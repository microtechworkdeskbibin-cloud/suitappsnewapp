import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:suitapps/core/database/session_storage.dart';
import 'package:suitapps/features/direct_sale/data/datasources/billing_api_datasource.dart';
import 'package:uuid/uuid.dart';
import 'package:suitapps/features/direct_sale/presentation/theme/direct_sale_theme.dart';
import 'package:suitapps/features/direct_sale/presentation/pages/select_item_page.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';
import 'package:suitapps/features/direct_sale/data/models/Bill_model.dart';
import 'package:suitapps/features/direct_sale/data/models/sale_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/core/database/database_helper.dart'; // adjust path if different
import 'package:suitapps/features/direct_sale/services/invoice_pdf_service.dart'; // adjust path if different

// Fallback so this file compiles even if `outerRadius` isn't already a
// top-level constant in your project. Delete this if DashboardConstants
// (or another file you already import) provides its own `outerRadius`.
const double outerRadius = DsRadius.card;

class DirectSaleOfCustomer extends StatefulWidget {
  final Map<String, dynamic> customer;

  /// When non-null, the page opens in EDIT mode instead of "new bill":
  /// this is a row from the local `bills` table (see
  /// DatabaseHelper.getAllBills / _saveBill's `localBill` map below).
  final Map<String, dynamic>? billToEdit;

  /// Line items for [billToEdit], from `DatabaseHelper.getItemsForBill`.
  /// Only meaningful together with [billToEdit].
  final List<Map<String, dynamic>>? billItemsToEdit;

  const DirectSaleOfCustomer({
    super.key,
    required this.customer,
    this.billToEdit,
    this.billItemsToEdit,
  });

  @override
  State<DirectSaleOfCustomer> createState() => _DirectSaleOfCustomerState();
}

class _DirectSaleOfCustomerState extends State<DirectSaleOfCustomer> {
  List<BillItem> _billItems = [];
  String _selectedPaymentType = 'Cash';
  bool _isSaving = false;
  bool _isSyncingPending = false;
  final _uuid = const Uuid();

  bool get _isEditing => widget.billToEdit != null;

  // â”€â”€ Bill series / number (B2B vs B2C) â”€â”€
  String _billSeries = '';
  String _billNo = '';
  bool _loadingBillNo = true;

  // Max height for the scrollable bill-items box. Sized so that 4 rows
  // fit fully in view (each compact row is ~78px including its divider);
  // once there are more than 4 items the box scrolls internally instead
  // of pushing the summary/payment/action bar further down the page.
  static const double _billItemsBoxMaxHeight = 312;

  static const List<Map<String, dynamic>> _paymentTypes = [
    {'label': 'Cash', 'icon': Icons.payments_outlined},
    {'label': 'UPI', 'icon': Icons.qr_code_2_outlined},
    {'label': 'Credit', 'icon': Icons.receipt_long_outlined},
    {'label': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _seedFromBillToEdit();
    } else {
      _loadBillSeriesAndNumber();
    }
    // Attempt to flush any bills that were saved locally while offline
    // and never made it to the server, so they don't sit there forever
    // and so their bill numbers get properly reconciled server-side.
    _syncPendingBills();
  }

  // Tries prefs.getInt() for each key in order; if that key holds a
  // String instead (e.g. saved via setString by mistake at login), falls
  // back to int.tryParse on the String. Returns 0 if nothing matches.
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

  // â”€â”€ Read helpers (tolerant of whatever keys your customer map uses) â”€â”€
  String _readValue(List<String> keys, {String fallback = 'N/A'}) {
    for (final key in keys) {
      final value = widget.customer[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  // â”€â”€ B2B detection: customer counts as B2B if a GST number is present â”€â”€
  String get _gstNumber => _readValue(
        ['GSTNumber', 'GSTIN', 'GstNo', 'Gst', 'GST'],
        fallback: '',
      );

  // In edit mode the customer map is reconstructed from the bill's stored
  // headerPayloadJson (see DirectSaleListPage._openForEdit), which carries
  // an 'InvoiceType' field ('B2B'/'B2C') but NOT the original GSTIN â€” that
  // was never persisted locally. So during edit, trust InvoiceType first;
  // otherwise fall back to the normal GST-number check used for a fresh
  // sale.
  bool get _isB2BCustomer {
    if (_isEditing) {
      final invoiceType = _readValue(['InvoiceType'], fallback: '').toUpperCase();
      if (invoiceType == 'B2B') return true;
      if (invoiceType == 'B2C') return false;
    }
    return _gstNumber.isNotEmpty && _gstNumber != 'N/A';
  }

  /// Rebuilds `_billItems` / `_billSeries` / `_billNo` / `_selectedPaymentType`
  /// from [widget.billToEdit] / [widget.billItemsToEdit] instead of
  /// starting a fresh bill. Called once from initState when [_isEditing].
  Future<void> _seedFromBillToEdit() async {
    final bill = widget.billToEdit!;

    final isExcluding = bill['isExcluding'];
    final taxMode = (isExcluding == 1 || isExcluding.toString() == '1') ? 'EXCLUDE' : 'INCLUDE';

    // Used only to recover each line's icon/color for display â€” falls
    // back to a generic icon if the product no longer exists locally
    // (e.g. removed from the van in a later sync) or lookup fails.
    List<ProductData> products = [];
    try {
      products = await DatabaseHelper.instance.getVanItems();
    } catch (_) {
      // Non-fatal â€” items just render with a generic icon below.
    }
    final productLookup = {for (final p in products) p.id: p};

    final items = (widget.billItemsToEdit ?? [])
        .map((row) => _billItemFromRow(row, productLookup, taxMode))
        .toList();

    if (!mounted) return;
    setState(() {
      _billSeries = bill['billSeries']?.toString() ?? '';
      _billNo = bill['billNo']?.toString() ?? '';
      _loadingBillNo = false;
      _selectedPaymentType = bill['paymentType']?.toString() ?? 'Cash';
      _billItems = items;
    });
  }

  /// Reconstructs one BillItem from a `bill_items` row.
  ///
  /// Most fields map straight across, but `taxPercent` isn't stored as its
  /// own column â€” only the already-computed `grossAmount`, `discountAmount`,
  /// and `taxAmount` are. Rather than re-look up taxPercent from the
  /// product master (which may have changed since, or the product may no
  /// longer exist locally), it's back-solved from those stored amounts:
  /// taxableAmount = grossAmount - discountAmount is the same base
  /// BillItem.taxAmount is computed from, so reversing that division
  /// reproduces the original taxPercent (aside from floating-point
  /// rounding) once BillItem's own getters recompute from
  /// rate/qty/taxPercent/taxMode.
  BillItem _billItemFromRow(
    Map<String, dynamic> row,
    Map<String, ProductData> productLookup,
    String taxMode,
  ) {
    final productId = row['productId']?.toString() ?? '';
    final product = productLookup[productId];

    final rate = (row['rate'] as num?)?.toDouble() ?? 0;
    final qty = (row['qty'] as num?)?.toInt() ?? 0;
    final freeQty = (row['freeQty'] as num?)?.toInt() ?? 0;
    final grossAmount = (row['grossAmount'] as num?)?.toDouble() ?? 0;
    final discountAmount = (row['discountAmount'] as num?)?.toDouble() ?? 0;
    final storedTaxAmount = (row['taxAmount'] as num?)?.toDouble() ?? 0;

    final taxableAmount = grossAmount - discountAmount;
    final taxPercent = taxableAmount > 0 ? (storedTaxAmount / taxableAmount * 100) : 0.0;

    return BillItem(
      productId: productId,
      name: row['itemName']?.toString() ?? (product?.displayName ?? 'Item'),
      icon: product?.icon ?? Icons.inventory_2_outlined,
      iconColor: product?.iconColor ?? DashboardConstants.brandBlue,
      rateType: row['rateType']?.toString() ?? 'MRP',
      rate: rate,
      qty: qty,
      freeQty: freeQty,
      unitId: row['unitId']?.toString() ?? '',
      discountType: DiscountType.percent,
      discountValue: (row['discountPercent'] as num?)?.toDouble() ?? 0,
      taxPercent: taxPercent,
      taxMode: taxMode,
    );
  }

  // â”€â”€ Pull the right series + next bill number from SharedPreferences â”€â”€
  // These were saved at login time by _fetchAndSaveAllocation():
  //   B2CSeries, B2BSeries, GreatestB2CBillNo, GreatestB2BBillNo, VanID
  // NOTE: only used for a fresh (non-edit) bill â€” see initState, which
  // skips this entirely when _isEditing and calls _seedFromBillToEdit
  // instead, so an edited bill keeps its ORIGINAL series/number.
  Future<void> _loadBillSeriesAndNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final series = _isB2BCustomer
          ? (prefs.getString('B2BSeries') ?? '')
          : (prefs.getString('B2CSeries') ?? '');

      final greatestBillNo = _isB2BCustomer
          ? (prefs.getInt('GreatestB2BBillNo') ?? 0)
          : (prefs.getInt('GreatestB2CBillNo') ?? 0);

      // The next bill will be one more than the greatest already issued
      // (either synced, or already reserved locally â€” see
      // _bumpGreatestBillNo, which now runs immediately after every local
      // save, not just after a successful server sync).
      final nextBillNo = (greatestBillNo + 1).toString();

      if (!mounted) return;
      setState(() {
        _billSeries = series;
        _billNo = nextBillNo;
        _loadingBillNo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBillNo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load bill number: $e')),
      );
    }
  }

  // â”€â”€ Totals â”€â”€
  int get _itemCount => _billItems.length;

  int get _totalQty => _billItems.fold(0, (sum, item) => sum + item.qty);

  // FIX: Sub Total must be the POST-discount taxable base, i.e.
  // item.taxableAmount (grossAmount - discountAmount), NOT item.grossAmount
  // (which is the PRE-discount base). Summing grossAmount was the bug: it
  // left the discount out of Sub Total entirely, so Sub Total + Tax didn't
  // add up to the actual Total Amount.
  //
  // Example (rate=100, qty=1, taxPercent=5, disc=20%):
  //   grossAmount (pre-discount base)   = 100 / 1.05        = 95.24  âŒ old Sub Total
  //   discountAmount (20% of 95.24)     = 19.05
  //   taxableAmount (post-discount base)= 95.24 - 19.05      = 76.19 âœ… new Sub Total
  //   taxAmount (5% of 76.19)           = 3.81
  //   Sub Total + Tax = 76.19 + 3.81    = 80.00  â†’ matches netAmount / Total Amount
  double get _subTotal => _billItems.fold(0, (sum, item) => sum + item.taxableAmount);

  double get _totalDiscount => _billItems.fold(0, (sum, item) => sum + item.discountAmount);

  double get _totalTax => _billItems.fold(0, (sum, item) => sum + item.taxAmount);

  // Total = Sub Total (post-discount, pre-tax) + Tax.
  // _totalDiscount is still surfaced (via _buildInlineStat('Discount', ...))
  // purely as an informational "you saved â‚¹X" figure â€” it is NOT
  // subtracted again here, since _subTotal already reflects the
  // post-discount base.
  double get _preRoundTotal => _subTotal + _totalTax;

  double get _roundOff => double.parse((_preRoundTotal.roundToDouble() - _preRoundTotal).toStringAsFixed(2));

  double get _totalAmount => _preRoundTotal + _roundOff;

  // â”€â”€ IsExcluding: 0 = tax-inclusive calc, 1 = tax-exclusive calc.
  // Derived from the taxMode chosen on SelectItemPage (see
  // _SelectItemPageState._taxMode / TAX_MODE permission), which is carried
  // onto every BillItem via _LineDraft.toBillItem. All items in a single
  // bill share the same mode (it's chosen once per bill on that screen),
  // so it's safe to read it off the first item. Defaults to 0 (Include)
  // when there are no items yet.
  int get _isExcluding =>
      _billItems.isNotEmpty && _billItems.first.taxMode == 'EXCLUDE' ? 1 : 0;

  Future<void> _openSelectItem() async {
    final prefs = await SharedPreferences.getInstance();

    // Saved at login time (see LoginPage._login / _fetchAndSaveAllocation):
    //   VanID        -> int,    e.g. prefs.setInt('VanID', ...)
    //   CompanyID    -> String, e.g. prefs.setString('CompanyID', ...)
    //   UserID       -> int (or String under a slightly different key â€”
    //                  see _readIntPref, same tolerant read used in
    //                  _saveBill so both places agree on where this
    //                  comes from).
    final vanId = prefs.getInt('VanID') ?? 0;
    final companyIdStr = prefs.getString('CompanyID') ??
        prefs.getString('SelectedCompanyId') ??
        '0';
    final companyId = int.tryParse(companyIdStr) ?? 0;
    final userId = _readIntPref(prefs, ['UserID', 'UserId', 'User_ID']);

    if (!mounted) return;

    final result = await Navigator.push<List<BillItem>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectItemPage(
          customer: widget.customer,
          initialItems: _billItems,
          vanId: vanId,
          companyId: companyId,
          userId: userId,
        ),
      ),
    );

    if (result != null) {
      setState(() => _billItems = result);
    }
  }

  void _removeItem(BillItem item) {
    setState(() => _billItems.removeWhere((i) => i.productId == item.productId));
  }

  void _showStubMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action tapped â€” wire this up to your backend.')),
    );
  }

  /// Reserves the given bill number locally by bumping the stored
  /// "greatest bill no" counter in SharedPreferences, if it's higher than
  /// what's already there. This is called immediately after EVERY NEW
  /// local save (online or offline) â€” not just after a successful server
  /// sync â€” so the same preview bill number is never handed out twice,
  /// even if the device stays offline for several bills in a row.
  /// NOT called when editing an existing bill (see _saveBill) â€” an edit
  /// reuses its original number and must never bump the counter.
  Future<void> _bumpGreatestBillNo(int savedBillNo) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isB2BCustomer ? 'GreatestB2BBillNo' : 'GreatestB2CBillNo';
    final current = prefs.getInt(key) ?? 0;

    if (savedBillNo > current) {
      await prefs.setInt(key, savedBillNo);
    }

    if (!mounted) return;
    await _loadBillSeriesAndNumber();
  }

  /// Re-attempts sync for any locally saved bills that never made it to
  /// the server (isSynced = 0), oldest first so bill order/sequence is
  /// preserved server-side. Safe to call repeatedly â€” bills already
  /// synced are skipped, and a bill that still fails (still offline /
  /// server unreachable) is simply left for the next attempt.
  ///
  /// Note: since headerPayloadJson stores the FULL header payload
  /// (including IsExcluding), this method needs no changes to carry that
  /// flag along on retry â€” it just replays whatever's in the JSON blob.
  Future<void> _syncPendingBills() async {
    if (_isSyncingPending) return; // avoid overlapping runs
    _isSyncingPending = true;

    try {
      List<Map<String, dynamic>> pending;
      try {
        pending = await DatabaseHelper.instance.getUnsyncedBills();
      } catch (e) {
        debugPrint('Could not read unsynced bills: $e');
        return;
      }

      if (pending.isEmpty) return;

      for (final bill in pending) {
        final suitAppsId = bill['suitAppsId'] as String?;
        if (suitAppsId == null) continue;

        final headerPayloadJson = bill['headerPayloadJson'] as String?;
        if (headerPayloadJson == null || headerPayloadJson.isEmpty) {
          // Older local rows saved before this column existed â€” nothing
          // to replay for these; skip rather than crash.
          debugPrint('Skipping pending bill $suitAppsId â€” no stored payload.');
          continue;
        }

        try {
          final items = await DatabaseHelper.instance.getItemsForBill(suitAppsId);

          final headerPayload =
              jsonDecode(headerPayloadJson) as Map<String, dynamic>;

          final headerResult =
              await BillingApiService.syncBillingHeader(headerPayload);
          final serverBillId = headerResult['BillID']?.toString();
          if (serverBillId == null) continue;

          final detailPayloads = <Map<String, dynamic>>[];
          for (final item in items) {
            final detailJson = item['detailPayloadJson'] as String?;
            if (detailJson == null || detailJson.isEmpty) continue;
            final payload = jsonDecode(detailJson) as Map<String, dynamic>;
            payload['DSID'] = serverBillId;
            detailPayloads.add(payload);
          }

          if (detailPayloads.isNotEmpty) {
            await BillingApiService.syncBillingDetails(detailPayloads);
          }

          await DatabaseHelper.instance.markBillSynced(suitAppsId, serverBillId);
          debugPrint('Synced pending bill $suitAppsId -> server $serverBillId');
        } catch (e) {
          // Still offline / server unreachable â€” leave it for the next
          // attempt (next screen open, next save, etc.) rather than
          // blocking the rest of the queue.
          debugPrint('Retry failed for pending bill $suitAppsId: $e');
          continue;
        }
      }
    } finally {
      _isSyncingPending = false;
    }
  }

  // â”€â”€ Save (local DB first, then sync to server) â”€â”€
  Future<void> _saveBill({required bool print}) async {
    if (_billItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Flush any older pending bills first so a NEW bill gets a number
      // that comes after them, and so we don't keep piling up an
      // unbounded backlog while online. Harmless to run when editing too.
      await _syncPendingBills();

      final prefs = await SharedPreferences.getInstance();

      // â”€â”€ DEBUG: dump every SharedPreferences key/value once, so you can
      // see the *exact* key names and types actually stored at login.
      // If 'UserID' / 'FYearID' aren't in this list (or show up under a
      // different casing, e.g. 'UserId'), that's why they're coming
      // through as 0 below. Remove this block once confirmed.
      for (final key in prefs.getKeys().toList()..sort()) {
        final value = prefs.get(key);
        debugPrint('prefs: $key = $value (${value.runtimeType})');
      }

      final companyId = prefs.getString('CompanyID') ??
          prefs.getString('SelectedCompanyId') ??
          '0';
      // Tolerant read: tries the int getter first, then falls back to
      // parsing a String value (covers the case where login saved this
      // key with setString instead of setInt), and finally tries a
      // couple of common alternate key spellings.
      final userId = _readIntPref(prefs, ['UserID', 'UserId', 'User_ID']);
      final routeId = prefs.getInt('RouteID') ?? 0;

      final now = DateTime.now();

      // â”€â”€ SuitApps_id generator: userId + yyyyMMddHHmmss + a running
      // sequence number (1 for the header, 2/3/4... for each line item)
      // so every id generated in this save is unique but still traces
      // back to who/when created it, instead of a random UUID.
      int _suitAppsSeq = 0;
      String _nextSuitAppsId() {
        _suitAppsSeq++;
        final ts = '${now.year.toString().padLeft(4, '0')}'
            '${now.month.toString().padLeft(2, '0')}'
            '${now.day.toString().padLeft(2, '0')}'
            '${now.hour.toString().padLeft(2, '0')}'
            '${now.minute.toString().padLeft(2, '0')}'
            '${now.second.toString().padLeft(2, '0')}';
        return '$userId-$ts-$_suitAppsSeq';
      }

      // EDIT: reuse the original bill's local id so
      // DatabaseHelper.insertBillWithItems (which REPLACEs on the unique
      // suitAppsId and always deletes+reinserts that bill's items) acts
      // as an update instead of creating a second bill.
      final suitAppsId = _isEditing
          ? (widget.billToEdit!['suitAppsId'] as String)
          : _nextSuitAppsId(); // header â†’ sequence 1

      final customerId = _readValue(['CustomerID', 'AccountCode', 'Code']);
      final customerName = _readValue(['AccountName', 'Name']);
      final cumAddress = _readValue(['Address'], fallback: '');
      final cumContact = _readValue(['Contact', 'Phone'], fallback: '');
      final cumPlace = _readValue(['Place'], fallback: '');

      final fYearId = _readIntPref(prefs, ['FYearID', 'FYearId', 'FyearID']);
      if (userId == 0) {
        debugPrint('âš ï¸  UserID resolved to 0 â€” check the prefs dump above '
            'for the actual key/value saved at login.');
      }
      if (fYearId == 0) {
        debugPrint('âš ï¸  FYearID resolved to 0 â€” check the prefs dump above '
            'for the actual key/value saved at login.');
      }

      // EDIT: keep the ORIGINAL series this bill was created under,
      // rather than re-reading the current InvSeriesB2B/B2C prefs (which
      // may have changed since). New bills still read the live prefs as
      // before.
      final String invSeries;
      if (_isEditing) {
        invSeries = widget.billToEdit!['billSeries']?.toString() ?? _billSeries;
      } else {
        final billSeriesKey = _isB2BCustomer ? 'InvSeriesB2B' : 'InvSeriesB2C';
        invSeries = prefs.getString(billSeriesKey) ?? _billSeries;
      }

      // â”€â”€ IsExcluding: 0 = tax-inclusive calc, 1 = tax-exclusive calc.
      // Derived from the taxMode chosen on SelectItemPage and carried on
      // every BillItem (see the getter above). Computed once here so the
      // exact same value goes into both the server payload and the local
      // row below.
      final isExcluding = _isExcluding;

      // EDIT: if this bill already made it to the server, its serverBillId
      // is sent as DSID so the server UPDATEs that row instead of
      // inserting a duplicate. 0 for a brand-new bill, or an edit of a
      // bill that never successfully synced in the first place.
      final int dsid = _isEditing
          ? (int.tryParse(widget.billToEdit!['serverBillId']?.toString() ?? '') ?? 0)
          : 0;

      // â”€â”€ Header payload for the server (Sync_BillingApp2 params) â”€â”€
      final headerPayload = {
        'DSID': dsid,
        'BillNo': int.tryParse(_billNo) ?? 0,
        'BillDate': now.toIso8601String().split('T').first,
        'BillMode': _selectedPaymentType == 'Credit' ? 1 : 0,
        'CustomerName': customerName,
        'FYearID': fYearId,
        'Amount': _totalAmount,
        'SubTotal': _subTotal,
        'Tax_Amt': _totalTax,
        'IsDeleted': 0,
        'CompanyID': int.tryParse(companyId) ?? 0,
        'InvoiceType': _isB2BCustomer ? 'B2B' : 'B2C',
        'CustomerID': int.tryParse(customerId) ?? 0,
        'Roundoff': _roundOff,
        'CumAddress': cumAddress,
        'CumContact': cumContact,
        'UserID': userId,
        'OrderNo': '',
        'RouteID': routeId,
        'CumPlace': cumPlace,
        'Bill_Series': invSeries,
        'SuitApps_id': suitAppsId,
        'IsExcluding': isExcluding, // NEW â€” 0=Include tax, 1=Exclude tax
      };

      // EDIT: keep the ORIGINAL createdAt/billDate rather than resetting
      // them to "now" â€” a bill's creation/transaction date shouldn't move
      // just because it was edited.
      final createdAt = _isEditing
          ? (widget.billToEdit!['createdAt']?.toString() ?? now.toIso8601String())
          : now.toIso8601String();
      final billDate = _isEditing
          ? (widget.billToEdit!['billDate']?.toString() ?? now.toIso8601String())
          : now.toIso8601String();

      // â”€â”€ Row for the local `bills` table â”€â”€
      // headerPayloadJson stores the exact payload above, so a later
      // retry (via _syncPendingBills) can replay it unchanged, including
      // IsExcluding.
      final localBill = {
        'suitAppsId': suitAppsId,
        'billNo': _billNo,
        'billSeries': invSeries,
        'customerId': customerId,
        'customerName': customerName,
        'companyId': companyId,
        'paymentType': _selectedPaymentType,
        'subTotal': _subTotal,
        'totalDiscount': _totalDiscount,
        'totalTax': _totalTax,
        'roundOff': _roundOff,
        'totalAmount': _totalAmount,
        'billDate': billDate,
        'isSynced': 0,
        'serverBillId': _isEditing ? widget.billToEdit!['serverBillId'] : null,
        'createdAt': createdAt,
        'isExcluding': isExcluding, // NEW â€” mirrors headerPayload['IsExcluding']
        'headerPayloadJson': jsonEncode(headerPayload),
      };

      // â”€â”€ Rows for the local `bill_items` table â”€â”€
      // detailPayloadJson stores the exact per-item payload that will be
      // sent to syncBillingDetails (minus DSID, which is only known once
      // the header sync returns a serverBillId â€” filled in at sync time).
      final localItems = _billItems.map((item) {
        final itemSuitAppsId = _nextSuitAppsId(); // header=1, items=2,3,4...

        final detailPayload = {
          'ItemID': item.productId,
          'ItemName': item.name,
          'Qty': item.qty,
          'UnitID': item.unitId,
          'Rate': item.rate,
          'MRP': item.rate, // TODO: replace with real MRP field if available
          'Tax_Rate': 0,     // TODO: wire up real tax rate field
          // FIX: this maps to the server's NetRate column, which must be
          // the POST-discount taxable base (item.taxableAmount), not the
          // pre-discount base (item.grossAmount). Sending grossAmount was
          // why NetRate showed 95.2380 (tax extracted from 100 before the
          // 20% discount) instead of the correct 76.1905 (tax extracted
          // from 100 -> 80 after the discount) â€” same root cause as the
          // Sub Total bug fixed earlier in _subTotal.
          'GrossValue': item.taxableAmount,
          'Tax_Amt': item.taxAmount,
          'NetAmount': item.netAmount,
          'disptg': item.discountPercentDisplay,
          'disamt': item.discountAmount,
          'FreeQuantity': item.freeQty,
          'SampleQty': 0,
          'SuitApps_id': itemSuitAppsId,
        };

        return {
          'suitAppsId': itemSuitAppsId,
          'productId': item.productId,
          'itemName': item.name,
          'qty': item.qty,
          'freeQty': item.freeQty,
          'rate': item.rate,
          'rateType': item.rateType,
          // Saved locally so a retried sync (via _syncPendingBills, which
          // replays detailPayloadJson) still carries the correct unit â€”
          // it doesn't need to re-derive it from the product at sync time.
          'unitId': item.unitId,
          'grossAmount': item.grossAmount,
          'discountPercent': item.discountPercentDisplay,
          'discountAmount': item.discountAmount,
          'taxAmount': item.taxAmount,
          'netAmount': item.netAmount,
          'isSynced': 0,
          'detailPayloadJson': jsonEncode(detailPayload),
        };
      }).toList();

      // â”€â”€ 1. Save locally first (offline-first) â”€â”€
      // For an edit this REPLACEs the existing row (matched on the
      // unique suitAppsId) and deletes+reinserts its items â€” i.e. this
      // one call handles both "create" and "update".
      await DatabaseHelper.instance.insertBillWithItems(localBill, localItems);

      // â”€â”€ 1b. Reserve this bill number immediately, unconditionally â€”
      // but ONLY for a brand-new bill. An edit reuses its original
      // number and must never bump the counter (that would let a later
      // new bill accidentally skip/collide with numbers).
      if (!_isEditing) {
        await _bumpGreatestBillNo(int.tryParse(_billNo) ?? 0);
      }

      // â”€â”€ 2. Try syncing to server â”€â”€
      try {
        final headerResult = await BillingApiService.syncBillingHeader(headerPayload);
        final serverBillId = headerResult['BillID']?.toString();

        if (serverBillId != null) {
          final detailPayloads = localItems.map((localItem) {
            final payload =
                jsonDecode(localItem['detailPayloadJson'] as String)
                    as Map<String, dynamic>;
            payload['DSID'] = serverBillId;
            return payload;
          }).toList();

          await BillingApiService.syncBillingDetails(detailPayloads);
          await DatabaseHelper.instance.markBillSynced(suitAppsId, serverBillId);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Bill updated successfully.'
                : (print ? 'Bill saved & sent to print.' : 'Bill saved successfully.')),
          ),
        );

        // â”€â”€ Build the invoice PDF data and show View/Share/Bluetooth popup.
        // Company details (name/address/GSTIN/mobile/phone) come from
        // SessionStore.getCompanyDetails() â€” saved once at login/company
        // selection â€” instead of being re-read/hardcoded from prefs here.
        // Bank/UPI details still come straight from prefs until you decide
        // where those should live permanently; replace the pref keys with
        // whatever your login flow actually saves.
        final company = await SessionStore.getCompanyDetails();
        final upiVpa = prefs.getString('UpiVpa');

        final invoiceData = await buildInvoiceDataWithSessionCompany(
          customerName: customerName,
          customerGst: _gstNumber,
          customerAddress: cumAddress,
          paymentType: _selectedPaymentType,
          invoiceNo: invSeries.isEmpty ? _billNo : '$invSeries-$_billNo',
          invoiceDate: now,
          salesman: prefs.getString('UserName') ?? 'ADMIN',
          items: _billItems.map((item) {
            return InvoiceItemData(
              name: item.name,
              // TODO: BillItem needs an `hsnCode` field â€” see the note at
              // the bottom of invoice_pdf_service.dart for the 2-line fix.
              hsn: '',
              qty: item.qty,
              freeQty: item.freeQty,
              mrp: item.rate,
              rate: item.rate,
              amount: item.grossAmount,
              grossAmt: item.taxableAmount,
              gstPercent: item.taxPercent,
              gstAmt: item.taxAmount,
              netAmount: item.netAmount,
            );
          }).toList(),
          roundOff: _roundOff,
          grandTotal: _totalAmount,
          bankName: prefs.getString('BankName') ?? '',
          bankAccountNo: prefs.getString('BankAccountNo') ?? '',
          bankIfsc: prefs.getString('BankIFSC') ?? '',
          bankBranch: prefs.getString('BankBranch') ?? '',
          qrData: upiVpa != null
              ? 'upi://pay?pa=$upiVpa&pn=${Uri.encodeComponent(company.companyName)}&am=${_totalAmount.toStringAsFixed(2)}&cu=INR'
              : '',
        );

        if (mounted) {
          showInvoiceActionsSheet(
            context,
            invoiceData,
            // TODO: wire this to your existing Bluetooth thermal-printer
            // flow instead of leaving it null.
            onBluetoothPrint: null,
          );
        }
      } catch (syncError) {
        // Saved locally but sync failed â€” bill number is already
        // reserved (step 1b above, new bills only), so it's safe to
        // leave this bill as isSynced = 0. It will be retried
        // automatically by _syncPendingBills() the next time this screen
        // opens, or right before the next bill is saved.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved offline. Will sync when online. ($syncError)'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      if (!mounted) return;
      if (_isEditing) {
        // Back to DirectSaleListPage, which refreshes on return.
        Navigator.pop(context);
      } else {
        setState(() {
          _billItems = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save bill: $e')),
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
            if (_billItems.isEmpty) _buildEmptyState() else _buildBillItemsList(),
            const SizedBox(height: DsSpacing.lg),
            _buildSummaryCard(),
            const SizedBox(height: DsSpacing.lg),
            _buildPaymentTypeSection(),
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
          Text('Billing', style: DsFonts.pageTitle),
          Text(_isEditing ? 'Update Invoice' : 'Create New Invoice', style: DsFonts.pageSubtitle),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildCustomerCard() {
    final name = _readValue(['AccountName', 'Name'], fallback: 'ABC STORES');
    final code = _readValue(['AccountCode', 'CustomerID', 'Code'], fallback: 'C000125');
    final distance = _readValue(['Distance'], fallback: '120 m Away');
    final outstanding = _readValue(['Outstanding', 'OutstandingAmount'], fallback: '4,250');

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
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DashboardConstants.brandBlue,
                  borderRadius: BorderRadius.circular(outerRadius),
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
                          child: Text(
                            name,
                            style: DsFonts.bodyBold.copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isB2BCustomer) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: DashboardConstants.brandBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'B2B',
                              style: DsFonts.caption.copyWith(
                                color: DashboardConstants.brandBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(code, style: DsFonts.caption),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: DashboardConstants.brandBlue,),
                        const SizedBox(width: 2),
                        Text(distance, style: DsFonts.caption.copyWith(color: DashboardConstants.brandBlue,)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Outstanding', style: DsFonts.caption),
                  Text(
                    '${DsConstants.currencySymbol}$outstanding',
                    style: DsFonts.bodyBold.copyWith(color: DsColors.error),
                  ),
                ],
              ),
              const SizedBox(width: DsSpacing.xs),
              const Icon(Icons.chevron_right, color: DsColors.textSecondary),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          const Divider(height: 1, color: DsColors.border),
          const SizedBox(height: DsSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn('Bill Series', _isB2BCustomer ? 'B2B' : 'B2C'),
              _buildStatColumn(
                'Bill No.',
                _loadingBillNo ? '...' : (_billSeries.isEmpty ? _billNo : '$_billSeries-$_billNo'),
              ),
              if (_isB2BCustomer) _buildStatColumn('GSTIN', _gstNumber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DsFonts.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(
          value,
          style: DsFonts.bodyBold.copyWith(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
                  Expanded(
                    child: Text(
                      'Search product / Scan / Add item',
                      style: DsFonts.smallText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.qr_code_scanner_outlined, size: 18, color: DsColors.textSecondary),
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
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: DsColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 44, color: DashboardConstants.brandBlue,),
          ),
          const SizedBox(height: DsSpacing.lg),
          Text('No items added yet', style: DsFonts.bodyBold.copyWith(fontSize: 16)),
          const SizedBox(height: DsSpacing.xs),
          Text('Search or add items to your bill', style: DsFonts.smallText),
          const SizedBox(height: DsSpacing.lg),
          OutlinedButton(
            onPressed: _openSelectItem,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: DashboardConstants.brandBlue,),
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl, vertical: DsSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
            ),
            child: Text('Add Item', style: DsFonts.bodyBold.copyWith(color: DashboardConstants.brandBlue,)),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Bill items: header stays put, item rows scroll in their own boxed
  // area so the summary / payment / action bar don't get pushed far down
  // the page when there are many items. â”€â”€
  Widget _buildBillItemsList() {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bill Items ($_itemCount)', style: DsFonts.bodyBold),
                InkWell(
                  onTap: _openSelectItem,
                  child: Text(
                    'Edit',
                    style: DsFonts.body.copyWith(color: DashboardConstants.brandBlue, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DsColors.border),
          // Scrollable, boxed item list. Caps its own height instead of
          // letting the outer page grow, and scrolls independently.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _billItemsBoxMaxHeight),
            child: Scrollbar(
              thumbVisibility: _billItems.length > 3,
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md, vertical: DsSpacing.xs),
                itemCount: _billItems.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: DsColors.border),
                itemBuilder: (context, index) => _buildBillItemRow(_billItems[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillItemRow(BillItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 18),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: DsFonts.bodyBold.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${DsConstants.currencySymbol}${item.rate.toStringAsFixed(0)} (${item.rateType}) Â· Qty ${item.qty}'
                  '${item.freeQty > 0 ? ' +${item.freeQty} free' : ''}'
                  '${item.discountPercentDisplay > 0 ? ' Â· ${item.discountPercentDisplay.toStringAsFixed(0)}% off' : ''}',
                  style: DsFonts.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.xs),
          Text('${DsConstants.currencySymbol}${item.netAmount.toStringAsFixed(2)}', style: DsFonts.bodyBold.copyWith(fontSize: 13)),
          InkWell(
            onTap: () => _removeItem(item),
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.delete_outline, size: 17, color: DsColors.error),
            ),
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
          // Top row: quick counts on the left, the headline total on the
          // right where it has plenty of room to show in full.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildStatColumn('Items', '$_itemCount')),
              Expanded(child: _buildStatColumn('Qty', '$_totalQty')),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total Amount', style: DsFonts.caption),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${DsConstants.currencySymbol}${_totalAmount.toStringAsFixed(2)}',
                        style: DsFonts.sectionTitle.copyWith(color: DashboardConstants.brandBlue, fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          const Divider(height: 1, color: DsColors.border),
          const SizedBox(height: DsSpacing.sm),
          // Breakdown as a 2x2 grid â€” each amount gets its own half-width
          // slot (with FittedBox as a safety net) instead of squeezing
          // everything onto one crowded line, so nothing gets clipped.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildInlineStat('Sub Total', '${DsConstants.currencySymbol}{_subTotal.toStringAsFixed(2)}')),
              Expanded(child: _buildInlineStat('Tax (GST)', '${DsConstants.currencySymbol}${_totalTax.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildInlineStat('Discount', '- ${DsConstants.currencySymbol}${_totalDiscount.toStringAsFixed(2)}', valueColor: DsColors.success)),
              Expanded(child: _buildInlineStat('Round Off', ' ${DsConstants.currencySymbol}${_roundOff.toStringAsFixed(2)}')),
            ],
          ),
        ],
      ),
    );
  }

  // Label above value, and the value scales down to fit (via FittedBox)
  // rather than getting clipped with an ellipsis â€” so the full amount is
  // always readable, even for large totals.
  Widget _buildInlineStat(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(right: DsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DsFonts.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: DsFonts.smallText.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? DsColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Payment Type', style: DsFonts.bodyBold),
        const SizedBox(height: DsSpacing.sm),
        Row(
          children: _paymentTypes.map((payment) {
            final label = payment['label'] as String;
            final icon = payment['icon'] as IconData;
            final isSelected = label == _selectedPaymentType;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: DsSpacing.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(DsRadius.button),
                  onTap: () => setState(() => _selectedPaymentType = label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected ? DsColors.primaryLight : DsColors.cardBg,
                      borderRadius: BorderRadius.circular(DsRadius.button),
                      border: Border.all(
                         color: isSelected ? DashboardConstants.brandBlue : DsColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, size: 20, color: isSelected ? DashboardConstants.brandBlue : DsColors.textSecondary),
                        const SizedBox(height: DsSpacing.xs),
                        Text(
                          label,
                          style: DsFonts.caption.copyWith(
                            color: isSelected ? DashboardConstants.brandBlue : DsColors.textSecondary,
                            fontWeight: FontWeight.w700,
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
        if (_billItems.isNotEmpty) ...[
          const SizedBox(height: DsSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              color: DsColors.primaryLight,
              borderRadius: BorderRadius.circular(DsRadius.button),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Amount Received', style: DsFonts.caption),
                Text(
                  '${DsConstants.currencySymbol}${_totalAmount.toStringAsFixed(2)}',
                  style: DsFonts.bodyBold.copyWith(color: DashboardConstants.brandBlue),
                ),
              ],
            ), 
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpacing.lg, DsSpacing.md, DsSpacing.lg, DsSpacing.lg),
      decoration: BoxDecoration(
        color: DsColors.cardBg,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveBill(print: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DashboardConstants.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.print_outlined, color: Colors.white, size: 18),
                label: Text(
                  _isEditing ? 'UPDATE & PRINT' : 'SAVE & PRINT',
                  style: DsFonts.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : () => _saveBill(print: false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
                  side: const BorderSide(color: DsColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
                ),
                icon: const Icon(Icons.save_outlined, size: 18, color: DsColors.textPrimary),
                label: Text(_isEditing ? 'UPDATE' : 'SAVE', style: DsFonts.body.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showStubMessage('WhatsApp'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
                  side: const BorderSide(color: DsColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DsRadius.button)),
                ),
                icon: const Icon(Icons.chat_outlined, size: 18, color: DsColors.textPrimary),
                label: Text('WHATSAPP', style: DsFonts.body.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
