import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:suitapps/features/direct_sale/data/models/item_category_model.dart';
import 'package:suitapps/features/direct_sale/data/models/sale_item_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();

  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'customer_db.db');

    // bump version when schema changes so existing DBs get upgraded
    return openDatabase(
      path,
      version: 12,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerName TEXT,
            address TEXT,
            type TEXT,
            email TEXT,
            mobile TEXT,
            city TEXT,
            country TEXT,
            phone TEXT,
            rateType TEXT,
            pinNo TEXT,
            gstinNo TEXT,
            place TEXT,
            customerType TEXT,
            discountPercentage TEXT,
            creditDays TEXT,
            imagePath TEXT,
            additionalImages TEXT
          )
        ''');

        await _createCategoriesAndItemsTables(db);
        await _createBillingTables(db);
        await _createReceiptsTable(db);
        await _createSaleOrderTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // If the app previously created the DB without image columns,
        // add them when upgrading. Use try/catch to ignore if column exists.
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE customers ADD COLUMN imagePath TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE customers ADD COLUMN additionalImages TEXT');
          } catch (_) {}
        }

        // v2 -> v3: add categories & van_items tables for offline item sync
        if (oldVersion < 3) {
          await _createCategoriesAndItemsTables(db);
        }

        // v3 -> v4: van_items table was missing the ccp column, so CCP rate
        // data from the API was being silently dropped on save.
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE van_items ADD COLUMN ccp REAL');
          } catch (_) {}
        }

        // v4 -> v5: van_items table was missing UnitID/UnitName columns.
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE van_items ADD COLUMN UnitID INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE van_items ADD COLUMN UnitName TEXT');
          } catch (_) {}
        }

        // v5 -> v6: add bills & bill_items tables for offline billing sync
        if (oldVersion < 6) {
          await _createBillingTables(db);
        }

        // v6 -> v7: store the exact payloads sent to the server on each
        // bill/item so a failed sync can be replayed later (retry) without
        // having to reconstruct the payload from partial local columns.
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE bills ADD COLUMN headerPayloadJson TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE bill_items ADD COLUMN detailPayloadJson TEXT');
          } catch (_) {}
        }

        // v7 -> v8: bill_items table was missing the unitId column, so the
        // unit each line was billed in never made it into the local row
        // (DirectSaleOfCustomer._saveBill() has been passing 'unitId' in
        // the item map since the BillItem model gained a unitId field, but
        // the insert failed with "table bill_items has no column named
        // unitId" until this column exists).
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE bill_items ADD COLUMN unitId TEXT');
          } catch (_) {}
        }

        // v8 -> v9: the 'receipts' table was never created by any prior
        // version, even though insertLocalReceipt/updateLocalReceipt/
        // getReceiptsByAccountCode etc. all assume it exists. Existing
        // installs on v8 or earlier would hit "no such table: receipts"
        // the first time a receipt was saved or read. Create it now.
        if (oldVersion < 9) {
          await _createReceiptsTable(db);
        }

        // v9 -> v10: Receiptpage now captures the customer's name/address
        // at save time (so a receipt still shows the right customer even
        // if that customer record changes later) and supports a cheque
        // image in addition to the existing gpay screenshot. Add the
        // three columns; try/catch guards against a fresh v9 install that
        // already went through _createReceiptsTable with these columns
        // present via onCreate on some future schema bump.
        if (oldVersion < 10) {
          try {
            await db.execute('ALTER TABLE receipts ADD COLUMN accountName TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE receipts ADD COLUMN customerAddress TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE receipts ADD COLUMN chequeImagePath TEXT');
          } catch (_) {}
        }

        // v10 -> v11: add sale_orders & sale_order_items tables for
        // offline sale-order sync (see Sync_AliasDirectSales /
        // Sync_AliasDirectSaleDetails — AliaseSales / AliaseSalesDetails
        // on the server). Orders are a separate flow from bills: an order
        // can later be converted into a bill, but is tracked independently
        // until then.
        if (oldVersion < 11) {
          await _createSaleOrderTables(db);
        }

        // v11 -> v12: sale_orders previously stored the order series and
        // order number pre-joined into a single `orderNo` string (e.g.
        // "B2C/SO/-1"), which made the two impossible to use separately
        // downstream. SaleOrderPage now saves them as two distinct
        // values — add the columns here so existing v11 installs (which
        // already ran _createSaleOrderTables without them) don't hit
        // "table sale_orders has no column named orderSeries" the next
        // time an order is saved. `orderNo` is kept as-is for backward
        // compatibility / display.
        if (oldVersion < 12) {
          try {
            await db.execute('ALTER TABLE sale_orders ADD COLUMN orderSeries TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE sale_orders ADD COLUMN orderNumber INTEGER');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createCategoriesAndItemsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        categoryId INTEGER PRIMARY KEY,
        categoryName TEXT,
        categoryCode TEXT,
        categoryType INTEGER,
        categoryParent INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS van_items (
        itemId INTEGER PRIMARY KEY,
        itemName TEXT,
        categoryId INTEGER,
        mrp REAL,
        dp REAL,
        sp REAL,
        wp REAL,
        ccp REAL,
        stock REAL,
        totalStock REAL,
        netStock REAL,
        taxPercent REAL,
        hsn TEXT,
        companyId INTEGER,
        UnitID INTEGER,
        UnitName TEXT
      )
    ''');
  }

  // ------------------------------------------------------
  // BILLING TABLES
  // ------------------------------------------------------
  Future<void> _createBillingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        suitAppsId TEXT UNIQUE,
        billNo TEXT,
        billSeries TEXT,
        customerId TEXT,
        customerName TEXT,
        companyId TEXT,
        paymentType TEXT,
        subTotal REAL,
        totalDiscount REAL,
        totalTax REAL,
        roundOff REAL,
        totalAmount REAL,
        billDate TEXT,
        isSynced INTEGER DEFAULT 0,
        serverBillId TEXT,
        createdAt TEXT,
        isExcluding TEXT,
        headerPayloadJson TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        billSuitAppsId TEXT,
        suitAppsId TEXT,
        productId TEXT,
        itemName TEXT,
        qty REAL,
        freeQty REAL,
        rate REAL,
        rateType TEXT,
        unitId TEXT,
        grossAmount REAL,
        discountPercent REAL,
        discountAmount REAL,
        taxAmount REAL,
        netAmount REAL,
        isSynced INTEGER DEFAULT 0,
        detailPayloadJson TEXT,
        FOREIGN KEY (billSuitAppsId) REFERENCES bills (suitAppsId) ON DELETE CASCADE
      )
    ''');
  }

  // ------------------------------------------------------
  // RECEIPTS TABLE
  // ------------------------------------------------------
  // Columns match every field written by insertLocalReceipt /
  // updateLocalReceipt below. 'accountCode' is the customer/party code
  // (PartyID) each receipt belongs to — it's what CustomerRecepitPage
  // filters on to show one customer's receipts. 'accountName' and
  // 'customerAddress' are captured at save time so a receipt still shows
  // the right customer details even if the source customer record
  // changes later. 'chequeImagePath' mirrors 'gpayImagePath' but for the
  // cheque payment mode.
  Future<void> _createReceiptsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        suitAppsId TEXT UNIQUE,
        rootId TEXT,
        accountCode TEXT,
        accountName TEXT,
        customerAddress TEXT,
        amount REAL,
        paymentType TEXT,
        narration TEXT,
        chequeNo TEXT,
        chequeDate TEXT,
        bankName TEXT,
        chequeImagePath TEXT,
        gpayImagePath TEXT,
        approvalStatus INTEGER DEFAULT 0,
        isSynced INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT,
        serverId TEXT
      )
    ''');

    // accountCode is queried on every receipts screen (customer receipts
    // list, sync queue, etc.) so index it instead of doing a full table scan.
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_receipts_accountCode
      ON receipts (accountCode)
    ''');
  }

  // ------------------------------------------------------
  // SALE ORDER TABLES
  // ------------------------------------------------------
  // Column names mirror the server's AliaseSales / AliaseSalesDetails
  // tables (see Sync_AliasDirectSales / Sync_AliasDirectSaleDetails),
  // camelCased to match this project's local-table convention (same
  // pattern as `receipts` vs InsertReceiptMob, `bills` vs
  // Sync_BillingApp2). A few notes on fields that don't map 1:1:
  //
  //   • serverOrderId (local) <-> DSID (server) — DSID is the server's
  //     row id, filled in locally only once a sync succeeds, same as
  //     bills.serverBillId. `id` here is purely a local autoincrement key
  //     and is never sent to the server.
  //   • orderSeries / orderNumber — added in schema v12. Previously the
  //     app pre-joined these into a single `orderNo` string (e.g.
  //     "B2C/SO/-1"), which made the series and the numeric part
  //     impossible to use separately (sorting, filtering, sending to the
  //     server as distinct fields, etc). SaleOrderPage now saves them as
  //     two separate values: orderSeries (TEXT, e.g. "B2C") and
  //     orderNumber (INTEGER, e.g. 11). `orderNo` is kept alongside as a
  //     legacy combined display string for any screen that still expects
  //     one field (e.g. bill printing) — drop it once nothing depends on
  //     it.
  //   • orderNo — Sync_AliasDirectSales GENERATES this itself on insert
  //     (see the proc: "@NO = COUNT(OrderNo)+1 ... @OrderNo=@UID+'-'+@NO")
  //     and does NOT return it via an OUT parameter. That means the app
  //     has no way to learn the server-assigned OrderNo from the sync
  //     response alone — after a successful insert sync, a follow-up
  //     lookup (e.g. SELECT OrderNo FROM AliaseSales WHERE DSID=@OutDSID)
  //     is needed to populate this column, or the proc needs an
  //     additional @OutOrderNo OUTPUT param. Left as a TODO — orderNo
  //     stays whatever the app previewed locally until that's resolved.
  //   • modifiedBy — Sync_AliasDirectSales's insert-vs-update check is
  //     `WHERE SuitApps_id=@SuitApps_id AND ModifiedBy=0`. Per team
  //     decision, the app ALWAYS sends ModifiedBy=0 on every sync call
  //     (create and edit alike) to avoid tripping this into the INSERT
  //     branch again and creating a duplicate order — see
  //     SaleOrderSyncService._toApiPayload.
  //   • CGST/SGST — AliaseSalesDetails splits tax into CGST_Rate/CGST_Amt
  //     and SGST_Rate/SGST_Amt (intra-state GST), but BillItem/ProductData
  //     only carry a single combined tax %. Per team decision, this is
  //     split evenly (CGST = SGST = taxPercent / 2) when building the
  //     sync payload — see SaleOrderSyncService. There's no IGST column
  //     at all, so inter-state orders aren't representable in this schema
  //     as it stands.
  //   • No UnitID column exists on AliaseSalesDetails (unlike
  //     BillingDetails), so sale order items don't carry a unit id
  //     server-side, even though bill items do.
  Future<void> _createSaleOrderTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        suitAppsId TEXT UNIQUE,
        serverOrderId TEXT,
        orderSeries TEXT,
        orderNumber INTEGER,
        orderNo TEXT,
        orderDate TEXT,
        customerId TEXT,
        customerName TEXT,
        customerSuitAppsId TEXT,
        userId INTEGER,
        companyId INTEGER,
        amount REAL,
        advanceAmount REAL,
        totalAmount REAL,
        orderStatus REAL,
        discount REAL,
        discountRate TEXT,
        billSeries TEXT,
        billNo TEXT,
        aliasBillNo TEXT,
        fYearId INTEGER,
        invType TEXT,
        billMode INTEGER,
        narration TEXT,
        createdBy INTEGER,
        createdDate TEXT,
        modifiedBy INTEGER DEFAULT 0,
        modifiedDate TEXT,
        deletedBy INTEGER,
        deletedDate TEXT,
        isDeleted INTEGER DEFAULT 0,
        isSynced INTEGER DEFAULT 0,
        headerPayloadJson TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderSuitAppsId TEXT,
        suitAppsId TEXT,
        productId TEXT,
        itemName TEXT,
        qty REAL,
        freeQty REAL,
        rate REAL,
        mrp REAL,
        grossValue REAL,
        netAmount REAL,
        taxRate TEXT,
        taxAmount REAL,
        cgstRate TEXT,
        cgstAmount REAL,
        sgstRate TEXT,
        sgstAmount REAL,
        fCessRate TEXT,
        fCessAmount REAL,
        discountPercent REAL,
        discountAmount REAL,
        isSynced INTEGER DEFAULT 0,
        detailPayloadJson TEXT,
        FOREIGN KEY (orderSuitAppsId) REFERENCES sale_orders (suitAppsId) ON DELETE CASCADE
      )
    ''');
  }

  // ------------------------------------------------------
  // CATEGORIES
  // ------------------------------------------------------
  Future<void> saveCategories(List<ItemCategory> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('categories');
      final batch = txn.batch();
      for (final cat in categories) {
        batch.insert(
          'categories',
          cat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<ItemCategory>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'categoryName ASC');
    return rows.map((r) => ItemCategory.fromMap(r)).toList();
  }

  // ------------------------------------------------------
  // VAN ITEMS
  // ------------------------------------------------------
  Future<void> saveVanItems(List<ProductData> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('van_items');
      final batch = txn.batch();
      for (final item in items) {
        batch.insert(
          'van_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Returns items already joined with their category name for easy display/filtering.
  Future<List<ProductData>> getVanItems() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.*, c.categoryName AS categoryName
      FROM van_items v
      LEFT JOIN categories c ON c.categoryId = v.categoryId
      ORDER BY v.itemName ASC
    ''');
    return rows.map((r) => ProductData.fromMap(r)).toList();
  }

  Future<void> clearCategoriesAndItems() async {
    final db = await database;
    await db.delete('categories');
    await db.delete('van_items');
  }

  // ------------------------------------------------------
  // BILLING
  // ------------------------------------------------------

  /// Inserts a bill header + its line items in a single transaction.
  /// `bill` is a flat map matching the `bills` table columns.
  /// `items` is a list of flat maps matching the `bill_items` table columns
  /// (billSuitAppsId will be set automatically from bill['suitAppsId']).
  Future<void> insertBillWithItems(
    Map<String, dynamic> bill,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    final suitAppsId = bill['suitAppsId'] as String;

    await db.transaction((txn) async {
      await txn.insert(
        'bills',
        bill,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Clear any previous items for this bill (covers retry/replace case)
      await txn.delete(
        'bill_items',
        where: 'billSuitAppsId = ?',
        whereArgs: [suitAppsId],
      );

      final batch = txn.batch();
      for (final item in items) {
        final row = Map<String, dynamic>.from(item);
        row['billSuitAppsId'] = suitAppsId;
        batch.insert('bill_items', row);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Marks a bill (and its items) as synced once the server confirms save.
  Future<void> markBillSynced(String suitAppsId, String serverBillId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'bills',
        {'isSynced': 1, 'serverBillId': serverBillId},
        where: 'suitAppsId = ?',
        whereArgs: [suitAppsId],
      );
      await txn.update(
        'bill_items',
        {'isSynced': 1},
        where: 'billSuitAppsId = ?',
        whereArgs: [suitAppsId],
      );
    });
  }

  /// All bill headers that haven't synced to the server yet, oldest first
  /// (so retries preserve the original billing order / sequence).
  Future<List<Map<String, dynamic>>> getUnsyncedBills() async {
    final db = await database;
    return db.query(
      'bills',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'createdAt ASC',
    );
  }

  /// Line items belonging to a given bill (by its local suitAppsId).
  Future<List<Map<String, dynamic>>> getItemsForBill(String suitAppsId) async {
    final db = await database;
    return db.query(
      'bill_items',
      where: 'billSuitAppsId = ?',
      whereArgs: [suitAppsId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllBills() async {
    final db = await database;
    return db.query('bills', orderBy: 'createdAt DESC');
  }


        /////////// Receipt management methods///////////////////

Future<void> insertLocalReceipt(Map<String, dynamic> receiptData) async {
  final db = await database;
  final now = DateTime.now().toIso8601String();

  final data = {
    'suitAppsId': receiptData['suitAppsId'] ?? '',
    'rootId': receiptData['rootId'],
    'accountCode': receiptData['accountCode'] ?? '',
    'accountName': receiptData['accountName'] ?? '',
    'customerAddress': receiptData['customerAddress'] ?? '',
    'amount': receiptData['amount'] ?? 0.0,
    'paymentType': receiptData['paymentType'] ?? '',
    'narration': receiptData['narration'] ?? '',
    'chequeNo': receiptData['chequeNo'] ?? '',
    'chequeDate': receiptData['chequeDate'] ?? '',
    'bankName': receiptData['bankName'] ?? '',  // Added bankName support
    'chequeImagePath': receiptData['chequeImagePath'] ?? '',
    'gpayImagePath': receiptData['gpayImagePath'] ?? '',
    'approvalStatus': receiptData['approvalStatus'] ?? 0,
    'isSynced': receiptData['isSynced'] ?? 0,
    'createdAt': receiptData['createdAt'] ?? now,
    'updatedAt': receiptData['updatedAt'] ?? now,
    'serverId': receiptData['serverId'],
  };

  await db.insert(
    'receipts',
    data,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

  Future<void> markReceiptSynced(String suitAppsId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'receipts',
      {
        'isSynced': 1,
        'updatedAt': now,
      },
      where: 'suitAppsId = ?',
      whereArgs: [suitAppsId],
    );
  }

  /// Receipts for a single customer/party, filtered by their account code
  /// (PartyID) directly in SQL. This is what CustomerRecepitPage should
  /// call instead of pulling every receipt and filtering client-side.
  Future<List<Map<String, dynamic>>> getReceiptsByAccountCode(String accountCode) async {
    final db = await database;
    return await db.query(
      'receipts',
      where: 'accountCode = ?',
      whereArgs: [accountCode],
      orderBy: 'createdAt DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllReceipts() async {
    final db = await database;
    return await db.query(
      'receipts',
      orderBy: 'createdAt DESC',
    );
  }
  Future<void> updateLocalReceipt(Map<String, dynamic> receiptData) async {
  final db = await database;
  final now = DateTime.now().toIso8601String();
  final suitAppsId = receiptData['suitAppsId'];

  if (suitAppsId == null || suitAppsId.isEmpty) {
    throw Exception('suitAppsId is required for updating receipt');
  }

  final updateFields = {
    'rootId': receiptData['rootId'],
    'accountCode': receiptData['accountCode'] ?? '',
    'accountName': receiptData['accountName'] ?? '',
    'customerAddress': receiptData['customerAddress'] ?? '',
    'amount': receiptData['amount'] ?? 0.0,
    'paymentType': receiptData['paymentType'] ?? '',
    'narration': receiptData['narration'] ?? '',
    'chequeNo': receiptData['chequeNo'] ?? '',
    'chequeDate': receiptData['chequeDate'] ?? '',
    'bankName': receiptData['bankName'] ?? '',  // Added bankName support
    'chequeImagePath': receiptData['chequeImagePath'] ?? '',
    'gpayImagePath': receiptData['gpayImagePath'] ?? '',
    'approvalStatus': receiptData['approvalStatus'] ?? 0,
    'isSynced': receiptData['isSynced'] ?? 0,
    'updatedAt': now,
    'serverId': receiptData['serverId'],
  };

  final rowsAffected = await db.update(
    'receipts',
    updateFields,
    where: 'suitAppsId = ?',
    whereArgs: [suitAppsId],
  );

  if (rowsAffected == 0) {
    throw Exception('No receipt found with suitAppsId: $suitAppsId');
  }
 }
 Future<Map<String, dynamic>?> getReceiptBySuitAppsId(String suitAppsId) async {
  final db = await database;
  final result = await db.query(
    'receipts',
    where: 'suitAppsId = ?',
    whereArgs: [suitAppsId],
    limit: 1,
      );
  return result.isNotEmpty ? result.first : null;
 }


 Future<List<Map<String, dynamic>>> getUnsyncedReceipts() async {
  final db = await database; // adjust to your actual db-getter name
  return db.query('receipts', where: 'isSynced = ?', whereArgs: [0]);
}

  // ------------------------------------------------------
  // SALE ORDERS
  // ------------------------------------------------------

  /// Inserts a sale order header + its line items in a single transaction.
  /// `order_` is a flat map matching the `sale_orders` table columns.
  /// `items` is a list of flat maps matching the `sale_order_items` table
  /// columns (orderSuitAppsId is set automatically from
  /// order_['suitAppsId']). Same REPLACE-on-unique-suitAppsId pattern as
  /// insertBillWithItems, so calling this again with the same suitAppsId
  /// acts as an update (used by SaleOrderPage's edit mode).
  Future<void> insertSaleOrderWithItems(
    Map<String, dynamic> order_,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    final suitAppsId = order_['suitAppsId'] as String;

    await db.transaction((txn) async {
      await txn.insert(
        'sale_orders',
        order_,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'sale_order_items',
        where: 'orderSuitAppsId = ?',
        whereArgs: [suitAppsId],
      );

      final batch = txn.batch();
      for (final item in items) {
        final row = Map<String, dynamic>.from(item);
        row['orderSuitAppsId'] = suitAppsId;
        batch.insert('sale_order_items', row);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Marks a sale order (and its items) as synced once the server confirms
  /// save, storing the server's DSID as serverOrderId.
  Future<void> markSaleOrderSynced(String suitAppsId, String serverOrderId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'sale_orders',
        {'isSynced': 1, 'serverOrderId': serverOrderId},
        where: 'suitAppsId = ?',
        whereArgs: [suitAppsId],
      );
      await txn.update(
        'sale_order_items',
        {'isSynced': 1},
        where: 'orderSuitAppsId = ?',
        whereArgs: [suitAppsId],
      );
    });
  }

  /// All sale order headers that haven't synced to the server yet, oldest
  /// first (so retries preserve the original order sequence).
  Future<List<Map<String, dynamic>>> getUnsyncedSaleOrders() async {
    final db = await database;
    return db.query(
      'sale_orders',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'createdDate ASC',
    );
  }

  /// Line items belonging to a given sale order (by its local suitAppsId).
  Future<List<Map<String, dynamic>>> getItemsForSaleOrder(String suitAppsId) async {
    final db = await database;
    return db.query(
      'sale_order_items',
      where: 'orderSuitAppsId = ?',
      whereArgs: [suitAppsId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllSaleOrders() async {
    final db = await database;
    return db.query('sale_orders', orderBy: 'createdDate DESC');
  }

  Future<Map<String, dynamic>?> getSaleOrderBySuitAppsId(String suitAppsId) async {
    final db = await database;
    final result = await db.query(
      'sale_orders',
      where: 'suitAppsId = ?',
      whereArgs: [suitAppsId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

}