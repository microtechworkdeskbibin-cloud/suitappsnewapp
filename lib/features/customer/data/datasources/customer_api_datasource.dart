import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:suitapps/core/config/api_config.dart';

// import 'dart:convert';

// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;

// import 'package:suitapps/core/config/api_config.dart';

// class CustomerApiService {
//   Future<List<Map<String, dynamic>>> fetchCustomers({
//     required String rootId,
//     required String companyId,
//   }) async {
//     final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.getCustomersUrl}').replace(
//       queryParameters: {
//         'RootID': rootId,
//         'CompanyID': companyId,
//       },
//     );

//     debugPrint('Customer API URL: $uri');
//     final response = await http.get(uri).timeout(const Duration(seconds: 20));

//     if (response.statusCode < 200 || response.statusCode >= 300) {
//       throw Exception('Failed to fetch customers (${response.statusCode})');
//     }

//     final decoded = jsonDecode(response.body);

//     if (decoded is List) {
//       return decoded
//           .whereType<Map<String, dynamic>>()
//           .toList();
//     }

//     if (decoded is Map<String, dynamic>) {
//       if (decoded['data'] is List) {
//         return (decoded['data'] as List)
//             .whereType<Map<String, dynamic>>()
//             .toList();
//       }
//       return [decoded];
//     }

//     return [];
//   }
// }



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
}
