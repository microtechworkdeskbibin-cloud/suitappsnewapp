import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:suitapps/core/database/database_helper.dart';

/// Local cache mirror of the server AppPermissions table
/// (dbo.APPGetPermissions): PermissionID, CompanyID, UserID,
/// PermissionCode, PermissionName, Module, PermissionType,
/// PermissionValue, IsActive.
class PermissionsLocalDbService {
  static const String _table = 'permissions';

  Future<void> ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        permissionId INTEGER PRIMARY KEY,
        companyId TEXT,
        userId TEXT,
        permissionCode TEXT,
        permissionName TEXT,
        module TEXT,
        permissionType TEXT,
        permissionValue TEXT,
        isActive INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_permissions_lookup
      ON $_table (userId, companyId, module, permissionCode)
    ''');
  }

  /// Replaces all cached permission rows for one user+company with a
  /// freshly-fetched set (call this after login and on manual refresh).
  Future<void> savePermissions({
    required String employeeCode, // UserID
    required String companyId,
    required List<Map<String, dynamic>> permissions,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await ensureTable(db);

    debugPrint(
      'Saving ${permissions.length} permission rows for '
      'userId=$employeeCode companyId=$companyId',
    );

    await db.transaction((txn) async {
      await txn.delete(
        _table,
        where: 'userId = ? AND companyId = ?',
        whereArgs: [employeeCode, companyId],
      );

      final batch = txn.batch();
      for (final p in permissions) {
        batch.insert(_table, {
          'permissionId': p['PermissionID'],
          'companyId': p['CompanyID']?.toString() ?? companyId,
          'userId': p['UserID']?.toString(),
          'permissionCode': p['PermissionCode']?.toString(),
          'permissionName': p['PermissionName']?.toString(),
          'module': p['Module']?.toString(),
          'permissionType': p['PermissionType']?.toString(),
          'permissionValue': p['PermissionValue']?.toString(),
          'isActive': (p['IsActive'] == true || p['IsActive'] == 1) ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });

    debugPrint('Permissions saved to local DB.');
  }

  /// Returns permissionCode -> row for one user, company and module.
  Future<Map<String, Map<String, dynamic>>> getPermissionsFor({
    required String employeeCode,
    required String companyId,
    required String module,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await ensureTable(db);

    final rows = await db.query(
      _table,
      where: 'userId = ? AND companyId = ? AND module = ?',
      whereArgs: [employeeCode, companyId, module],
    );

    debugPrint(
      'Loaded ${rows.length} permission rows for '
      'userId=$employeeCode companyId=$companyId module=$module',
    );

    return {
      for (final r in rows) r['permissionCode'] as String: r,
    };
  }

  /// Returns permissionCode -> row for one user+company across ALL modules.
  /// Use this where a screen needs codes from more than one module at once
  /// (e.g. SelectItemPage needs BILLING codes like ALLOW_MANUAL_RATE
  /// alongside STOCK codes like ALLOW_NEGATIVE_STOCK). Assumes
  /// permissionCode is unique per user+company regardless of module, which
  /// holds for the current AppPermissions rows.
  Future<Map<String, Map<String, dynamic>>> getAllPermissionsFor({
    required String employeeCode,
    required String companyId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await ensureTable(db);

    final rows = await db.query(
      _table,
      where: 'userId = ? AND companyId = ?',
      whereArgs: [employeeCode, companyId],
    );

    debugPrint(
      'Loaded ${rows.length} permission rows (all modules) for '
      'userId=$employeeCode companyId=$companyId',
    );

    return {
      for (final r in rows) r['permissionCode'] as String: r,
    };
  }
}
