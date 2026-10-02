import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:suitapps/core/database/database_helper.dart';
import 'package:suitapps/features/direct_sale/data/models/sale_item_model.dart';
import 'package:suitapps/features/direct_sale/presentation/pages/select_item_page.dart';
import 'package:suitapps/features/direct_sale/data/models/Bill_model.dart' as ds_bill;
import 'package:suitapps/features/SaleOrder/data/models/sale_order_model.dart';
import 'package:suitapps/features/SaleOrder/presentation/theme/order_sale_theme.dart';
import 'package:suitapps/features/SaleOrder/services/SaleOrderSyncService.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';

/// Create/edit page for a sale order (AliaseSales / AliaseSalesDetails on
/// the server — see Sync_AliasDirectSales / Sync_AliasDirectSaleDetails).
/// Structurally mirrors DirectSaleOfCustomer (same customer card, same
/// SelectItemPage flow, same OrderItem/BillItem-based totals, and now the
/// same series/next-number preview pattern — see
/// _loadOrderSeriesAndNumber/_bumpGreatestOrderBillNo) but trimmed to what
/// an order actually needs — no invoice PDF popup. Converting a saved
/// order into an actual bill later is a separate TODO, not built here.
///
/// NOTE on models: this feature's own `OrderItem` (sale_order_model.dart)
/// is field-for-field identical to direct_sale's `BillItem` (Bill_model.dart)
/// by design, but `SelectItemPage` — shared with DirectSaleOfCustomer — is
/// hard-wired to `BillItem`. Rather than forking SelectItemPage, this page
/// converts at the boundary via `_orderItemFromBillItem` / `_billItemFromOrderItem`.
///
/// PRIMARY vs SECONDARY:
///   This same page now serves BOTH "Primary Order" and "Secondary Sales"
///   from CustomerInfoPage's Quick Actions grid — see the `isPrimary` flag
///   below. The two flows are otherwise 100% identical (UI, item
///   selection, totals, save flow); the ONLY difference is the new
///   `status` column persisted with the order: 1 for Primary, 0 for
///   Secondary. See `_orderTypeStatus` and its use in `_saveOrder`.
///
/// CHANGE LOG (fixes applied):
///   • orderSeries/orderNumber are now saved as TWO SEPARATE local columns
///     instead of being pre-joined into a single "series-number" string.
///     `orderNo` is still saved too, purely as a display/legacy string, in
///     case other screens (e.g. bill printing) still read it that way.
///   • `amount` now stores the FINAL amount (same value as `totalAmount`,
///     tax included), not the pre-tax subtotal.
///   • cgstRate/cgstAmount/sgstRate/sgstAmount are now computed and saved
///     locally (CGST = SGST = taxPercent / 2, taxAmount / 2) instead of
///     being written as NULL.
///   • Added `isPrimary` flag + `status` column (1 = Primary, 0 =
///     Secondary) — see "PRIMARY vs SECONDARY" above.
///   • FIX: `customerId` now resolves to the real numeric AccountID from
///     dbo.Accout FIRST (keys 'AccountID' / 'AccountId'), instead of
///     silently falling through to AccountCode/Code because those exact
///     key names weren't in the lookup list. Previously an order saved
///     with the customer's display CODE in the CustomerID column instead
///     of their actual AccountID, breaking the FK relationship on the
///     server (AliaseSales.CustomerID). See `_readValue` call below.
class SaleOrderPage extends StatefulWidget {
  final Map<String, dynamic> customer;

  /// True = Primary Order, false = Secondary Sales. The only behavioural
  /// difference between the two order types is the `status` column
  /// persisted with the order (1 for primary, 0 for secondary) — see
  /// `_orderTypeStatus`. Everything else (UI, item selection, totals,
  /// save flow) is identical. Defaults to true so existing call sites
  /// that don't pass it keep behaving as a Primary order.
  final bool isPrimary;

  /// When non-null, opens in EDIT mode: a row from the local `sale_orders`
  /// table (see DatabaseHelper.getAllSaleOrders).
  final Map<String, dynamic>? orderToEdit;

  /// Line items for [orderToEdit], from `DatabaseHelper.getItemsForSaleOrder`.
  final List<Map<String, dynamic>>? orderItemsToEdit;

  const SaleOrderPage({
    super.key,
    required this.customer,
    this.isPrimary = true,
    this.orderToEdit,
    this.orderItemsToEdit,
  });

  @override
  State<SaleOrderPage> createState() => _SaleOrderPageState();
}

/// Placeholder order-status codes — AliaseSales.OrderStatus is typed
/// `money` server-side with no lookup table shown, so the actual codes in
/// use aren't confirmed. Adjust these to match whatever your backend
/// actually expects before relying on this in production.
class _OrderStatusOption {
  final double value;
  final String label;
  const _OrderStatusOption(this.value, this.label);
}

const List<_OrderStatusOption> _orderStatusOptions = [
  _OrderStatusOption(0, 'Pending'),
  _OrderStatusOption(1, 'Confirmed'),
  _OrderStatusOption(2, 'Dispatched'),
  _OrderStatusOption(3, 'Cancelled'),
];

class _SaleOrderPageState extends State<SaleOrderPage> {
  List<OrderItem> _orderItems = [];
  final TextEditingController _advanceAmountController = TextEditingController(text: '0');
  final TextEditingController _narrationController = TextEditingController();
  double _orderStatus = 0;
  bool _isSaving = false;

  // ── Order series / order number (B2B vs B2C) ──
  String _orderSeries = '';
  String _orderBillNo = '';
  bool _loadingOrderNo = true;

  bool get _isEditing => widget.orderToEdit != null;

  // ── Primary vs Secondary ──
  int get _orderTypeStatus {
    if (_isEditing) {
      return (widget.orderToEdit!['status'] as num?)?.toInt() ?? (widget.isPrimary ? 1 : 0);
    }
    return widget.isPrimary ? 1 : 0;
  }

  bool get _resolvedIsPrimary => _orderTypeStatus == 1;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _seedFromOrderToEdit();
    } else {
      _loadOrderSeriesAndNumber();
    }
    SaleOrderSyncService.instance.trySyncNow();
  }

  @override
  void dispose() {
    _advanceAmountController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  OrderItem _orderItemFromBillItem(ds_bill.BillItem b) {
    return OrderItem(
      productId: b.productId,
      name: b.name,
      icon: b.icon,
      iconColor: b.iconColor,
      rateType: b.rateType,
      rate: b.rate,
      qty: b.qty,
      freeQty: b.freeQty,
      unitId: b.unitId,
      discountType: b.discountType == ds_bill.DiscountType.percent
          ? DiscountType.percent
          : DiscountType.amount,
      discountValue: b.discountValue,
      taxPercent: b.taxPercent,
      taxMode: b.taxMode,
    );
  }

  ds_bill.BillItem _billItemFromOrderItem(OrderItem o) {
    return ds_bill.BillItem(
      productId: o.productId,
      name: o.name,
      icon: o.icon,
      iconColor: o.iconColor,
      rateType: o.rateType,
      rate: o.rate,
      qty: o.qty,
      freeQty: o.freeQty,
      unitId: o.unitId,
      discountType: o.discountType == DiscountType.percent
          ? ds_bill.DiscountType.percent
          : ds_bill.DiscountType.amount,
      discountValue: o.discountValue,
      taxPercent: o.taxPercent,
      taxMode: o.taxMode,
    );
  }

  // ── Read helpers (tolerant of whatever keys your customer map uses) ──
  String _readValue(List<String> keys, {String fallback = 'N/A'}) {
    for (final key in keys) {
      final value = widget.customer[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  String get _gstNumber => _readValue(['GSTNumber', 'GSTIN', 'GstNo', 'Gst', 'GST'], fallback: '');

  bool get _isB2BCustomer {
    if (_isEditing) {
      final invType = _readValue(['InvoiceType'], fallback: '').toUpperCase();
      if (invType == 'B2B') return true;
      if (invType == 'B2C') return false;
    }
    return _gstNumber.isNotEmpty && _gstNumber != 'N/A';
  }

  Future<void> _seedFromOrderToEdit() async {
    final order = widget.orderToEdit!;

    List<ProductData> products = [];
    try {
      products = await DatabaseHelper.instance.getVanItems();
    } catch (_) {
      // Non-fatal — items just render with a generic icon below.
    }
    final productLookup = {for (final p in products) p.id: p};

    final items = (widget.orderItemsToEdit ?? [])
        .map((row) => _orderItemFromRow(row, productLookup))
        .toList();

    if (!mounted) return;
    setState(() {
      _orderItems = items;
      _advanceAmountController.text = (order['advanceAmount'] ?? 0).toString();
      _narrationController.text = order['narration']?.toString() ?? '';
      _orderStatus = (order['orderStatus'] as num?)?.toDouble() ?? 0;
      _loadingOrderNo = false;
    });
  }

  Future<void> _loadOrderSeriesAndNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final series = _isB2BCustomer
          ? (prefs.getString('B2BOrderSeries') ?? '')
          : (prefs.getString('B2COrderSeries') ?? '');

      final greatestOrderNo = _isB2BCustomer
          ? (prefs.getInt('GreatestB2BOrderBillNo') ?? 0)
          : (prefs.getInt('GreatestB2COrderBillNo') ?? 0);

      final nextOrderNo = (greatestOrderNo + 1).toString();

      if (!mounted) return;
      setState(() {
        _orderSeries = series;
        _orderBillNo = nextOrderNo;
        _loadingOrderNo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOrderNo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load order number: $e')),
      );
    }
  }

  Future<void> _bumpGreatestOrderBillNo(int savedOrderNo) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isB2BCustomer ? 'GreatestB2BOrderBillNo' : 'GreatestB2COrderBillNo';
    final current = prefs.getInt(key) ?? 0;

    if (savedOrderNo > current) {
      await prefs.setInt(key, savedOrderNo);
    }

    if (!mounted) return;
    await _loadOrderSeriesAndNumber();
  }

  String get _displayOrderNo {
    if (_isEditing) {
      final series = widget.orderToEdit?['orderSeries']?.toString() ?? '';
      final number = widget.orderToEdit?['orderNumber']?.toString() ?? '';
      if (series.isEmpty && number.isEmpty) {
        return widget.orderToEdit?['orderNo']?.toString() ?? '';
      }
      return series.isEmpty ? number : '$series-$number';
    }
    if (_loadingOrderNo) return '...';
    return _orderSeries.isEmpty ? _orderBillNo : '$_orderSeries-$_orderBillNo';
  }

  OrderItem _orderItemFromRow(Map<String, dynamic> row, Map<String, ProductData> productLookup) {
    final productId = row['productId']?.toString() ?? '';
    final product = productLookup[productId];
    final taxPercent = double.tryParse(row['taxRate']?.toString() ?? '') ?? 0;

    return OrderItem(
      productId: productId,
      name: row['itemName']?.toString() ?? (product?.displayName ?? 'Item'),
      icon: product?.icon ?? Icons.inventory_2_outlined,
      iconColor: product?.iconColor ?? DashboardConstants.brandBlue,
      rateType: 'MRP',
      rate: (row['rate'] as num?)?.toDouble() ?? 0,
      qty: (row['qty'] as num?)?.toInt() ?? 0,
      freeQty: (row['freeQty'] as num?)?.toInt() ?? 0,
      unitId: '',
      discountType: DiscountType.percent,
      discountValue: (row['discountPercent'] as num?)?.toDouble() ?? 0,
      taxPercent: taxPercent,
      taxMode: 'INCLUDE',
    );
  }

  Future<void> _openSelectItem() async {
    final prefs = await SharedPreferences.getInstance();
    final vanId = prefs.getInt('VanID') ?? 0;
    final companyIdStr = prefs.getString('CompanyID') ?? prefs.getString('SelectedCompanyId') ?? '0';
    final companyId = int.tryParse(companyIdStr) ?? 0;
    final userId = _readIntPref(prefs, ['UserID', 'UserId', 'User_ID']);

    if (!mounted) return;

    final result = await Navigator.push<List<ds_bill.BillItem>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectItemPage(
          customer: widget.customer,
          initialItems: _orderItems.map(_billItemFromOrderItem).toList(),
          vanId: vanId,
          companyId: companyId,
          userId: userId,
        ),
      ),
    );

    if (result != null) {
      setState(() => _orderItems = result.map(_orderItemFromBillItem).toList());
    }
  }

  void _removeItem(OrderItem item) {
    setState(() => _orderItems.removeWhere((i) => i.productId == item.productId));
  }

  int _readIntPref(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final intValue = prefs.getInt(key);
      if (intValue != null) return intValue;
      final stringValue = prefs.getString(key);
      if (stringValue != null) {
        final parsed = int.tryParse(stringValue);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  // ── Totals — same shape as DirectSaleOfCustomer ──
  int get _itemCount => _orderItems.length;
  int get _totalQty => _orderItems.fold(0, (sum, item) => sum + item.qty);
  double get _subTotal => _orderItems.fold(0, (sum, item) => sum + item.taxableAmount);
  double get _totalDiscount => _orderItems.fold(0, (sum, item) => sum + item.discountAmount);
  double get _totalTax => _orderItems.fold(0, (sum, item) => sum + item.taxAmount);
  double get _totalAmount => _subTotal + _totalTax;

  Future<void> _saveOrder() async {
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = int.tryParse(
            prefs.getString('CompanyID') ?? prefs.getString('SelectedCompanyId') ?? '0',
          ) ??
          0;
      final userId = _readIntPref(prefs, ['UserID', 'UserId', 'User_ID']);
      final fYearId = _readIntPref(prefs, ['FYearID', 'FYearId', 'FyearID']);

      final now = DateTime.now();

      int seq = 0;
      String nextSuitAppsId() {
        seq++;
        final ts = '${now.year.toString().padLeft(4, '0')}'
            '${now.month.toString().padLeft(2, '0')}'
            '${now.day.toString().padLeft(2, '0')}'
            '${now.hour.toString().padLeft(2, '0')}'
            '${now.minute.toString().padLeft(2, '0')}'
            '${now.second.toString().padLeft(2, '0')}';
        return '$userId-$ts-$seq';
      }

      final suitAppsId = _isEditing
          ? (widget.orderToEdit!['suitAppsId'] as String)
          : nextSuitAppsId();

      // FIX: CustomerID sent to the server must be the customer's real
      // numeric database id — dbo.Accout.AccountID (matches
      // AliaseSales.CustomerID FK) — NOT their display code.
      // 'AccountID' / 'AccountId' are checked FIRST since that's the
      // actual key name the customer map carries (it comes straight off
      // dbo.Accout via GetCustomerDetails / GetDistributors / etc., whose
      // SELECT list starts with "AccountID, AccountCode, ..."). Previously
      // 'AccountID' wasn't in this list at all, so _readValue always fell
      // through every numeric-id guess and landed on 'AccountCode' /
      // 'Code' instead, silently saving the CODE as CustomerID.
      // 'AccountCode' / 'Code' are kept ONLY as a last-resort fallback for
      // any older caller that might still pass just a code with no id.
      final customerId = _readValue(
        [
          'AccountID',
          'AccountId',
          'CustomerId',
          'customerId',
          'CustomerID',
          'Id',
          'id',
          'AccountCode',
          'Code',
        ],
      );
      final customerName = _readValue(['AccountName', 'Name']);
      final advanceAmount = double.tryParse(_advanceAmountController.text) ?? 0;

      final createdDate = _isEditing
          ? (widget.orderToEdit!['createdDate']?.toString() ?? now.toIso8601String())
          : now.toIso8601String();
      final orderDate = _isEditing
          ? (widget.orderToEdit!['orderDate']?.toString() ?? now.toIso8601String())
          : now.toIso8601String();

      final orderSeries = _isEditing
          ? (widget.orderToEdit!['orderSeries']?.toString() ?? '')
          : _orderSeries;
      final orderNumber = _isEditing
          ? (widget.orderToEdit!['orderNumber'] as int? ?? 0)
          : (int.tryParse(_orderBillNo) ?? 0);

      final localOrder = {
        'suitAppsId': suitAppsId,
        'serverOrderId': _isEditing ? widget.orderToEdit!['serverOrderId'] : null,
        'orderSeries': orderSeries,
        'orderNumber': orderNumber,
        'orderNo': _displayOrderNo,
        'orderDate': orderDate,
        'customerId': customerId,
        'customerName': customerName,
        'customerSuitAppsId': _readValue(['CustomerSuitAppsId'], fallback: ''),
        'userId': userId,
        'companyId': companyId,
        'amount': _totalAmount,
        'advanceAmount': advanceAmount,
        'totalAmount': _totalAmount,
        'orderStatus': _orderStatus,
        'status': _orderTypeStatus,
        'discount': _totalDiscount,
        'discountRate': '',
        'billSeries': orderSeries,
        'billNo': orderNumber.toString(),
        'aliasBillNo': '$userId-$orderNumber',
        'fYearId': fYearId,
        'invType': _isB2BCustomer ? 'B2B' : 'B2C',
        'billMode': 0,
        'narration': _narrationController.text,
        'createdBy': userId,
        'createdDate': createdDate,
        'modifiedBy': 0,
        'modifiedDate': now.toIso8601String(),
        'deletedBy': 0,
        'deletedDate': null,
        'isDeleted': 0,
        'isSynced': 0,
      };

      final localItems = _orderItems.map((item) {
        final itemSuitAppsId = nextSuitAppsId();

        final halfTaxPercent = item.taxPercent / 2;
        final halfTaxAmount = item.taxAmount / 2;

        return {
          'suitAppsId': itemSuitAppsId,
          'productId': item.productId,
          'itemName': item.name,
          'qty': item.qty,
          'freeQty': item.freeQty,
          'rate': item.rate,
          'mrp': item.rate,
          'grossValue': item.taxableAmount,
          'netAmount': item.netAmount,
          'taxRate': item.taxPercent.toString(),
          'taxAmount': item.taxAmount,
          'cgstRate': halfTaxPercent.toString(),
          'cgstAmount': halfTaxAmount,
          'sgstRate': halfTaxPercent.toString(),
          'sgstAmount': halfTaxAmount,
          'fCessRate': '0',
          'fCessAmount': 0.0,
          'discountPercent': item.discountPercentDisplay,
          'discountAmount': item.discountAmount,
          'isSynced': 0,
        };
      }).toList();

      await DatabaseHelper.instance.insertSaleOrderWithItems(localOrder, localItems);

      if (!_isEditing) {
        await _bumpGreatestOrderBillNo(int.tryParse(_orderBillNo) ?? 0);
      }

      // ignore: unawaited_futures
      SaleOrderSyncService.instance.trySyncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Order updated.' : 'Order saved.')),
      );

      if (_isEditing) {
        Navigator.pop(context);
      } else {
        setState(() {
          _orderItems = [];
          _advanceAmountController.text = '0';
          _narrationController.clear();
          _orderStatus = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save order: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DsColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomerCard(),
            const SizedBox(height: DsSpacing.md),
            _buildSearchAndAddRow(),
            const SizedBox(height: DsSpacing.lg),
            if (_orderItems.isEmpty) _buildEmptyState() else _buildItemsList(),
            const SizedBox(height: DsSpacing.lg),
            _buildSummaryCard(),
            const SizedBox(height: DsSpacing.lg),
            _buildOrderDetailsSection(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final typeLabel = _resolvedIsPrimary ? 'Primary Order' : 'Secondary Sales';
    return AppBar(
      backgroundColor: DashboardConstants.brandBlue,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sale Order', style: DsFonts.pageTitle),
          Text(
            _isEditing ? 'Update $typeLabel' : 'Create New $typeLabel',
            style: DsFonts.pageSubtitle,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    final name = _readValue(['AccountName', 'Name'], fallback: '');
    final code = _readValue(['AccountCode', 'CustomerID', 'Code'], fallback: '');

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: DsColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DashboardConstants.brandBlue,
              borderRadius: BorderRadius.circular(DsRadius.card),
            ),
            child: const Icon(Icons.storefront, color: Colors.white),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name, style: DsFonts.bodyBold.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (_isB2BCustomer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: DashboardConstants.brandBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('B2B', style: DsFonts.caption.copyWith(color: DashboardConstants.brandBlue, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: (_resolvedIsPrimary ? DashboardConstants.brandBlue : DsColors.error)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _resolvedIsPrimary ? 'Primary' : 'Secondary',
                        style: DsFonts.caption.copyWith(
                          color: _resolvedIsPrimary ? DashboardConstants.brandBlue : DsColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(code, style: DsFonts.caption),
                const SizedBox(height: 2),
                Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: DsFonts.caption),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Order No.', style: DsFonts.caption),
              const SizedBox(height: 2),
              Text(
                _displayOrderNo.isEmpty ? '...' : _displayOrderNo,
                style: DsFonts.bodyBold.copyWith(fontSize: 13, color: DashboardConstants.brandBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndAddRow() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _openSelectItem,
            borderRadius: BorderRadius.circular(DsRadius.button),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md, vertical: DsSpacing.md),
              decoration: BoxDecoration(
                color: DsColors.cardBg,
                borderRadius: BorderRadius.circular(DsRadius.button),
                border: Border.all(color: DsColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: DsColors.textSecondary),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(child: Text('Search product / Scan / Add item', style: DsFonts.smallText, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: DsSpacing.sm),
        ElevatedButton.icon(
          onPressed: _openSelectItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: DashboardConstants.brandBlue,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md, vertical: DsSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
          ),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: Text('Add Item', style: DsFonts.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl * 1.5),
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: DsColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 44, color: DashboardConstants.brandBlue),
          const SizedBox(height: DsSpacing.md),
          Text('No items added yet', style: DsFonts.bodyBold.copyWith(fontSize: 16)),
          const SizedBox(height: DsSpacing.xs),
          Text('Search or add items to this order', style: DsFonts.smallText),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: DsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpacing.md, DsSpacing.md, DsSpacing.md, DsSpacing.sm),
            child: Text('Order Items ($_itemCount)', style: DsFonts.bodyBold),
          ),
          const Divider(height: 1, color: DsColors.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md, vertical: DsSpacing.xs),
            itemCount: _orderItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: DsColors.border),
            itemBuilder: (context, index) => _buildItemRow(_orderItems[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: item.iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(item.icon, color: item.iconColor, size: 18),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: DsFonts.bodyBold.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('₹${item.rate.toStringAsFixed(0)} · Qty ${item.qty}', style: DsFonts.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Text('₹${item.netAmount.toStringAsFixed(2)}', style: DsFonts.bodyBold.copyWith(fontSize: 13)),
          InkWell(
            onTap: () => _removeItem(item),
            child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.delete_outline, size: 17, color: DsColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: DsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount', style: DsFonts.caption),
              Text('₹${_totalAmount.toStringAsFixed(2)}', style: DsFonts.sectionTitle.copyWith(color: DashboardConstants.brandBlue)),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              Expanded(child: Text('Sub Total: ₹${_subTotal.toStringAsFixed(2)}', style: DsFonts.smallText)),
              Expanded(child: Text('Tax: ₹${_totalTax.toStringAsFixed(2)}', style: DsFonts.smallText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Details', style: DsFonts.bodyBold),
        const SizedBox(height: DsSpacing.sm),
        TextField(
          controller: _advanceAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Advance Amount',
            filled: true,
            fillColor: DsColors.cardBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
        TextField(
          controller: _narrationController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Narration',
            filled: true,
            fillColor: DsColors.cardBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpacing.lg, DsSpacing.md, DsSpacing.lg, DsSpacing.lg),
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: DashboardConstants.brandBlue,
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
            minimumSize: const Size(double.infinity, 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
          ),
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, color: Colors.white, size: 18),
          label: Text(
            _isEditing ? 'UPDATE ORDER' : 'SAVE ORDER',
            style: DsFonts.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}