import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/core/database/tables.dart';

// lib/services/billing_api_service.dart

class BillingApiService {
  /// Pretty-prints a payload map/list to the console, in chunks, so long
  /// JSON isn't truncated by the log line-length limit. Also lists any
  /// top-level keys whose value is null / empty-string â€” the most common
  /// reason a field "doesn't pass" to the server.
  static void _logPayload(String label, dynamic payload) {
    const encoder = JsonEncoder.withIndent('  ');
    final pretty = encoder.convert(payload);
    debugPrint('â”€â”€â”€â”€ $label â”€â”€â”€â”€');
    // debugPrint truncates long strings on some platforms; chunk it.
    for (var i = 0; i < pretty.length; i += 800) {
      debugPrint(pretty.substring(i, i + 800 > pretty.length ? pretty.length : i + 800));
    }

    if (payload is Map<String, dynamic>) {
      _flagSuspectFields(label, payload);
    } else if (payload is List) {
      for (var i = 0; i < payload.length; i++) {
        final item = payload[i];
        if (item is Map<String, dynamic>) {
          _flagSuspectFields('$label[$i]', item);
        }
      }
    }
  }

  static void _flagSuspectFields(String label, Map<String, dynamic> map) {
    final suspects = <String>[];
    map.forEach((key, value) {
      if (value == null || value == '' ) {
        suspects.add('$key = ${value == null ? 'null' : '""'}');
      }
    });
    if (suspects.isNotEmpty) {
      debugPrint('âš ï¸  $label has empty/null fields: ${suspects.join(', ')}');
    }
  }

  static void _logResponse(String label, http.Response response) {
    debugPrint('â”€â”€â”€â”€ $label response (${response.statusCode}) â”€â”€â”€â”€');
    final body = response.body;
    for (var i = 0; i < body.length; i += 800) {
      debugPrint(body.substring(i, i + 800 > body.length ? body.length : i + 800));
    }
  }

  /// Syncs the bill header. Returns the server response map, or throws.
  static Future<Map<String, dynamic>> syncBillingHeader(
    Map<String, dynamic> billPayload,
  ) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.insertBilling}');

    final requestBody = {
      'billingList': [billPayload],
    };

    // 1. See exactly what you're about to send, and which fields are
    //    null/empty before it even leaves the device.
    _logPayload('syncBillingHeader â†’ request', requestBody);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    // 2. See exactly what the server sent back.
    _logResponse('syncBillingHeader', response);

    if (response.statusCode != 200) {
      throw Exception('Header sync failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Header sync failed');
    }

    // billingList: [ { Message, BillID, SuitApps_id } ]
    final result = (decoded['billingList'] as List).first as Map<String, dynamic>;

    // 3. Confirm the server actually gave back a BillID â€” if this is
    //    null, everything downstream (detail sync, local sync flag)
    //    will silently no-op.
    if (result['BillID'] == null) {
      debugPrint('âš ï¸  syncBillingHeader: server response has no BillID â€” '
          'details will NOT be synced. Full item: $result');
    }

    return result;
  }

  /// Syncs bill line items. billDetailPayloads must each include DSID (server BillID).
  static Future<List<dynamic>> syncBillingDetails(
    List<Map<String, dynamic>> billDetailPayloads,
  ) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.insertBillingDetails}');

    final requestBody = {
      'billingDetailList': billDetailPayloads,
    };

    _logPayload('syncBillingDetails â†’ request', requestBody);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    _logResponse('syncBillingDetails', response);

    if (response.statusCode != 200) {
      throw Exception('Detail sync failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded['success'] != true) {
      throw Exception(decoded['ErrorMessage'] ?? 'Detail sync failed');
    }

    return decoded['billingDetailList'] as List;
  }
}
