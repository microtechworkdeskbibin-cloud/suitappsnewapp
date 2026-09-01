import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:suitapps/core/config/api_config.dart';

class PermissionsApiService {
  /// Fetches all permission rows for one user+company from
  /// dbo.APPGetPermissions (via GET /api/permissions?UserID=&CompanyID=).
  Future<List<Map<String, dynamic>>> fetchPermissions({
    required String employeeCode, // this is actually the UserID
    required String companyId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.getPermissionsUrl}',
    ).replace(
      queryParameters: {
        'UserID': employeeCode,
        'CompanyID': companyId,
      },
    );

    debugPrint('Permissions API URL: $uri');

    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    debugPrint('Permissions API status: ${response.statusCode}');
    debugPrint('Permissions API body: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch permissions (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }

    return [];
  }
}
