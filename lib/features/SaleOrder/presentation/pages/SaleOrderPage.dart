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
/// CHANGE LOG (fixes applied):
///   • orderSeries/orderNumber are now saved as TWO SEPARATE local columns
///     instead of being pre-joined into a single "series-number" string.
///     `orderNo` is still saved too, purely as a display/legacy string, in
///     case other screens (e.g. bill printing) still read it that way.
///     >>> DatabaseHelper's `sale_orders` table + insert method must be
///     >>> updated to add `orderSeries` (TEXT) and `orderNumber` (INTEGER)
///     >>> columns — not done here, that file wasn't available.
///   • `amount` now stores the FINAL amount (same value as `totalAmount`,
///     tax included), not the pre-tax subtotal. Previously `amount` was
///     fed `_subTotal`, which is why it showed as e.g. 190.47 instead of
///     the expected 200.0 final total.
class SaleOrderPage extends StatefulWidget {
  final Map<String, dynamic> customer;

  /// When non-null, opens in EDIT mode: a row from the local `sale_orders`
  /// table (see DatabaseHelper.getAllSaleOrders).
  final Map<String, dynamic>? orderToEdit;

  /// Line items for [orderToEdit], from `DatabaseHelper.getItemsForSaleOrder`.
  final List<Map<String, dynamic>>? orderItemsToEdit;

  const SaleOrderPage({
    super.key,
    required this.customer,
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
  // Mirrors DirectSaleOfCustomer's _billSeries/_billNo/_loadingBillNo, but
  // keyed off the *Order* prefs saved by _fetchAndSaveAllocation():
  //   B2COrderSeries, B2BOrderSeries, GreatestB2COrderBillNo,
  //   GreatestB2BOrderBillNo
  // so order numbers run their own continuous sequence (10, 11, 12, ...)
  // independent of the bill sequence.
  String _orderSeries = '';
  String _orderBillNo = '';
  bool _loadingOrderNo = true;

  bool get _isEditing => widget.orderToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _seedFromOrderToEdit();
    } else {
      _loadOrderSeriesAndNumber();
    }
    // Flush any orders saved locally while offline so they don't sit there
    // forever, same pattern as DirectSaleOfCustomer's _syncPendingBills.
    SaleOrderSyncService.instance.trySyncNow();
  }

  @override
  void dispose() {
    _advanceAmountController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  // ── Bridges between this feature's OrderItem and direct_sale's BillItem
  // (SelectItemPage only knows about BillItem — see class doc above). ──
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
      // An edit keeps its ORIGINAL order number (already the full
      // "series-number" string, or whatever was saved) rather than
      // re-deriving it from the live series/counter prefs below, which
      // may have moved on since this order was first created.
      _loadingOrderNo = false;
    });
  }

  // ── Pull the right order series + next order number from
  // SharedPreferences ──
  // These were saved at login time by _fetchAndSaveAllocation():
  //   B2COrderSeries, B2BOrderSeries, GreatestB2COrderBillNo,
  //   GreatestB2BOrderBillNo, VanID
  // NOTE: only used for a fresh (non-edit) order — see initState, which
  // skips this entirely when _isEditing and calls _seedFromOrderToEdit
  // instead, so an edited order keeps its ORIGINAL series/number.
  Future<void> _loadOrderSeriesAndNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final series = _isB2BCustomer
          ? (prefs.getString('B2BOrderSeries') ?? '')
          : (prefs.getString('B2COrderSeries') ?? '');

      final greatestOrderNo = _isB2BCustomer
          ? (prefs.getInt('GreatestB2BOrderBillNo') ?? 0)
          : (prefs.getInt('GreatestB2COrderBillNo') ?? 0);

      // The next order will be one more than the greatest already issued
      // (either synced, or already reserved locally — see
      // _bumpGreatestOrderBillNo, which runs immediately after every local
      // save, not just after a successful server sync).
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

  /// Reserves the given order number locally by bumping the stored
  /// "greatest order no" counter in SharedPreferences, if it's higher than
  /// what's already there. Called immediately after EVERY NEW local save
  /// (online or offline) — not just after a successful server sync — so
  /// the same preview order number is never handed out twice, even if the
  /// device stays offline for several orders in a row (10, then 11, then
  /// 12, ...). NOT called when editing an existing order — an edit reuses
  /// its original number and must never bump the counter.
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

  /// The order number as shown in the UI: "series-number" for a fresh
  /// order (e.g. "B2C-11"), or reconstructed from the saved
  /// orderSeries/orderNumber columns when editing an existing one.
  ///
  /// NOTE: this is a DISPLAY string only. The actual saved row (see
  /// _saveOrder) stores orderSeries and orderNumber as two SEPARATE
  /// columns — this getter just joins them for the UI, and for the
  /// legacy combined `orderNo` field kept for backward compatibility.
  String get _displayOrderNo {
    if (_isEditing) {
      final series = widget.orderToEdit?['orderSeries']?.toString() ?? '';
      final number = widget.orderToEdit?['orderNumber']?.toString() ?? '';
      if (series.isEmpty && number.isEmpty) {
        // Fallback for rows saved before this fix, which only have the
        // old combined `orderNo` column.
        return widget.orderToEdit?['orderNo']?.toString() ?? '';
      }
      return series.isEmpty ? number : '$series-$number';
    }
    if (_loadingOrderNo) return '...';
    return _orderSeries.isEmpty ? _orderBillNo : '$_orderSeries-$_orderBillNo';
  }

  /// Reconstructs an OrderItem from a `sale_order_items` row. Unlike
  /// DirectSaleOfCustomer's bill_items (which only stores a combined
  /// taxAmount), this table's taxRate column already holds the ORIGINAL
  /// combined tax percentage as text (the CGST/SGST split only happens at
  /// sync-payload time — see SaleOrderSyncService — never stored locally
  /// as the split), so taxPercent can be read directly rather than
  /// back-solved.
  OrderItem _orderItemFromRow(Map<String, dynamic> row, Map<String, ProductData> productLookup) {
    final productId = row['productId']?.toString() ?? '';
    final product = productLookup[productId];
    final taxPercent = double.tryParse(row['taxRate']?.toString() ?? '') ?? 0;

    return OrderItem(
      productId: productId,
      name: row['itemName']?.toString() ?? (product?.displayName ?? 'Item'),
      icon: product?.icon ?? Icons.inventory_2_outlined,
      iconColor: product?.iconColor ?? DashboardConstants.brandBlue,
      rateType: 'MRP', // sale_order_items has no rateType column server-side
      rate: (row['rate'] as num?)?.toDouble() ?? 0,
      qty: (row['qty'] as num?)?.toInt() ?? 0,
      freeQty: (row['freeQty'] as num?)?.toInt() ?? 0,
      unitId: '', // AliaseSalesDetails has no UnitID column, unlike BillingDetails
      discountType: DiscountType.percent,
      discountValue: (row['discountPercent'] as num?)?.toDouble() ?? 0,
      taxPercent: taxPercent,
      taxMode: 'INCLUDE', // orders don't currently carry a per-order tax-mode flag
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

      // IMPORTANT: CustomerID sent to the server must be the customer's
      // real numeric database id (matches AliaseSales.CustomerID FK), NOT
      // their display code. Try the likely numeric-id keys FIRST; only
      // fall back to AccountCode/Code as a last resort (which will send
      // the wrong value to the server if hit — if you see CustomerID
      // sync issues again, the actual key name needs to be confirmed
      // here).
      final customerId = _readValue(
        ['CustomerId', 'customerId', 'CustomerID', 'Id', 'id', 'AccountCode', 'Code'],
      );
      final customerName = _readValue(['AccountName', 'Name']);
      final advanceAmount = double.tryParse(_advanceAmountController.text) ?? 0;

      final createdDate = _isEditing
          ? (widget.orderToEdit!['createdDate']?.toString() ?? now.toIso8601String())
          : now.toIso8601String();
      final orderDate = _isEditing
          ? (widget.orderToEdit!['orderDate']?.toString() ?? now.toIso8601String())
          : now.toIso8601String();

      // Order series / order number, kept as two SEPARATE values.
      // - New order: series = _orderSeries, number = parsed _orderBillNo
      // - Edit: reuse whatever was already stored on the row
      final orderSeries = _isEditing
          ? (widget.orderToEdit!['orderSeries']?.toString() ?? '')
          : _orderSeries;
      final orderNumber = _isEditing
          ? (widget.orderToEdit!['orderNumber'] as int? ?? 0)
          : (int.tryParse(_orderBillNo) ?? 0);

      final localOrder = {
        'suitAppsId': suitAppsId,
        'serverOrderId': _isEditing ? widget.orderToEdit!['serverOrderId'] : null,
        // Separate columns now — see DatabaseHelper TODO in the class doc
        // comment at the top of this file. `orderSeries` is TEXT (e.g.
        // "B2C"), `orderNumber` is an INTEGER (e.g. 11).
        'orderSeries': orderSeries,
        'orderNumber': orderNumber,
        // Legacy combined display string kept alongside, in case any
        // other screen (e.g. bill printing) still reads `orderNo` as one
        // "series-number" string. Safe to drop once nothing depends on it.
        'orderNo': _displayOrderNo,
        'orderDate': orderDate,
        'customerId': customerId,
        'customerName': customerName,
        'customerSuitAppsId': _readValue(['CustomerSuitAppsId'], fallback: ''),
        'userId': userId,
        'companyId': companyId,
        // Now the FINAL amount (tax included), same as totalAmount —
        // previously this was fed `_subTotal` (pre-tax), which is why it
        // showed a stripped-down value instead of the real final total.
        'amount': _totalAmount,
        'advanceAmount': advanceAmount,
        'totalAmount': _totalAmount,
        'orderStatus': _orderStatus,
        'discount': _totalDiscount,
        'discountRate': '',
        // Bill_Series / BillNo now mirror the order's own series/number
        // (orderSeries/orderNumber) at save time, for BOTH new orders and
        // edits — per team decision, populated immediately rather than
        // waiting for a separate "convert order to bill" flow.
        // AliasBillNo uses the "userId-sequenceNumber" pattern (e.g.
        // "3-4"), matching the UID+'-'+NO pattern Sync_AliasDirectSales
        // itself uses when generating OrderNo server-side.
        'billSeries': orderSeries,
        'billNo': orderNumber.toString(),
        'aliasBillNo': '$userId-$orderNumber',
        'fYearId': fYearId,
        'invType': _isB2BCustomer ? 'B2B' : 'B2C',
        'billMode': 0,
        'narration': _narrationController.text,
        'createdBy': userId,
        'createdDate': createdDate,
        // Always 0 — see DatabaseHelper._createSaleOrderTables comments.
        'modifiedBy': 0,
        'modifiedDate': now.toIso8601String(),
        'deletedBy': 0,
        'deletedDate': null,
        'isDeleted': 0,
        'isSynced': 0,
      };

      final localItems = _orderItems.map((item) {
        final itemSuitAppsId = nextSuitAppsId();
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
          // Combined tax kept as-is locally; CGST/SGST split happens only
          // at sync-payload time (see SaleOrderSyncService).
          'taxRate': item.taxPercent.toString(),
          'taxAmount': item.taxAmount,
          'cgstRate': null,
          'cgstAmount': null,
          'sgstRate': null,
          'sgstAmount': null,
          'fCessRate': null,
          'fCessAmount': null,
          'discountPercent': item.discountPercentDisplay,
          'discountAmount': item.discountAmount,
          'isSynced': 0,
        };
      }).toList();

      // REPLACEs on the unique suitAppsId + deletes/reinserts items —
      // acts as an update when editing, same trick as insertBillWithItems.
      await DatabaseHelper.instance.insertSaleOrderWithItems(localOrder, localItems);

      // Reserve this order number immediately, unconditionally — but ONLY
      // for a brand-new order. An edit reuses its original number and
      // must never bump the counter (that would let a later new order
      // accidentally skip/collide with numbers).
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
          Text(_isEditing ? 'Update Order' : 'Create New Order', style: DsFonts.pageSubtitle),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    final name = _readValue(['AccountName', 'Name'], fallback: 'ABC STORES');
    final code = _readValue(['AccountCode', 'CustomerID', 'Code'], fallback: 'C000125');

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
        const SizedBox(height: DsSpacing.sm),
        DropdownButtonFormField<double>(
          initialValue: _orderStatus,
          decoration: InputDecoration(
            labelText: 'Order Status',
            filled: true,
            fillColor: DsColors.cardBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
          ),
          items: _orderStatusOptions
              .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
              .toList(),
          onChanged: (value) => setState(() => _orderStatus = value ?? 0),
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