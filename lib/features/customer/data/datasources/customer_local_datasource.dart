import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:suitapps/core/database/tables.dart';
import 'package:suitapps/features/customer/data/models/customer_model.dart';

class CustomerService {
  static final CustomerService _instance = CustomerService._internal();
  factory CustomerService() => _instance;
  CustomerService._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'suitapps.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createCustomerTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE ${Tables.CUSTOMER_TABLE_NAME} '
            'ADD COLUMN ${Tables.COLUMN_NAME_IF_DISTRIBUTOR} INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE ${Tables.CUSTOMER_TABLE_NAME} '
            'ADD COLUMN ${Tables.COLUMN_NAME_DISTRIBUTOR_WISE_CUST_ID} INTEGER',
          );
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
        ${Tables.COLUMN_NAME_DISTRIBUTOR_WISE_CUST_ID} INTEGER
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

  Future<int> insertCustomer(CustomerModel customer) async {
    final db = await database;
    return db.insert(
      Tables.CUSTOMER_TABLE_NAME,
      customer.toMap(),
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
}
