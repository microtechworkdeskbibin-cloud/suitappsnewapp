import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/core/database/database_helper.dart';

// receipt_sync_service.dart
//
// Handles pushing locally-saved receipts (from Receiptpage._saveReceipt) up
// to the online DB via the /syncReceiptApp endpoint (InsertReceiptMob proc).
//
// Flow this implements:
//   1. Receiptpage saves the receipt to SQLite first (isSynced = 0) â€”
//      already working, unchanged.
//   2. Right after that local save, we ATTEMPT an immediate sync. If the
//      device has no network, this attempt just fails silently and the
//      row stays isSynced = 0 â€” nothing is lost, no error shown to the
//      user (the local save already succeeded, that's all they asked for).
//   3. A connectivity listener watches for the device coming back online.
//      The moment it does, we sweep the local DB for every row where
//      isSynced = 0 and push them all in one batch call to
//      /syncReceiptApp (which already accepts a `receiptList` array).
//   4. On a successful response we mark each row isSynced = 1 and store
//      the server's OutId as serverId, matched back by SuitApps_id
//      (vouchernum) since that's the one field both sides always agree on.
//
// â”€â”€ FIXED (see debug log dated 2026-08-31): â”€â”€
//   â€¢ PartyID was sending accountCode (e.g. 19587) instead of the numeric
//     account id (rootId, e.g. 147). InsertReceiptMob looks up
//     `AccountCode FROM Accout WHERE AccountID = @PartyID` â€” sending the
//     *code* where an *id* was expected meant the lookup always missed,
//     so PartyID landed as 0 server-side. Now sends row['rootId'].
//   â€¢ CompanyID / UserID / FYearID were hardcoded to 0 via SessionStub.
//     They're actually stored in SharedPreferences as a single JSON string
//     under the key 'user' (see _readSession below), not as flat pref
//     keys â€” confirmed from the app's own debug log:
//       prefs: user = {"CompanyID":"8","UserId":3,"FYearID":1006,...}
//     Session values are now read from that blob once per sync batch and
//     passed into _toApiPayload for every row.
//
// âš ï¸ TODO â€” CONFIRM BEFORE RELYING ON THIS IN PRODUCTION:
//   â€¢ RMID â€” not present in the local schema shown; sent as 0. If this
//     needs to be a real receipt-master id from another table, wire it in.
//   â€¢ OBank â€” the proc expects a bank *account id* (int), but the app UI
//     only collects a bank *name* (`bankName`, free text -> PBank). OBank
//     is sent as 0 here. If you have a bank lookup, resolve it before
//     sending.
//   â€¢ DrHead â€” sent as 0 (placeholder). Confirm expected value.
//   â€¢ Type mapping â€” proc expects '0' = Cash, '1' = Bank. Local
//     `paymentType` is 'cash' / 'cheque' / 'gpay'. Mapped as:
//     cash -> '0', cheque -> '1', gpay -> '1' (both cheque and gpay are
//     non-cash / bank-routed). Adjust if your business logic differs.
//   â€¢ Image â€” the proc has a single @Image param but the local row keeps
//     two separate images (chequeImagePath / gpayImagePath). Whichever one
//     is non-empty for that payment mode is sent as @Image.
//
// pubspec.yaml packages needed if not already present:
//   http: ^1.2.0
//   connectivity_plus: ^6.0.0
//   shared_preferences: ^2.0.0
//
// Uses DatabaseHelper.markReceiptSynced(String suitAppsId) as already
// implemented in the project â€” it flips isSynced to 1 and stamps
// updatedAt, matched by suitAppsId. The server's OutId is only used
// here to decide success/failure (see wasSaved below); it isn't
// persisted locally since the existing markReceiptSynced doesn't take
// a serverId. If you later add a serverId column, extend that method
// and pass outId through here too.


class ReceiptSyncService {
  ReceiptSyncService._internal();
  static final ReceiptSyncService instance = ReceiptSyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isSyncing = false;

  /// Call this once, e.g. in main() or when the app starts / user logs in.
  void startListening() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        // Fire and forget â€” don't block whatever triggered the
        // connectivity change.
        syncPendingReceipts();
      }
    });
  }

  void dispose() {
    _connSub?.cancel();
  }

  /// Call this right after a receipt is saved locally, so a receipt made
  /// while online goes up immediately instead of waiting for the next
  /// connectivity-change event or app restart.
  Future<void> trySyncNow() async {
    final results = await Connectivity().checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork) {
      await syncPendingReceipts();
    }
    // If offline, do nothing â€” the row is already saved locally with
    // isSynced = 0 and will be picked up by the connectivity listener
    // (or the next manual/periodic sync) once the network is back.
  }

  /// Reads CompanyID / UserID / FYearID out of the logged-in session.
  ///
  /// These are NOT flat SharedPreferences keys in this app â€” login stores
  /// a single JSON-encoded string under the key 'user', e.g.:
  ///   {"success":true,"Username":"admin","CompanyID":"8","UserId":3,
  ///    "UserRoleId":1,"Name":"ADMIN","FYearID":1006}
  /// (confirmed from the app's own debug log). This parses that blob once
  /// per sync batch. Falls back to 0 for any field that's missing or the
  /// wrong type, and tolerates a couple of common alternate key spellings
  /// in case the login payload's casing ever changes.
  Future<_SessionValues> _readSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson == null || userJson.isEmpty) {
        print('âš ï¸ Receipt sync: no "user" pref found â€” sending 0 for '
            'CompanyID/UserID/FYearID.');
        return const _SessionValues(companyId: 0, userId: 0, fYearId: 0);
      }

      final Map<String, dynamic> user =
          jsonDecode(userJson) as Map<String, dynamic>;

      int _asInt(dynamic v) {
        if (v is int) return v;
        if (v is String) return int.tryParse(v) ?? 0;
        return 0;
      }

      final companyId = _asInt(user['CompanyID'] ?? user['CompanyId']);
      final userId = _asInt(user['UserId'] ?? user['UserID'] ?? user['User_ID']);
      final fYearId = _asInt(user['FYearID'] ?? user['FYearId'] ?? user['FyearID']);

      if (companyId == 0 || userId == 0 || fYearId == 0) {
        print('âš ï¸ Receipt sync: one or more session values resolved to 0 '
            '(companyId=$companyId, userId=$userId, fYearId=$fYearId) â€” '
            'check the "user" pref contents.');
      }

      return _SessionValues(
        companyId: companyId,
        userId: userId,
        fYearId: fYearId,
      );
    } catch (e) {
      print('âŒ Receipt sync: failed to read/parse session â€” $e');
      return const _SessionValues(companyId: 0, userId: 0, fYearId: 0);
    }
  }

  /// Pulls every local receipt with isSynced = 0 and pushes them all in
  /// one batch call to /syncReceiptApp. Safe to call repeatedly â€” it's a
  /// no-op if nothing is pending or a sync is already in flight.
  Future<void> syncPendingReceipts() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // NOTE: add this method to DatabaseHelper if it doesn't exist yet â€”
      // `SELECT * FROM receipts WHERE isSynced = 0`.
      final List<Map<String, dynamic>> pending =
          await DatabaseHelper.instance.getUnsyncedReceipts();

      if (pending.isEmpty) return;

      // Read session values once for this whole batch rather than once
      // per row â€” they don't change mid-sync.
      final session = await _readSession();

      final payload = {
        'receiptList':
            pending.map((row) => _toApiPayload(row, session)).toList(),
      };

      print('ðŸ“¤ Receipt sync payload -> ${jsonEncode(payload)}');

      final uri = Uri.parse(
        '${ApiConfig.apiBaseUrl}${ApiConfig.insertreceipt}',
      );

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.receiveTimeout);

      if (response.statusCode != 200) {
        print('âŒ Receipt sync failed: HTTP ${response.statusCode}');
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded['success'] != true) {
        print('âŒ Receipt sync rejected by server: ${decoded['message']}');
        return;
      }

      final List<dynamic> resultList = decoded['receiptList'] ?? [];

      // Match each result back to its local row by SuitApps_id
      // (== vouchernum == suitAppsId on the local row) and mark it synced.
      for (final result in resultList) {
        final String? suitAppsId = result['SuitApps_id'];
        final outId = result['OutId'];

        if (suitAppsId == null) continue;

        final bool wasSaved = outId != null && outId != -3;
        if (wasSaved) {
          await DatabaseHelper.instance.markReceiptSynced(suitAppsId);
          print('âœ… Receipt synced: $suitAppsId (server id $outId)');
        } else {
          print(
            'âš ï¸ Receipt $suitAppsId not saved server-side (OutId=$outId) '
            'â€” left as unsynced for retry.',
          );
        }
      }
    } catch (e) {
      // Network error, timeout, etc. â€” leave everything as unsynced and
      // just try again on the next connectivity event.
      print('âŒ Receipt sync error (will retry later): $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Converts one local `receipts` row (the shape built in
  /// Receiptpage._saveReceipt's `localData` map) into the field names
  /// InsertReceiptMob / syncReceiptApp.js expects.
  Map<String, dynamic> _toApiPayload(
    Map<String, dynamic> row,
    _SessionValues session,
  ) {
    final String paymentType = (row['paymentType'] ?? 'cash').toString();

    // '0' = Cash, '1' = Bank (per InsertReceiptMob's @Type mapping).
    final String type = paymentType == 'cash' ? '0' : '1';

    final String image = paymentType == 'cheque'
        ? (row['chequeImagePath'] ?? '')
        : paymentType == 'gpay'
            ? (row['gpayImagePath'] ?? '')
            : '';

    return {
      'RMID': 0, // TODO confirm â€” see header notes
      'RDate': DateTime.now().toIso8601String().substring(0, 10),
      // FIXED: was sending accountCode (the display code, e.g. 19587).
      // InsertReceiptMob does `AccountCode FROM Accout WHERE AccountID =
      // @PartyID` â€” it needs the numeric account id, which is what
      // Receiptpage stores as rootId on the local row.
      'PartyID': row['rootId'] ?? 0,
      'Amt': row['amount'],
      'Type': type,
      'OBank': 0, // TODO confirm â€” no bank-account id collected in UI yet
      'PBank': row['bankName'] ?? '',
      'ChkNo': row['chequeNo'] ?? '',
      'ChkDate': _parseChequeDate(row['chequeDate']),
      'Remark': row['narration'] ?? '',
      'CollectionCharge': 0,
      'DiscountCharge': 0,
      'PostalCharge': 0,
      'Cleared': 0,
      'Bounced': 0,
      'CompanyID': session.companyId,
      'IsDeleted': 0,
      'vouchernum': row['suitAppsId'],
      'RouteID': row['rootId'] ?? 0,
      'FYearID': session.fYearId,
      'DrHead': 0, // TODO confirm
      'UserID': session.userId,
      'Image': image,
    };
  }

  String _parseChequeDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return DateTime.now().toIso8601String();
    }
    try {
      // Stored locally as 'dd/MM/yyyy' (see Receiptpage._selectDate).
      final parts = value.toString().split('/');
      if (parts.length == 3) {
        final d = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        return DateTime(y, m, d).toIso8601String();
      }
    } catch (_) {}
    return DateTime.now().toIso8601String();
  }
}

/// Session values pulled from the logged-in user's SharedPreferences blob.
/// See ReceiptSyncService._readSession.
class _SessionValues {
  final int companyId;
  final int userId;
  final int fYearId;

  const _SessionValues({
    required this.companyId,
    required this.userId,
    required this.fYearId,
  });
}
