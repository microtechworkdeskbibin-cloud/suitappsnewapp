/// Mirrors the local SQLite `permissions` table (synced from
/// dbo.AppPermissions). One row per (companyId, userId, permissionCode).
class AppPermission {
  final int permissionId;
  final int companyId;
  final int userId;
  final String permissionCode;
  final String permissionName;
  final String module;
  final String permissionType; // 'BOOL' or 'OPTION'
  final String permissionValue; // '1'/'0' for BOOL, e.g. 'BOTH' for OPTION
  final bool isActive;

  const AppPermission({
    required this.permissionId,
    required this.companyId,
    required this.userId,
    required this.permissionCode,
    required this.permissionName,
    required this.module,
    required this.permissionType,
    required this.permissionValue,
    required this.isActive,
  });

  /// Convenience for BOOL-type permissions. Anything not "1"/"true" is false.
  bool get boolValue {
    final v = permissionValue.trim().toLowerCase();
    return v == '1' || v == 'true';
  }

  factory AppPermission.fromMap(Map<String, dynamic> map) {
    return AppPermission(
      permissionId: map['permissionId'] as int,
      companyId: map['companyId'] as int,
      userId: map['userId'] as int,
      permissionCode: map['permissionCode'] as String,
      permissionName: map['permissionName'] as String? ?? '',
      module: map['module'] as String? ?? '',
      permissionType: map['permissionType'] as String? ?? 'BOOL',
      permissionValue: map['permissionValue']?.toString() ?? '0',
      isActive: map['isActive'] == 1 || map['isActive'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'permissionId': permissionId,
      'companyId': companyId,
      'userId': userId,
      'permissionCode': permissionCode,
      'permissionName': permissionName,
      'module': module,
      'permissionType': permissionType,
      'permissionValue': permissionValue,
      'isActive': isActive ? 1 : 0,
    };
  }
}