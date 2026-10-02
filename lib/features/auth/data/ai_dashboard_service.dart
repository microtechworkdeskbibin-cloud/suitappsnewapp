import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:suitapps/core/config/api_config.dart';

class AiDashboardService {

  static Future<String> ask({

    required int userId,
    required int companyId,

    required String fromDate,
    required String toDate,

    required String question,

  }) async {

    final uri = Uri.parse(
      '${ApiConfig.apiBaseUrl}/api/TSMDashboard/ai-insight',
    );

    final response = await http.post(

      uri,

      headers: {
        'Content-Type': 'application/json',
      },

      body: jsonEncode({

        'UserId': userId,

        'CompanyID': companyId,

        'FromDate': fromDate,

        'ToDate': toDate,

        'question': question,

      }),

    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {

      throw Exception(
        'AI API Error ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body);

    if (json['success'] != true) {

      throw Exception(
        json['message'] ??
        'AI request failed',
      );
    }

    // Currently the backend returns the generated prompt.
    // Once the AI provider is connected, return:
    //
    // json['data']['answer']

    return json['data']['answer'] ??
        'AI response is ready.';
  }
}