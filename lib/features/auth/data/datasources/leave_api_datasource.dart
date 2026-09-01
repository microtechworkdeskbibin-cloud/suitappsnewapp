import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:suitapps/core/config/api_config.dart';

class LeaveService {

  /// =========================
  /// GET LEAVE TYPES
  /// =========================
  static Future<List<dynamic>> getLeaveTypes(int companyId) async {
    final url = Uri.parse(
      '${ApiConfig.apiBaseUrl}${ApiConfig.getLeaveTypes}?CompanyID=$companyId',
    );

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      if (data is List) return data;
      if (data is Map && data['data'] != null) return data['data'];

      return [];
    }

    throw Exception("Failed to load leave types");
  }

  /// =========================
  /// APPLY LEAVE
  /// =========================
  static Future<bool> applyLeave(Map<String, dynamic> body) async {
    final url = Uri.parse(
      '${ApiConfig.apiBaseUrl}${ApiConfig.insertLeaveRequest}',
    );

    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(res.body);

    print("Leave Response: $data");

    if (res.statusCode == 200 || res.statusCode == 201) {
      if (data is Map && data.containsKey("Success")) {
        return data["Success"] == 1 || data["Success"] == true;
      }
      return true;
    }

    return false;
  }
}
