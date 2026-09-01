import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:suitapps/core/database/tables.dart';
import 'package:suitapps/features/customer/data/models/customer_model.dart';

/// Handles all local (on-device) persistence for customers using sqflite.
/// Column/table names are pulled from Tables.CustomerTable so this stays
/// in sync with the same schema naming used on the Android/Java side.
///
/// Add these to pubspec.yaml if not already present:
///   sqflite: ^2.3.0
///   path: ^1.9.0
class CustomerService {
  // Singleton so the whole app shares one open DB connection.
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
      version: 1,
      onCreate: (db, version) async {
        await _createCustomerTable(db);
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
        ${Tables.COLUMN_NAME_Date} TEXT
      )
    ''');
    // Speeds up the duplicate-mobile-number lookup on save.
    await db.execute(
      'CREATE INDEX idx_customer_mobile ON ${Tables.CUSTOMER_TABLE_NAME} (${Tables.COLUMN_NAME_MOBILE})',
    );
  }

  /// Inserts a new customer and returns the generated row id.
  Future<int> insertCustomer(CustomerModel customer) async {
    final db = await database;
    return db.insert(
      Tables.CUSTOMER_TABLE_NAME,
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Updates an existing customer (requires customer.id to be set).
  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await database;
    return db.update(
      Tables.CUSTOMER_TABLE_NAME,
      customer.toMap(),
      where: '${Tables.KEY_CustomerID} = ?',
      whereArgs: [customer.id],
    );
  }

  /// Deletes a customer by id.
  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return db.delete(
      Tables.CUSTOMER_TABLE_NAME,
      where: '${Tables.KEY_CustomerID} = ?',
      whereArgs: [id],
    );
  }

  /// Returns true if a customer already exists with this mobile number.
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

  /// Fetches all customers, most recently added first.
  Future<List<CustomerModel>> getAllCustomers() async {
    final db = await database;
    final result = await db.query(
      Tables.CUSTOMER_TABLE_NAME,
      orderBy: '${Tables.KEY_CustomerID} DESC',
    );
    return result.map((row) => CustomerModel.fromMap(row)).toList();
  }

  /// Fetches a single customer by id, or null if not found.
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

  /// Simple search across name, mobile, and GSTIN â€” handy for a customer list screen.
  Future<List<CustomerModel>> searchCustomers(String query) async {
    final db = await database;
    final like = '%$query%';
    final result = await db.query(
      Tables.CUSTOMER_TABLE_NAME,
      where:
          '${Tables.COLUMN_NAME_CUSTOMERNAME} LIKE ? OR ${Tables.COLUMN_NAME_MOBILE} LIKE ? OR ${Tables.COLUMN_NAME_GSTIN} LIKE ?',
      whereArgs: [like, like, like],
      orderBy: '${Tables.KEY_CustomerID} DESC',
    );
    return result.map((row) => CustomerModel.fromMap(row)).toList();
  }
}
