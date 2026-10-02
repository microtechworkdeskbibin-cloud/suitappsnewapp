import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/core/database/database_helper.dart';

// sale_order_sync_service.dart
//
// Handles pushing locally-saved sale orders (from SaleOrderPage._saveOrder)
// up to the online DB via the /syncSaleOrderApp endpoint (which internally
// calls Sync_AliasDirectSales then Sync_AliasDirectSaleDetails per item —
// see syncSaleOrderApp.js).
//
// Same offline-first flow as ReceiptSyncService: save locally first
// (isSynced = 0), attempt an immediate sync, and let a connectivity
// listener sweep any still-pending rows once the device comes back online.
//
// Two things baked in per team decision (see DatabaseHelper._createSaleOrderTables
// comments for the full rationale):
//   • ModifiedBy is ALWAYS sent as 0 — Sync_AliasDirectSales's insert-vs-
//     update check is `WHERE SuitApps_id=@SuitApps_id AND ModifiedBy=0`;
//     any other value risks a duplicate INSERT on the next sync of the
//     same order.
//   • CGST/SGST are split evenly from the item's single combined tax
//     amount (CGST = SGST = taxAmount / 2), since AliaseSalesDetails has
//     no single "total tax" column, only the CGST/SGST pair (intra-state
//     GST only — there's no IGST column in this schema for inter-state
//     orders).
//
// CHANGE LOG (fixes applied):
//   • `orderSeries` and `orderNumber` are now read as two SEPARATE local
//     columns (see sale_order_page.dart / DatabaseHelper) instead of one
//     combined "series-number" string. `OrderNo` below is now sent as the
//     plain numeric order number. `orderSeries` is sent separately —
//     confirm against Sync_AliasDirectSales which actual server-side
//     parameter it should map to (this file guesses `AliasBillNo` isn't
//     it; adjust once you check the stored procedure's parameter list).
//   • 'Amount' is unaffected here — it was already forwarding
//     row['amount'] as-is; the fix for that value lives in
//     SaleOrderPage._saveOrder (amount now equals totalAmount).
//   • 'Status' (Primary vs Secondary — 1 = Primary, 0 = Secondary) is now
//     forwarded from the local `sale_orders.status` column (schema v13,
//     see DatabaseHelper). Previously this method never read `row['status']`
//     at all, so the header payload sent to /syncSaleOrderApp had no
//     `Status` key — the API route's `order.Status ?? 1` fallback then
//     silently defaulted EVERY order to 1 server-side, regardless of
//     whether it was actually saved locally as Primary or Secondary.
//     This is a SEPARATE field from 'OrderStatus' below (the
//     Pending/Confirmed/Dispatched/Cancelled lifecycle) — don't conflate
//     the two.
//
// pubspec.yaml packages needed if not already present:
//   http: ^1.2.0
//   connectivity_plus: ^6.0.0


class SaleOrderSyncService {
  SaleOrderSyncService._internal();
  static final SaleOrderSyncService instance = SaleOrderSyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isSyncing = false;

  void startListening() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        syncPendingOrders();
      }
    });
  }

  void dispose() {
    _connSub?.cancel();
  }

  /// Call right after a sale order is saved locally, so an order made
  /// while online goes up immediately instead of waiting for the next
  /// connectivity-change event or app restart.
  Future<void> trySyncNow() async {
    final results = await Connectivity().checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork) {
      await syncPendingOrders();
    }
  }

  /// Pulls every local order with isSynced = 0 and syncs them one at a
  /// time (unlike receipts/bills, an order's header+items sync is one
  /// combined API call per order — see syncSaleOrderApp.js — so there's
  /// no batch endpoint to send them all in a single request).
  Future<void> syncPendingOrders() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final List<Map<String, dynamic>> pending =
          await DatabaseHelper.instance.getUnsyncedSaleOrders();

      if (pending.isEmpty) return;

      for (final order in pending) {
        final suitAppsId = order['suitAppsId'] as String?;
        if (suitAppsId == null) continue;

        try {
          final items = await DatabaseHelper.instance.getItemsForSaleOrder(suitAppsId);

          final headerPayload = _toHeaderPayload(order);
          final itemPayloads = items.map(_toItemPayload).toList();

          final uri = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.insertOrder}');

          final response = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'order': headerPayload,
                  'items': itemPayloads,
                }),
              )
              .timeout(ApiConfig.receiveTimeout);

          if (response.statusCode != 200) {
            print('❌ Sale order sync failed for $suitAppsId: HTTP ${response.statusCode}');
            print('❌ Response body: ${response.body}');
            continue;
          }

          final decoded = jsonDecode(response.body);
          if (decoded['success'] != true) {
            print('❌ Sale order sync rejected for $suitAppsId: ${decoded['message']}');
            continue;
          }

          final serverOrderId = decoded['DSID']?.toString();
          if (serverOrderId == null) {
            print('⚠️ Sale order $suitAppsId synced but no DSID returned — left unsynced.');
            continue;
          }

          await DatabaseHelper.instance.markSaleOrderSynced(suitAppsId, serverOrderId);
          print('✅ Sale order synced: $suitAppsId -> server DSID $serverOrderId '
              '(OrderNo: ${decoded['OrderNo']})');
        } catch (e) {
          // Still offline / server unreachable — leave it for the next
          // attempt rather than blocking the rest of the queue.
          print('❌ Sale order sync error for $suitAppsId (will retry later): $e');
          continue;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Converts one local `sale_orders` row into Sync_AliasDirectSales'
  /// parameter names.
  Map<String, dynamic> _toHeaderPayload(Map<String, dynamic> row) {
    return {
      'DSID': int.tryParse(row['serverOrderId']?.toString() ?? '') ?? 0,
      'Date': row['orderDate'],
      // `orderNumber` is now the plain numeric order number, stored
      // separately from `orderSeries` (previously both were pre-joined
      // into a single "series-number" string here — e.g. "B2C-11").
      // Server validates OrderNo as a string, so convert explicitly.
      'OrderNo': row['orderNumber']?.toString() ?? '',
      // TODO: confirm which parameter Sync_AliasDirectSales actually
      // expects the series in (this schema comment set didn't include
      // the stored proc signature). Sending it as `OrderSeries` as a
      // best guess — rename to match once confirmed.
      'OrderSeries': row['orderSeries'] ?? '',
      'CustomerID': int.tryParse(row['customerId']?.toString() ?? '') ?? 0,
      'UserID': row['userId'],
      'CompanyID': row['companyId'],
      // Now the FINAL amount (tax included) — SaleOrderPage._saveOrder
      // fixed this to equal totalAmount instead of the pre-tax subtotal.
      'Amount': row['amount'],
      'AdvanceAmo': row['advanceAmount'],
      'TotAmo': row['totalAmount'],
      'OrderStatus': row['orderStatus'],
      // Primary vs Secondary order type — 1 = Primary, 0 = Secondary.
      // Read from the local `sale_orders.status` column (see file header
      // comment for why this was missing before). Falls back to 1 only
      // if the column is somehow null (e.g. a pre-v13 row that hasn't
      // been re-saved yet), matching the API route's own default.
      'Status': row['status'] ?? 1,
      'CreatedBy': row['createdBy'],
      'CreatedDate': row['createdDate'],
      // ModifiedBy is fixed at 0 here regardless of the local column —
      // see the file header comment for why.
      'ModifiedBy': 0,
      'ModifiedDate': DateTime.now().toIso8601String(),
      'DeletedBy': row['deletedBy'] ?? 0,
      'DeletedDate': row['deletedDate'],
      'IsDeleted': row['isDeleted'] ?? 0,
      'SuitApps_id': row['suitAppsId'],
      'Discount': row['discount'],
      'Discount_rate': row['discountRate'] ?? '',
      'Customer_SuitAppsId': row['customerSuitAppsId'] ?? '',
      'BillNo': int.tryParse(row['billNo']?.toString() ?? '') ?? 0,
      'AliasBillNo': row['aliasBillNo'] ?? '',
      'Bill_Series': row['billSeries'] ?? '',
      'BillMode': row['billMode'] ?? 0,
      'FYearID': row['fYearId'],
      'Narration': row['narration'] ?? '',
      'InvoiceType': row['invType'] ?? '',
    };
  }

  /// Converts one local `sale_order_items` row into
  /// Sync_AliasDirectSaleDetails' parameter names. CGST/SGST are split
  /// evenly from the stored combined taxAmount/taxRate (see file header).
  Map<String, dynamic> _toItemPayload(Map<String, dynamic> row) {
    final taxAmount = (row['taxAmount'] as num?)?.toDouble() ?? 0;
    final taxRate = row['taxRate']?.toString() ?? '';

    final halfTaxAmount = taxAmount / 2;
    // taxRate is stored as text (matches CGST_Rate/SGST_Rate's varchar
    // type server-side); halve it numerically where possible, otherwise
    // fall back to the original string for both halves.
    final parsedRate = double.tryParse(taxRate);
    final halfRateStr = parsedRate != null ? (parsedRate / 2).toString() : taxRate;

    return {
      'ItemID': int.tryParse(row['productId']?.toString() ?? '') ?? 0,
      'Qty': row['qty'],
      'NetAmount': row['netAmount'],
      'SuitApps_id': row['suitAppsId'],
      'Tax_Rate': taxRate,
      'Tax_Amt': taxAmount,
      'Rate': row['rate'],
      'GrossValue': row['grossValue'],
      'CGST_Rate': halfRateStr,
      'CGST_Amt': halfTaxAmount,
      'SGST_Rate': halfRateStr,
      'SGST_Amt': halfTaxAmount,
      'FreeQuantity': row['freeQty'],
      'MRP': row['mrp'],
      'disptg': row['discountPercent'],
      'disamt': row['discountAmount'],
      'FCessRate': row['fCessRate'] ?? '',
      'FCessAmt': row['fCessAmount'] ?? 0,
    };
  }
}