import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Lightweight offline cache for the route/company customer list fetched
/// from the API.
///
/// Design:
/// - Separate DB file (`customers_cache.db`) from `DatabaseHelper`'s
///   `customer_db.db`, so this cache can be wiped/rebuilt independently
///   without touching billing/local-customer data.
/// - Each customer is stored as a single JSON blob in the `data` column,
///   keyed by (`rootId`, `companyId`). This avoids needing a DB migration
///   every time the API adds/removes/renames a field on the customer
///   object - we just re-encode whatever shape comes back.
/// - On every successful API fetch, all rows for that (rootId, companyId)
///   pair are deleted and re-inserted, so the cache always mirrors the
///   latest full list for that route (no stale/duplicate rows).
class CustomerLocalDbService {
  static final CustomerLocalDbService _instance =
      CustomerLocalDbService._internal();

  factory CustomerLocalDbService() => _instance;

  CustomerLocalDbService._internal();

  static const String _dbName = 'customers_cache.db';
  static const String _table = 'customers';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rootId TEXT NOT NULL,
            companyId TEXT NOT NULL,
            data TEXT NOT NULL
          )
        ''');

        // Speeds up the getCustomers()/saveCustomers() lookups, which are
        // always filtered by this pair.
        await db.execute('''
          CREATE INDEX idx_customers_root_company
          ON $_table (rootId, companyId)
        ''');
      },
    );
  }

  /// Returns the cached customers for a given route/company, decoded back
  /// into maps. Returns an empty list if nothing has been cached yet.
  Future<List<Map<String, dynamic>>> getCustomers({
    required String rootId,
    required String companyId,
  }) async {
    final db = await _database;

    final rows = await db.query(
      _table,
      where: 'rootId = ? AND companyId = ?',
      whereArgs: [rootId, companyId],
    );

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final raw = row['data'];
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            result.add(decoded);
          } else if (decoded is Map) {
            result.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Skip any row that somehow contains malformed JSON instead of
          // letting one bad row blow up the whole cached list.
        }
      }
    }

    return result;
  }

  /// Replaces the cached customers for a given route/company with the
  /// freshly fetched list. Wrapped in a transaction so a crash mid-write
  /// can't leave the cache half-deleted / half-inserted.
  Future<void> saveCustomers({
    required String rootId,
    required String companyId,
    required List<Map<String, dynamic>> customers,
  }) async {
    final db = await _database;

    await db.transaction((txn) async {
      await txn.delete(
        _table,
        where: 'rootId = ? AND companyId = ?',
        whereArgs: [rootId, companyId],
      );

      final batch = txn.batch();
      for (final customer in customers) {
        batch.insert(_table, {
          'rootId': rootId,
          'companyId': companyId,
          'data': jsonEncode(customer),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  /// Clears the entire cache (all routes/companies). Handy for a manual
  /// "clear offline data" action or logout flow.
  Future<void> clearAll() async {
    final db = await _database;
    await db.delete(_table);
  }

  /// Clears just one route/company's cached customers.
  Future<void> clearFor({
    required String rootId,
    required String companyId,
  }) async {
    final db = await _database;
    await db.delete(
      _table,
      where: 'rootId = ? AND companyId = ?',
      whereArgs: [rootId, companyId],
    );
  }
}
