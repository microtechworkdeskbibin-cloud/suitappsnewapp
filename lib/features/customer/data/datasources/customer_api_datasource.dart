import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:suitapps/core/config/api_config.dart';

class CustomerApiService {
  Future<List<Map<String, dynamic>>> fetchCustomers({
    required String rootId,
    required String companyId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.getCustomersUrl}',
    ).replace(queryParameters: {'RootID': rootId, 'CompanyID': companyId});

    debugPrint('Customer API URL: $uri');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch customers (${response.statusCode})');
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
      return [decoded];
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> fetchRoots({required String empId}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.getAllRootsByEmp}',
    ).replace(queryParameters: {'EmpID': empId});

    debugPrint('Roots API URL: $uri');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch roots (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      if (decoded['success'] == false) {
        throw Exception(
          'Failed to fetch roots: ${decoded['message'] ?? 'unknown error'}',
        );
      }
      if (decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }

    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    return [];
  }

  // NEW: fetches every account with IfDistributor = 1 for the given
  // company, for the "select distributor" dropdown on
  // CustomerDashboardPage. Mirrors /GetDistributors on the server (see
  // customer_routes.js), which returns AccountID/AccountName/AccountCode.
  Future<List<Map<String, dynamic>>> getDistributors({
    required String companyId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.getDistributorsUrl}',
    ).replace(queryParameters: {'CompanyID': companyId});

    debugPrint('Distributors API URL: $uri');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch distributors (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      if (decoded['success'] == false) {
        throw Exception(
          'Failed to fetch distributors: ${decoded['message'] ?? 'unknown error'}',
        );
      }
      if (decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }

    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    return [];
  }

  // NEW: pushes one locally-saved customer/distributor row up to
  // /InsertUpdateCustomer -> APPInsertUpdateAccount. `payload` must already
  // be shaped with the SERVER's parameter names (AccountName, SuitAppsId,
  // Type, CompanyID, IfDistributor, DistribtrWiseCustId, etc. — see
  // APPInsertUpdateAccount.sql for the full param list), NOT the local
  // CustomerModel field names. Build that mapping in CustomerSyncService
  // (see customer_sync_service.dart), the same way SaleOrderSyncService
  // builds _toHeaderPayload from a local sale_orders row.
  Future<Map<String, dynamic>> insertOrUpdateCustomer(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.insertCustomer}');

    debugPrint('Insert Customer API URL: $uri');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['error'] ??
            decoded['message'] ??
            'Failed to save customer (${response.statusCode})',
      );
    }

    if (decoded['success'] != true) {
      throw Exception(decoded['error'] ?? decoded['message'] ?? 'Save rejected by server');
    }

    return decoded;
  }
}

