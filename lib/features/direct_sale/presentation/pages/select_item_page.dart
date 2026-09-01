import 'package:flutter/material.dart';
import 'package:suitapps/features/direct_sale/presentation/theme/direct_sale_theme.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';
import 'package:suitapps/features/auth/data/datasources/permissions_local_datasource.dart';
import 'package:suitapps/features/direct_sale/data/models/Bill_model.dart';
import 'package:suitapps/features/direct_sale/data/models/item_category_model.dart';
import 'package:suitapps/features/direct_sale/data/models/sale_item_model.dart';
import 'package:suitapps/core/database/database_helper.dart';
import 'package:suitapps/features/direct_sale/data/datasources/item_sync_datasource.dart';
import 'package:suitapps/features/auth/data/datasources/permissions_api_datasource.dart';

/// Local, per-product editing state for the inline item list.
/// Everything the user can tweak for a row lives here; a [BillItem] is only
/// materialized (via [toBillItem]) once qty > 0 and the page is handed back.
class _LineDraft {
  String rateType;
  double rate;
  int qty;
  int freeQty;
  double discountPercent;
  double discountAmount;
  bool favorite;

  /// Product's tax rate (%), used by [taxAmountFor]/[netAmountFor] to apply
  /// the TAX_MODE permission (dbo.AppPermissions 'TAX_MODE': INCLUDE /
  /// EXCLUDE / BOTH). Set from ProductData.taxPercent when the draft is
  /// created â€” see _SelectItemPageState._draftFor / _seedDraftsFromInitialItems.
  double taxPercent;

  _LineDraft({
    required this.rateType,
    required this.rate,
    this.qty = 0,
    this.freeQty = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.favorite = false,
    this.taxPercent = 0,
  });

  double get grossAmount => rate * qty;

  /// Gross minus discount, before any tax adjustment. Both tax modes work
  /// from this â€” discount is always applied first (matches the existing
  /// DirectSaleOfCustomer billing logic: discount-first, then extract/add
  /// tax on the discounted total).
  double get discountedTotal {
    final value = grossAmount - discountAmount;
    return value < 0 ? 0 : value;
  }

  /// Kept for existing callers â€” same as [discountedTotal].
  /// Prefer [netAmountFor] for a tax-mode-aware line total.
  double get lineAmount => discountedTotal;

  /// The tax component of this line under [mode] ('INCLUDE' or 'EXCLUDE').
  /// - INCLUDE: rate already has tax baked in â€” back the tax out of
  ///   [discountedTotal] (this is the original/current calculation).
  /// - EXCLUDE: rate is tax-free â€” tax is calculated on top of
  ///   [discountedTotal] instead of being extracted from it.
  double taxAmountFor(String mode) {
    if (discountedTotal <= 0 || taxPercent <= 0) return 0;
    if (mode == 'EXCLUDE') {
      return discountedTotal * taxPercent / 100;
    }
    // INCLUDE (default)
    return discountedTotal - (discountedTotal / (1 + taxPercent / 100));
  }

  /// The final line total under [mode].
  /// - INCLUDE: [discountedTotal] already contains tax, so it IS the total.
  /// - EXCLUDE: tax is added on top of [discountedTotal].
  double netAmountFor(String mode) {
    if (mode == 'EXCLUDE') {
      return discountedTotal + taxAmountFor(mode);
    }
    return discountedTotal;
  }

  bool get isInBill => qty > 0;

  BillItem toBillItem(ProductData product, String taxMode) {
    return BillItem(
      productId: product.id,
      name: product.displayName,
      icon: product.icon,
      iconColor: product.iconColor,
      rateType: rateType,
      rate: rate,
      qty: qty,
      freeQty: freeQty,
      // Carried straight from the product master â€” this is what ends up
      // in the local bill_items row and the API payload's UnitID field
      // (see DirectSaleOfCustomer._saveBill()). ProductData.unitId is an
      // int; BillItem.unitId is a String (same pattern as productId), so
      // it's converted here.
      unitId: product.unitId.toString(),
      discountType: DiscountType.percent,
      discountValue: discountPercent,
      taxPercent: product.taxPercent,
      // NEW: carries the Include/Exclude choice made on this screen (see
      // _SelectItemPageState._taxMode / TAX_MODE permission) so
      // DirectSaleOfCustomer's totals use the SAME calculation the user
      // saw here, instead of always assuming tax-inclusive rates.
      taxMode: taxMode,
    );
  }
}

class SelectItemPage extends StatefulWidget {
  final Map<String, dynamic> customer;
  final List<BillItem> initialItems;

  /// Needed to call GetVanItems â€” pass these in from wherever
  /// the logged-in van / company context is stored.
  final int vanId;
  final int companyId;

  /// Needed to scope permission lookups (permissions are per company+user,
  /// see the `permissions` local table / dbo.AppPermissions).
  final int userId;

  const SelectItemPage({
    super.key,
    required this.customer,
    required this.vanId,
    required this.companyId,
    required this.userId,
    this.initialItems = const [],
  });

  @override
  State<SelectItemPage> createState() => _SelectItemPageState();
}

class _SelectItemPageState extends State<SelectItemPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  // null = "All" selected
  int? _selectedCategoryId;

  List<ItemCategory> _categories = [];
  List<ProductData> _allProducts = [];

  // permissionCode -> row, scoped to widget.companyId/widget.userId
  // (via PermissionsLocalDbService.getAllPermissionsFor)
  Map<String, Map<String, dynamic>> _permissions = {};
  final PermissionsLocalDbService _permissionsDb = PermissionsLocalDbService();

  bool _isLoadingLocal = true;
  bool _isSyncing = false;
  String? _loadError;

  // productId -> editable line state. Populated lazily as products load
  // (pre-filled from widget.initialItems where a cart already exists).
  final Map<String, _LineDraft> _drafts = {};

  bool _compactView = false;

  // Current tax calculation mode: 'INCLUDE' or 'EXCLUDE'.
  // Driven by the TAX_MODE permission (see _taxModeSetting). When that
  // permission is 'BOTH', the user can switch this via the selector chips
  // (_buildTaxModeSelector); otherwise it's forced to the permission's
  // single value and the selector is hidden entirely.
  String _taxMode = 'INCLUDE';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _loadFromLocalDb();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------
  // PERMISSIONS
  // ------------------------------------------------------
  //
  // Every gate below defaults to the *safe* (most restrictive) option if the
  // row is missing locally (e.g. before the first sync) or isActive = 0, so
  // the app never silently grants access it hasn't confirmed.

  bool _permBool(String code, {required bool defaultValue}) {
    final row = _permissions[code];
    if (row == null) return defaultValue;
    final isActive = row['isActive'] == 1 || row['isActive'] == true;
    if (!isActive) return defaultValue;
    final value = row['permissionValue']?.toString().trim().toLowerCase();
    return value == '1' || value == 'true';
  }

  bool get _allowManualRate => _permBool('ALLOW_MANUAL_RATE', defaultValue: false);
  bool get _allowRateTypeChange => _permBool('ALLOW_RATE_TYPE_CHANGE', defaultValue: false);
  bool get _allowManualDiscount => _permBool('ALLOW_MANUAL_DISCOUNT', defaultValue: false);
  bool get _allowCustomerDiscount => _permBool('ALLOW_CUSTOMER_DISCOUNT', defaultValue: false);
  bool get _allowNegativeStock => _permBool('ALLOW_NEGATIVE_STOCK', defaultValue: false);

  /// TAX_MODE is an OPTION-type permission (not BOOL) â€” its PermissionValue
  /// is the literal string 'INCLUDE', 'EXCLUDE', or 'BOTH', so it's read
  /// directly rather than through [_permBool]. Defaults to 'INCLUDE' (the
  /// original/current behavior) if the row is missing or inactive.
  String get _taxModeSetting {
    final row = _permissions['TAX_MODE'];
    if (row == null) return 'INCLUDE';
    final isActive = row['isActive'] == 1 || row['isActive'] == true;
    if (!isActive) return 'INCLUDE';
    final value = row['permissionValue']?.toString().trim().toUpperCase();
    if (value == 'INCLUDE' || value == 'EXCLUDE' || value == 'BOTH') return value!;
    return 'INCLUDE';
  }

  /// The Include/Exclude selector is only shown when the company has opted
  /// into letting staff choose (TAX_MODE = 'BOTH'). Otherwise the mode is
  /// fixed to whatever TAX_MODE says and the section doesn't render at all.
  bool get _showTaxModeSelector => _taxModeSetting == 'BOTH';

  /// Resolves [_taxMode] against the current TAX_MODE permission. Call after
  /// permissions (re)load. When the permission is 'BOTH', an already-chosen
  /// selection is preserved; otherwise the mode is forced to the single
  /// permitted value.
  void _resolveTaxMode() {
    final setting = _taxModeSetting;
    if (setting == 'BOTH') {
      _taxMode = _taxMode == 'EXCLUDE' ? 'EXCLUDE' : 'INCLUDE';
    } else {
      _taxMode = setting;
    }
  }

  // Note: AUTO_RATE_SELECTION is intentionally not read here â€” the
  // customer's assigned rate type is always used as the default line
  // rate (see _resolveDefaultRateType), not gated behind this permission.
  // If AUTO_RATE_SELECTION turns out to control something else (e.g. a
  // dynamic re-evaluation as qty crosses a price break), wire it in then.

  // ------------------------------------------------------
  // DATA LOADING
  // ------------------------------------------------------

  Future<void> _loadFromLocalDb() async {
    setState(() {
      _isLoadingLocal = true;
      _loadError = null;
    });
    try {
      final categories = await DatabaseHelper.instance.getCategories();
      final products = await DatabaseHelper.instance.getVanItems();
      final permissions = await _permissionsDb.getAllPermissionsFor(
        employeeCode: widget.userId.toString(),
        companyId: widget.companyId.toString(),
      );
      setState(() {
        _categories = categories;
        _allProducts = products;
        _permissions = permissions;
        _isLoadingLocal = false;
        _seedDraftsFromInitialItems();
        _resolveTaxMode();
      });
    } catch (e) {
      setState(() {
        _isLoadingLocal = false;
        _loadError = 'Could not load local data: $e';
      });
    }
  }

  void _seedDraftsFromInitialItems() {
    for (final item in widget.initialItems) {
      _drafts[item.productId] = _LineDraft(
        rateType: item.rateType,
        rate: item.rate,
        qty: item.qty,
        freeQty: item.freeQty,
        discountPercent: item.discountValue,
        discountAmount: item.rate * item.qty * item.discountValue / 100,
        taxPercent: item.taxPercent,
      );
    }
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final categories = await ItemSyncService.fetchCategories();
      final items = await ItemSyncService.fetchVanItems(
        vanId: widget.vanId,
        companyId: widget.companyId,
      );
      final permissionRows = await PermissionsApiService().fetchPermissions(
        employeeCode: widget.userId.toString(),
        companyId: widget.companyId.toString(),
      );

      await DatabaseHelper.instance.saveCategories(categories);
      await DatabaseHelper.instance.saveVanItems(items);
      await _permissionsDb.savePermissions(
        employeeCode: widget.userId.toString(),
        companyId: widget.companyId.toString(),
        permissions: permissionRows,
      );

      await _loadFromLocalDb();

      if (mounted) _showMessage('Sync complete â€” ${items.length} items updated');
    } catch (e) {
      if (mounted) _showMessage('Sync failed: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ------------------------------------------------------
  // FILTERING
  // ------------------------------------------------------

  List<ProductData> get _filteredProducts {
    return _allProducts.where((product) {
      final matchesCategory =
          _selectedCategoryId == null || product.categoryId == _selectedCategoryId;
      final matchesSearch = _searchQuery.isEmpty ||
          product.itemName.toLowerCase().contains(_searchQuery) ||
          product.hsn.toLowerCase().contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  _LineDraft _draftFor(ProductData product) {
    return _drafts.putIfAbsent(product.id, () {
      final defaultRateType = _resolveDefaultRateType(product);
      return _LineDraft(
        rateType: defaultRateType,
        rate: product.rates[defaultRateType] ?? product.mrp,
        taxPercent: product.taxPercent,
      );
    });
  }

  /// The customer's assigned rate type (see the account payload's
  /// "RateType" key) is always the correct starting rate for a new line â€”
  /// it is NOT gated behind AUTO_RATE_SELECTION. If it were, a company
  /// with AUTO_RATE_SELECTION off *and* ALLOW_RATE_TYPE_CHANGE off (as
  /// seen in this data) would have no way to ever land on the right rate:
  /// no auto default, and staff can't manually pick one either.
  String _resolveDefaultRateType(ProductData product) {
    final customerRateType = _readCustomerRateType();
    if (customerRateType != null && product.rates.containsKey(customerRateType)) {
      return customerRateType;
    }
    return product.rates.keys.isNotEmpty ? product.rates.keys.last : 'MRP';
  }

  /// Case-tolerant lookup â€” the account payload uses "RateType", but this
  /// guards against a differently-cased key from another caller.
  String? _readCustomerRateType() {
    for (final key in const ['RateType', 'rateType', 'RATE_TYPE', 'ratetype']) {
      final value = widget.customer[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  // ------------------------------------------------------
  // TOTALS (across everything currently in the bill)
  // ------------------------------------------------------

  Iterable<MapEntry<String, _LineDraft>> get _billEntries =>
      _drafts.entries.where((e) => e.value.isInBill);

  int get _totalItems => _billEntries.length;

  int get _totalQty => _billEntries.fold(0, (sum, e) => sum + e.value.qty);

  int get _totalFreeQty => _billEntries.fold(0, (sum, e) => sum + e.value.freeQty);

  double get _totalAmount =>
      _billEntries.fold(0, (sum, e) => sum + e.value.netAmountFor(_taxMode));

  void _finishAndReturn() {
    final cartItems = <BillItem>[];
    for (final entry in _billEntries) {
      final product = _allProducts.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => throw StateError('Product ${entry.key} not found'),
      );
      cartItems.add(entry.value.toBillItem(product, _taxMode));
    }
    Navigator.pop(context, cartItems);
  }

  void _cancelAndReturn() {
    Navigator.pop(context, widget.initialItems);
  }

  // ------------------------------------------------------
  // UI
  // ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _cancelAndReturn();
        return false;
      },
      child: Scaffold(
        backgroundColor: DsColors.background,
        appBar: _buildAppBar(),
        body: _isLoadingLocal
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _buildErrorState()
                : Column(
                    children: [
                      _buildSearchBar(),
                      _buildCategoryChips(),
                      if (_showTaxModeSelector) _buildTaxModeSelector(),
                      Expanded(child: _buildProductList()),
                    ],
                  ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: DashboardConstants.brandBlue,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _cancelAndReturn,
      ),
      title: Text('Item List', style: DsFonts.pageTitle),
      actions: [
        IconButton(
          tooltip: 'Sync items & categories',
          icon: _isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.sync, color: Colors.white),
          onPressed: _isSyncing ? null : _handleSync,
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: DsColors.textSecondary),
            const SizedBox(height: DsSpacing.sm),
            Text(_loadError!, style: DsFonts.smallText, textAlign: TextAlign.center),
            const SizedBox(height: DsSpacing.md),
            ElevatedButton.icon(
              onPressed: _loadFromLocalDb,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: DsColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpacing.lg, DsSpacing.md, DsSpacing.lg, DsSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: DsColors.cardBg,
          borderRadius: BorderRadius.circular(DsRadius.button),
          border: Border.all(color: DsColors.border),
        ),
        child: TextField(
          controller: _searchController,
          style: DsFonts.body,
          decoration: InputDecoration(
            hintText: 'Search item by name / code / barcode',
            hintStyle: DsFonts.smallText,
            prefixIcon: const Icon(Icons.search, color: DsColors.textSecondary),
            suffixIcon: _searchQuery.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(right: DsSpacing.sm),
                    child: Icon(Icons.qr_code_scanner_outlined, color: DsColors.textSecondary),
                  )
                : IconButton(
                    icon: const Icon(Icons.close, color: DsColors.textSecondary),
                    onPressed: () => _searchController.clear(),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1, // +1 for "All"
                separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.sm),
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final category = isAll ? null : _categories[index - 1];
                  final isSelected = isAll
                      ? _selectedCategoryId == null
                      : _selectedCategoryId == category!.categoryId;
                  final label = isAll ? 'All' : category!.categoryName;

                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => setState(
                      () => _selectedCategoryId = isAll ? null : category!.categoryId,
                    ),
                    labelStyle: DsFonts.smallText.copyWith(
                      color: isSelected ? Colors.white : DsColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: DsColors.primary,
                    backgroundColor: DsColors.cardBg,
                    side: BorderSide(color: isSelected ? DsColors.primary : DsColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DsRadius.chip),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: DsSpacing.lg, left: DsSpacing.xs),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _compactView = !_compactView),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DsColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DsColors.primary.withOpacity(0.3)),
                  ),
                  child: Icon(
                    _compactView ? Icons.view_agenda_outlined : Icons.view_list_outlined,
                    size: 18,
                    color: DsColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Include/Exclude tax toggle. Only ever built when [_showTaxModeSelector]
  /// is true (TAX_MODE permission = 'BOTH') â€” when the permission is fixed
  /// to a single value, this section is skipped entirely and [_taxMode] is
  /// forced by [_resolveTaxMode] instead.
  Widget _buildTaxModeSelector() {
    Widget chip(String label, String mode) {
      final isSelected = _taxMode == mode;
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _taxMode = mode),
        labelStyle: DsFonts.smallText.copyWith(
          color: isSelected ? Colors.white : DsColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: DsColors.primary,
        backgroundColor: DsColors.cardBg,
        side: BorderSide(color: isSelected ? DsColors.primary : DsColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DsRadius.chip),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpacing.lg, 0, DsSpacing.lg, DsSpacing.sm),
      child: Row(
        children: [
          Text('Tax:', style: DsFonts.caption),
          const SizedBox(width: DsSpacing.sm),
          chip('Include Tax', 'INCLUDE'),
          const SizedBox(width: DsSpacing.sm),
          chip('Exclude Tax', 'EXCLUDE'),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final products = _filteredProducts;

    if (_allProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 40, color: DsColors.textSecondary),
            const SizedBox(height: DsSpacing.sm),
            Text('No items loaded yet', style: DsFonts.smallText),
            const SizedBox(height: DsSpacing.sm),
            TextButton.icon(
              onPressed: _isSyncing ? null : _handleSync,
              icon: const Icon(Icons.sync),
              label: const Text('Tap to sync now'),
            ),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: DsColors.textSecondary),
            const SizedBox(height: DsSpacing.sm),
            Text('No products found', style: DsFonts.smallText),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleSync,
      color: DsColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, DsSpacing.xl),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
        itemBuilder: (context, index) {
          final product = products[index];
          return _compactView
              ? _CompactProductRow(
                  key: ValueKey('compact-${product.id}'),
                  product: product,
                  draft: _draftFor(product),
                  allowNegativeStock: _allowNegativeStock,
                  onChanged: () => setState(() {}),
                )
              : _InlineProductCard(
                  key: ValueKey('full-${product.id}'),
                  product: product,
                  draft: _draftFor(product),
                  allowManualRate: _allowManualRate,
                  allowRateTypeChange: _allowRateTypeChange,
                  allowManualDiscount: _allowManualDiscount,
                  allowNegativeStock: _allowNegativeStock,
                  taxMode: _taxMode,
                  onChanged: () => setState(() {}),
                  onClear: () => setState(() {
                    final d = _draftFor(product);
                    d.qty = 0;
                    d.freeQty = 0;
                    d.discountPercent = 0;
                    d.discountAmount = 0;
                  }),
                );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DsSpacing.lg, DsSpacing.md, DsSpacing.lg, DsSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _buildSummaryStat('Total Items', '$_totalItems')),
                  Expanded(child: _buildSummaryStat('Total Qty', '$_totalQty')),
                  Expanded(child: _buildSummaryStat('Free Qty', '$_totalFreeQty')),
                  Expanded(
                    child: _buildSummaryStat(
                      'Total Amount',
                      'â‚¹${_totalAmount.toStringAsFixed(2)}',
                      valueColor: DsColors.primary,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelAndReturn,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
                        side: const BorderSide(color: DsColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
                      ),
                      child: Text('CANCEL', style: DsFonts.bodyBold),
                    ),
                  ),
                  const SizedBox(width: DsSpacing.md),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _totalItems == 0 ? null : _finishAndReturn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DsColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white, size: 18),
                      label: Text(
                        'DONE (ADD TO BILL)',
                        style: DsFonts.bodyBold.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, {Color? valueColor, bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: DsFonts.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: DsFonts.bodyBold.copyWith(color: valueColor ?? DsColors.textPrimary),
        ),
      ],
    );
  }
}

// ============================================================
// COMPACT ROW â€” quick scan mode (name, one rate, qty stepper, amount)
// ============================================================

class _CompactProductRow extends StatelessWidget {
  final ProductData product;
  final _LineDraft draft;
  final bool allowNegativeStock;
  final VoidCallback onChanged;

  const _CompactProductRow({
    super.key,
    required this.product,
    required this.draft,
    required this.allowNegativeStock,
    required this.onChanged,
  });

  void _bumpQty(int delta) {
    var newQty = draft.qty + delta;
    if (delta > 0 && !allowNegativeStock && newQty > product.stock) {
      newQty = product.stock.floor();
    }
    draft.qty = newQty < 0 ? 0 : newQty;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final atStockLimit = !allowNegativeStock && draft.qty >= product.stock;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: draft.isInBill ? DashboardConstants.brandBlue.withOpacity(0.5) : DsColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: product.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(product.icon, color: product.iconColor, size: 20),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full item name shown â€” no maxLines/ellipsis truncation.
                Text(product.displayName, style: DsFonts.bodyBold),
                Text('â‚¹${draft.rate.toStringAsFixed(2)} â€¢ Stock: ${product.stock.toStringAsFixed(0)}', style: DsFonts.caption),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.remove,
            onTap: draft.qty > 0 ? () => _bumpQty(-1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text('${draft.qty}', textAlign: TextAlign.center, style: DsFonts.bodyBold),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: atStockLimit ? null : () => _bumpQty(1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: enabled ? DsColors.primaryLight : DsColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: enabled ? DashboardConstants.brandBlue.withOpacity(0.4) : DsColors.border),
        ),
        child: Icon(icon, size: 15, color: enabled ? DashboardConstants.brandBlue : DsColors.textSecondary),
      ),
    );
  }
}

// ============================================================
// FULL INLINE CARD â€” rate columns, qty/free-qty, discount, live amount
// ============================================================

class _InlineProductCard extends StatefulWidget {
  final ProductData product;
  final _LineDraft draft;
  final bool allowManualRate;
  final bool allowRateTypeChange;
  final bool allowManualDiscount;
  final bool allowNegativeStock;
  final String taxMode; // 'INCLUDE' or 'EXCLUDE' â€” see _SelectItemPageState._taxMode
  final VoidCallback onChanged;
  final VoidCallback onClear;

  const _InlineProductCard({
    super.key,
    required this.product,
    required this.draft,
    required this.allowManualRate,
    required this.allowRateTypeChange,
    required this.allowManualDiscount,
    required this.allowNegativeStock,
    required this.taxMode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_InlineProductCard> createState() => _InlineProductCardState();
}

class _InlineProductCardState extends State<_InlineProductCard> {
  late final TextEditingController _rateController;
  late final TextEditingController _discPercentController;
  late final TextEditingController _discAmountController;
  late final TextEditingController _qtyController;
  late final TextEditingController _freeQtyController;

  @override
  void initState() {
    super.initState();
    _rateController = TextEditingController(text: _fmt(widget.draft.rate));
    _discPercentController = TextEditingController(text: _fmt(widget.draft.discountPercent));
    _discAmountController = TextEditingController(text: _fmt(widget.draft.discountAmount));
    _qtyController = TextEditingController(text: '${widget.draft.qty}');
    _freeQtyController = TextEditingController(text: '${widget.draft.freeQty}');
  }

  @override
  void dispose() {
    _rateController.dispose();
    _discPercentController.dispose();
    _discAmountController.dispose();
    _qtyController.dispose();
    _freeQtyController.dispose();
    super.dispose();
  }

  String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  void _syncControllers() {
    _rateController.text = _fmt(widget.draft.rate);
    _discPercentController.text = widget.draft.discountPercent == 0 ? '' : _fmt(widget.draft.discountPercent);
    _discAmountController.text = widget.draft.discountAmount == 0 ? '' : _fmt(widget.draft.discountAmount);
    _qtyController.text = '${widget.draft.qty}';
    _freeQtyController.text = '${widget.draft.freeQty}';
  }

  void _selectRateType(String key, double value) {
    if (!widget.allowRateTypeChange) return; // ALLOW_RATE_TYPE_CHANGE gate
    setState(() {
      widget.draft.rateType = key;
      widget.draft.rate = value;
      _recalcDiscountFromPercent();
      _rateController.text = _fmt(value);
    });
    widget.onChanged();
  }

  void _recalcDiscountFromPercent() {
    final gross = widget.draft.grossAmount;
    widget.draft.discountAmount = gross * widget.draft.discountPercent / 100;
    _discAmountController.text = widget.draft.discountAmount == 0 ? '' : _fmt(widget.draft.discountAmount);
  }

  void _recalcPercentFromAmount() {
    final gross = widget.draft.grossAmount;
    widget.draft.discountPercent = gross > 0 ? (widget.draft.discountAmount / gross * 100) : 0;
    _discPercentController.text = widget.draft.discountPercent == 0 ? '' : _fmt(widget.draft.discountPercent);
  }

  // --------------------------------------------------------
  // QTY â€” supports both the +/- stepper buttons and direct typing.
  // --------------------------------------------------------

  void _bumpQty(int delta) {
    var newQty = widget.draft.qty + delta;
    // ALLOW_NEGATIVE_STOCK gate: cap additions at available stock when off.
    if (delta > 0 && !widget.allowNegativeStock && newQty > widget.product.stock) {
      newQty = widget.product.stock.floor();
    }
    setState(() {
      widget.draft.qty = newQty < 0 ? 0 : newQty;
      _qtyController.text = '${widget.draft.qty}';
      _qtyController.selection = TextSelection.collapsed(offset: _qtyController.text.length);
      _recalcDiscountFromPercent();
    });
    widget.onChanged();
  }

  void _onQtyTyped(String value) {
    var parsed = int.tryParse(value) ?? 0;
    if (parsed < 0) parsed = 0;
    if (!widget.allowNegativeStock && parsed > widget.product.stock) {
      parsed = widget.product.stock.floor();
      _qtyController.text = '$parsed';
      _qtyController.selection = TextSelection.collapsed(offset: _qtyController.text.length);
    }
    setState(() {
      widget.draft.qty = parsed;
      _recalcDiscountFromPercent();
    });
    widget.onChanged();
  }

  // --------------------------------------------------------
  // FREE QTY â€” supports both the +/- stepper buttons and direct typing.
  // --------------------------------------------------------

  void _bumpFreeQty(int delta) {
    final newFree = widget.draft.freeQty + delta;
    setState(() {
      widget.draft.freeQty = newFree < 0 ? 0 : newFree;
      _freeQtyController.text = '${widget.draft.freeQty}';
      _freeQtyController.selection = TextSelection.collapsed(offset: _freeQtyController.text.length);
    });
    widget.onChanged();
  }

  void _onFreeQtyTyped(String value) {
    var parsed = int.tryParse(value) ?? 0;
    if (parsed < 0) parsed = 0;
    setState(() => widget.draft.freeQty = parsed);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final draft = widget.draft;
    final outOfStock = product.stock <= 0;
    final atStockLimit = !widget.allowNegativeStock && draft.qty >= product.stock;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: draft.isInBill ? DashboardConstants.brandBlue.withOpacity(0.5) : DsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon, full name, stock (no HSN), favorite.
          // Delete icon removed â€” clear a line by typing qty back to 0.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: product.iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(product.icon, color: product.iconColor, size: 22),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full item name â€” no maxLines/overflow, wraps as needed.
                    Text(product.displayName, style: DsFonts.bodyBold),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${product.stock.toStringAsFixed(0)}',
                      style: DsFonts.caption.copyWith(color: outOfStock ? Colors.red : DsColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  draft.favorite ? Icons.star : Icons.star_border,
                  size: 20,
                  color: draft.favorite ? Colors.amber[700] : DsColors.textSecondary,
                ),
                onPressed: () {
                  setState(() => draft.favorite = !draft.favorite);
                  widget.onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),

          // Rate-type columns (MRP / CCP / DP / WP / SP / ...whatever exists)
          // Tapping is a no-op when ALLOW_RATE_TYPE_CHANGE is off, and the
          // chips are dimmed so it's visually clear they're locked.
          Opacity(
            opacity: widget.allowRateTypeChange ? 1 : 0.5,
            child: Row(
              children: product.rates.entries.map((entry) {
                final isSelected = entry.key == draft.rateType;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: DsSpacing.xs),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.allowRateTypeChange ? () => _selectRateType(entry.key, entry.value) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? DashboardConstants.brandBlue: DsColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? DashboardConstants.brandBlue : DsColors.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              entry.key,
                              style: DsFonts.caption.copyWith(
                                color: isSelected ? Colors.white : DsColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              entry.value.toStringAsFixed(2),
                              style: DsFonts.smallText.copyWith(
                                color: isSelected ? Colors.white : DsColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: DsSpacing.sm),

          // Rate (editable) / Qty / Free Qty
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLabeledField(
                  label: 'Rate (${draft.rateType})',
                  child: _buildTextInput(
                    controller: _rateController,
                    readOnly: !widget.allowManualRate, // ALLOW_MANUAL_RATE gate
                    prefixIcon: widget.allowManualRate ? Icons.edit_outlined : Icons.lock_outline,
                    onChanged: (value) {
                      draft.rate = double.tryParse(value) ?? draft.rate;
                      _recalcDiscountFromPercent();
                      widget.onChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: _buildLabeledField(
                  label: 'Qty',
                  child: _buildStepperRow(
                    controller: _qtyController,
                    onTyped: _onQtyTyped,
                    onDecrement: () => _bumpQty(-1),
                    onIncrement: atStockLimit ? null : () => _bumpQty(1),
                    decrementEnabled: draft.qty > 0,
                  ),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: _buildLabeledField(
                  label: 'Free Qty',
                  child: _buildStepperRow(
                    controller: _freeQtyController,
                    onTyped: _onFreeQtyTyped,
                    onDecrement: () => _bumpFreeQty(-1),
                    onIncrement: () => _bumpFreeQty(1),
                    decrementEnabled: draft.freeQty > 0,
                  ),
                ),
              ),
            ],
          ),
          if (atStockLimit) ...[
            const SizedBox(height: 4),
            Text(
              'Stock limit reached',
              style: DsFonts.caption.copyWith(color: Colors.red),
            ),
          ],
          const SizedBox(height: DsSpacing.sm),

          // Discount % / Discount â‚¹ / live Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLabeledField(
                  label: 'Disc. %',
                  child: _buildTextInput(
                    controller: _discPercentController,
                    readOnly: !widget.allowManualDiscount, // ALLOW_MANUAL_DISCOUNT gate
                    onChanged: (value) {
                      draft.discountPercent = double.tryParse(value) ?? 0;
                      _recalcDiscountFromPercent();
                      widget.onChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: _buildLabeledField(
                  label: 'Disc. â‚¹',
                  child: _buildTextInput(
                    controller: _discAmountController,
                    readOnly: !widget.allowManualDiscount, // ALLOW_MANUAL_DISCOUNT gate
                    valueColor: DsColors.success,
                    onChanged: (value) {
                      draft.discountAmount = double.tryParse(value) ?? 0;
                      _recalcPercentFromAmount();
                      widget.onChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: _buildLabeledField(
                  label: 'Amount',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        height: 40,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
                        decoration: BoxDecoration(
                          color: DsColors.primaryLight,
                          borderRadius: BorderRadius.circular(DsRadius.button),
                        ),
                        child: Text(
                          'â‚¹${draft.netAmountFor(widget.taxMode).toStringAsFixed(2)}',
                          style: DsFonts.bodyBold.copyWith(color: DsColors.primary),
                        ),
                      ),
                      if (draft.taxPercent > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.taxMode == 'EXCLUDE'
                              ? '+â‚¹${draft.taxAmountFor(widget.taxMode).toStringAsFixed(2)} tax'
                              : 'incl. â‚¹${draft.taxAmountFor(widget.taxMode).toStringAsFixed(2)} tax',
                          style: DsFonts.caption,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DsFonts.caption),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    bool readOnly = false,
    IconData? prefixIcon,
    Color? valueColor,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: DsFonts.smallText.copyWith(
          fontWeight: FontWeight.w700,
          color: readOnly ? DsColors.textSecondary : (valueColor ?? DsColors.textPrimary),
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          filled: readOnly,
          fillColor: readOnly ? DsColors.background : null,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 14, color: DsColors.textSecondary)
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 0),
          contentPadding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DsRadius.button),
            borderSide: const BorderSide(color: DsColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DsRadius.button),
            borderSide: const BorderSide(color: DsColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DsRadius.button),
            borderSide: const BorderSide(color: DsColors.primary),
          ),
        ),
      ),
    );
  }

  /// Qty / Free Qty control: [-] [editable number field] [+].
  /// The middle field accepts direct typing via [onTyped]; the side buttons
  /// still work via [onDecrement]/[onIncrement] and keep the field in sync.
  Widget _buildStepperRow({
    required TextEditingController controller,
    required ValueChanged<String> onTyped,
    required VoidCallback onDecrement,
    required VoidCallback? onIncrement,
    required bool decrementEnabled,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: DsColors.border),
        borderRadius: BorderRadius.circular(DsRadius.button),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: decrementEnabled ? onDecrement : null,
              child: Icon(
                Icons.remove,
                size: 16,
                color: decrementEnabled ? DsColors.primary : DsColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: DsFonts.bodyBold,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onTyped,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onIncrement,
              child: Icon(
                Icons.add,
                size: 16,
                color: onIncrement != null ? DsColors.primary : DsColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
