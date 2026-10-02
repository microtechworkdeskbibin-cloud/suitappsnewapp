import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:suitapps/core/database/tables.dart';
import 'package:suitapps/features/customer/data/datasources/customer_api_datasource.dart';
import 'package:suitapps/features/customer/data/datasources/customer_local_datasource.dart';

// customer_sync_service.dart
//
// Handles pushing locally-saved customers/distributors (from
// CustomerDashboardPage._save -> CustomerService().insertCustomer) up to
// the online DB via /InsertUpdateCustomer (APPInsertUpdateAccount) — same
// offline-first shape as SaleOrderSyncService: save locally first, attempt
// an immediate sync, and let a connectivity listener sweep any still-
// pending rows once the device comes back online.
//
// FIXED: previously referenced `DatabaseHelper.instance.get/markXxx`,
// which doesn't exist — CustomerTable lives in a SEPARATE local database
// (suitapps.db, managed by CustomerService in
// customer_local_datasource.dart), not the sale_orders/bills/receipts one
// (customer_db.db, managed by DatabaseHelper). Now correctly calls
// CustomerService() and reads/writes using the real Tables.* column
// names.

class CustomerSyncService {
  CustomerSyncService._internal();
  static final CustomerSyncService instance = CustomerSyncService._internal();

  final CustomerApiService _api = CustomerApiService();
  final CustomerService _localDb = CustomerService();

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isSyncing = false;

  void startListening() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        syncPendingCustomers();
      }
    });
  }

  void dispose() {
    _connSub?.cancel();
  }

  /// Call right after a customer/distributor is saved locally, so a save
  /// made while online goes up immediately instead of waiting for the next
  /// connectivity-change event or app restart.
  Future<void> trySyncNow() async {
    final results = await Connectivity().checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork) {
      await syncPendingCustomers();
    }
  }

  Future<void> syncPendingCustomers() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final List<Map<String, dynamic>> pending =
          await _localDb.getUnsyncedCustomers();

      if (pending.isEmpty) return;

      for (final row in pending) {
        final suitAppsId = row[Tables.COLUMN_NAME_SUIT_APPS_ID] as String?;
        if (suitAppsId == null) continue;

        try {
          final payload = _toApiPayload(row);
          final result = await _api.insertOrUpdateCustomer(payload);

          final accountCode = result['AccountCode']?.toString();
          if (accountCode == null) {
            print('⚠️ Customer $suitAppsId synced but no AccountCode returned — left unsynced.');
            continue;
          }

          await _localDb.markCustomerSynced(suitAppsId, accountCode);
          print('✅ Customer synced: $suitAppsId -> server AccountCode $accountCode');
        } catch (e) {
          // Still offline / server unreachable — leave it for the next
          // attempt rather than blocking the rest of the queue.
          print('❌ Customer sync error for $suitAppsId (will retry later): $e');
          continue;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Converts one local `CustomerTable` row into APPInsertUpdateAccount's
  /// parameter names (see APPInsertUpdateAccount.sql / customer_routes.js
  /// /InsertUpdateCustomer). Reads using the real Tables.* column names
  /// confirmed from customer_local_datasource.dart / tables.dart.
  ///
  /// ⚠️ Still unconfirmed (no customer_model.dart / customer_create_page.dart
  /// seen yet): CreatedBy/CreatedDate/ModifiedBy/RootId/Latitude/Longitude/
  /// Branchid have no matching CustomerTable column at all — these default
  /// to 0/now/empty below. If your create flow captures any of these
  /// (e.g. RootId for route/beat assignment), the columns need adding to
  /// CustomerTable and this mapping updated accordingly.
  Map<String, dynamic> _toApiPayload(Map<String, dynamic> row) {
    final now = DateTime.now().toIso8601String();

    return {
      'AccountName': row[Tables.COLUMN_NAME_CUSTOMERNAME] ?? '',
      'SuitAppsId': row[Tables.COLUMN_NAME_SUIT_APPS_ID],
      'Type': row[Tables.COLUMN_NAME_TYPE] ?? '',
      'AccountID': 0,
      'CompanyID': int.tryParse(row[Tables.COLUMN_NAME_COMPANY_ID]?.toString() ?? '') ?? 0,

      // TODO: no CreatedBy/CreatedDate/ModifiedBy columns exist on
      // CustomerTable yet — using safe defaults for now.
      'CreatedBy': 0,
      'CreatedDate': row[Tables.COLUMN_NAME_Date] ?? now,
      'ModifiedBy': 0,
      'ModifiedDate': now,
      'IsDeleted': 0,

      'Address': row[Tables.COLUMN_NAME_ADDRESS] ?? '',
      'Email': row[Tables.COLUMN_NAME_EMAIL] ?? '',
      'Mob': row[Tables.COLUMN_NAME_MOBILE] ?? '',
      'city': row[Tables.COLUMN_NAME_CITY] ?? '',
      'country': row[Tables.COLUMN_NAME_COUNTRY] ?? '',
      'Phone': row[Tables.COLUMN_NAME_PHONE] ?? '',

      'CreatedDateAndTime': row[Tables.COLUMN_NAME_Date] ?? now,
      'MoifiedDateAndTime': now,

      // TODO: no RootId column exists on CustomerTable yet.
      'RootId': 0,
      'RateType': row[Tables.COLUMN_NAME_RATETYPE] ?? '',
      'PinNo': row[Tables.COLUMN_NAME_PINNO] ?? '',
      'GSTinNo': row[Tables.COLUMN_NAME_GSTIN] ?? '',
      'Place': row[Tables.COLUMN_NAME_PLACE] ?? '',
      'CustomerType': row[Tables.COLUMN_NAME_CUSTOMERTYPE] ?? '',

      // TODO: no Latitude/Longitude columns exist on CustomerTable yet.
      'Latitude': '',
      'Longitude': '',

      'DiscountPercentage': row[Tables.COLUMN_NAME_DISCOUNTPERCENTAGE] ?? '',
      'CreditDays': int.tryParse(row[Tables.COLUMN_NAME_CREDITDAYS]?.toString() ?? '') ?? 0,

      // NOTE: the route reads data.image1 (not data.image) for the image
      // bytes — see customer_routes.js. ImagePath stores a local file
      // PATH, not raw bytes, so actual image upload (reading the file and
      // encoding it) is a separate step not wired yet.
      'image1': null,
      // TODO: no Branchid column exists on CustomerTable yet.
      'Branchid': 0,

      // Distributor fields.
      'IfDistributor': row[Tables.COLUMN_NAME_IF_DISTRIBUTOR] ?? 0,
      'DistribtrWiseCustId': row[Tables.COLUMN_NAME_DISTRIBUTOR_WISE_CUST_ID],
    };
  }
}