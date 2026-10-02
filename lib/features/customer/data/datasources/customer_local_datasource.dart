import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:suitapps/core/database/tables.dart';
import 'package:suitapps/features/customer/data/models/customer_model.dart';

class CustomerService {
  static final CustomerService _instance = CustomerService._internal();
  factory CustomerService() => _instance;
  CustomerService._internal();

  static Database? _db;

  // Guards against a race where two callers hit the `database` getter
  // concurrently before `_db` is assigned — caching the in-flight Future
  // ensures openDatabase (and its onUpgrade migrations) only ever
  // actually runs once, no matter how many concurrent callers there are.
  static Future<Database>? _initFuture;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _initFuture ??= _initDb();
    _db = await _initFuture;
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'suitapps.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createCustomerTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE ${Tables.CUSTOMER_TABLE_NAME} '
              'ADD COLUMN ${Tables.COLUMN_NAME_IF_DISTRIBUTOR} INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE ${Tables.CUSTOMER_TABLE_NAME} '
              'ADD COLUMN ${Tables.COLUMN_NAME_DISTRIBUTOR_WISE_CUST_ID} INTEGER',
            );
          } catch (_) {}
        }

        // v2 -> v3: add offline-sync tracking columns, same role as
        // sale_orders.suitAppsId/isSynced/serverOrderId in DatabaseHelper.
        // Without these, CustomerService had no way to know which local
        // customers still needed pushing to the server, and no stable id
        // to correlate a local row with the server's Accout row — see
        // CustomerSyncService.
        if (oldVersion < 3) {
          try {
            await db.execute(
              'ALTER TABLE ${Tables.CUSTOMER_TABLE_NAME} '
              'ADD COLUMN ${Tables.COLUMN_NAME_SUIT_APPS_ID} TEXT',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE ${Tables.CUSTOMER_TABLE_NAME} '
              'ADD COLUMN ${Tables.COLUMN_NAME_IS_SYNCED} INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE ${Tables.CUSTOMER_TABLE_NAME} '
              'ADD COLUMN ${Tables.COLUMN_NAME_SERVER_ACCOUNT_CODE} TEXT',
            );
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createCustomerTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${Tables.CUSTOMER_TABLE_NAME} (
        ${Tables.KEY_CustomerID} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${Tables.COLUMN_NAME_GSTIN} TEXT,
        ${Tables.COLUMN_NAME_CUSTOMERNAME} TEXT NOT NULL,
        ${Tables.COLUMN_NAME_ADDRESS} TEXT NOT NULL,
        ${Tables.COLUMN_NAME_TYPE} TEXT,
        ${Tables.COLUMN_NAME_CUSTOMERTYPE} TEXT,
        ${Tables.COLUMN_NAME_RATETYPE} TEXT,
        ${Tables.COLUMN_NAME_EMAIL} TEXT,
        ${Tables.COLUMN_NAME_MOBILE} TEXT NOT NULL,
        ${Tables.COLUMN_NAME_PHONE} TEXT,
        ${Tables.COLUMN_NAME_CITY} TEXT,
        ${Tables.COLUMN_NAME_COUNTRY} TEXT,
        ${Tables.COLUMN_NAME_PINNO} TEXT,
        ${Tables.COLUMN_NAME_PLACE} TEXT,
        ${Tables.COLUMN_NAME_DISCOUNTPERCENTAGE} TEXT,
        ${Tables.COLUMN_NAME_CREDITDAYS} TEXT,
        ${Tables.COLUMN_NAME_IMAGEPATH} TEXT,
        ${Tables.COLUMN_NAME_ADDITIONALIMAGES} TEXT,
        ${Tables.COLUMN_NAME_COMPANY_ID} TEXT,
        ${Tables.COLUMN_NAME_Date} TEXT,
        ${Tables.COLUMN_NAME_IF_DISTRIBUTOR} INTEGER NOT NULL DEFAULT 0,
        ${Tables.COLUMN_NAME_DISTRIBUTOR_WISE_CUST_ID} INTEGER,
        ${Tables.COLUMN_NAME_SUIT_APPS_ID} TEXT,
        ${Tables.COLUMN_NAME_IS_SYNCED} INTEGER NOT NULL DEFAULT 0,
        ${Tables.COLUMN_NAME_SERVER_ACCOUNT_CODE} TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_customer_mobile ON '
      '${Tables.CUSTOMER_TABLE_NAME} '
      '(${Tables.COLUMN_NAME_MOBILE})',
    );

    await db.execute(
      'CREATE INDEX idx_customer_distributor ON '
      '${Tables.CUSTOMER_TABLE_NAME} '
      '(${Tables.COLUMN_NAME_IF_DISTRIBUTOR}, '
      '${Tables.COLUMN_NAME_DISTRIBUTOR_WISE_CUST_ID})',
    );
  }

  /// Inserts a new customer/distributor row. A `SuitAppsId` is generated
  /// here (timestamp-based, same shape as the id-generation pattern used
  /// for sale orders) UNLESS `customer.toMap()` already provides one —
  /// this keeps things working even before CustomerModel is updated to
  /// carry SuitAppsId/IsSynced itself.
  Future<int> insertCustomer(CustomerModel customer) async {
    final db = await database;
    final map = Map<String, dynamic>.from(customer.toMap());

    if (map[Tables.COLUMN_NAME_SUIT_APPS_ID] == null ||
        map[Tables.COLUMN_NAME_SUIT_APPS_ID].toString().isEmpty) {
      map[Tables.COLUMN_NAME_SUIT_APPS_ID] =
          'CUST-${DateTime.now().millisecondsSinceEpoch}';
    }
    map[Tables.COLUMN_NAME_IS_SYNCED] ??= 0;

    return db.insert(
      Tables.CUSTOMER_TABLE_NAME,
      map,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await database;
    return db.update(
      Tables.CUSTOMER_TABLE_NAME,
      customer.toMap(),
      where: '${Tables.KEY_CustomerID} = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return db.delete(
      Tables.CUSTOMER_TABLE_NAME,
      where: '${Tables.KEY_CustomerID} = ?',
      whereArgs: [id],
    );
  }

  Future<bool> customerExists(String mobile) async {
    final db = await database;
    final result = await db.query(
      Tables.CUSTOMER_TABLE_NAME,
      where: '${Tables.COLUMN_NAME_MOBILE} = ?',
      whereArgs: [mobile],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Returns only rows created as distributors.
  Future<List<CustomerModel>> getDistributors() async {
    final db = await database;
    final result = await db.query(
      Tables.CUSTOMER_TABLE_NAME,
      where: '${Tables.COLUMN_NAME_IF_DISTRIBUTOR} = ?',
      whereArgs: [1],
      orderBy: '${Tables.COLUMN_NAME_CUSTOMERNAME} COLLATE NOCASE ASC',
    );
    return result.map(CustomerModel.fromMap).toList();
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final db = await database;
    final result = await db.query(
      Tables.CUSTOMER_TABLE_NAME,
      orderBy: '${Tables.KEY_CustomerID} DESC',
    );
    return result.map(CustomerModel.fromMap).toList();
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final db = await database;
    final result = await db.query(
      Tables.CUSTOMER_TABLE_NAME,
      where: '${Tables.KEY_CustomerID} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return CustomerModel.fromMap(result.first);
  }

  Future<List<CustomerModel>> searchCustomers(String query) async {
    final db = await database;
    final like = '%$query%';
    final result = await db.query(
      Tables.CUSTOMER_TABLE_NAME,
      where:
          '${Tables.COLUMN_NAME_CUSTOMERNAME} LIKE ? OR '
          '${Tables.COLUMN_NAME_MOBILE} LIKE ? OR '
          '${Tables.COLUMN_NAME_GSTIN} LIKE ?',
      whereArgs: [like, like, like],
      orderBy: '${Tables.KEY_CustomerID} DESC',
    );
    return result.map(CustomerModel.fromMap).toList();
  }

  // ------------------------------------------------------
  // SYNC SUPPORT — used by CustomerSyncService
  // ------------------------------------------------------

  /// All customer/distributor rows not yet pushed to the server, oldest
  /// first. Returns raw maps (not CustomerModel) since the sync payload
  /// needs the exact column values, keyed by the SAME column names used
  /// everywhere else in this file (Tables.* constants) — see
  /// CustomerSyncService._toApiPayload, which reads row[Tables.xxx].
  Future<List<Map<String, dynamic>>> getUnsyncedCustomers() async {
    final db = await database;
    return db.query(
      Tables.CUSTOMER_TABLE_NAME,
      where: '${Tables.COLUMN_NAME_IS_SYNCED} = ?',
      whereArgs: [0],
      orderBy: '${Tables.KEY_CustomerID} ASC',
    );
  }

  /// Marks a customer/distributor as synced once /InsertUpdateCustomer
  /// confirms save, storing the server's AccountCode for any future
  /// UPDATE sync of this same row.
  Future<void> markCustomerSynced(String suitAppsId, String accountCode) async {
    final db = await database;
    await db.update(
      Tables.CUSTOMER_TABLE_NAME,
      {
        Tables.COLUMN_NAME_IS_SYNCED: 1,
        Tables.COLUMN_NAME_SERVER_ACCOUNT_CODE: accountCode,
      },
      where: '${Tables.COLUMN_NAME_SUIT_APPS_ID} = ?',
      whereArgs: [suitAppsId],
    );
  }
}