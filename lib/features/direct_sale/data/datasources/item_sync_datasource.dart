import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/features/direct_sale/data/models/item_category_model.dart';
import 'package:suitapps/features/direct_sale/data/models/sale_item_model.dart';

class ItemSyncService {
  /// Calls GET {apiBaseUrl}/item/GetItemCategory
  static Future<List<ItemCategory>> fetchCategories() async {
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.getItemCategoryUrl}');

    // ignore: avoid_print
    print('SYNC URL (categories) >>> $uri');

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    // ignore: avoid_print
    print('SYNC STATUS (categories) >>> ${response.statusCode}');
    // ignore: avoid_print
    print('SYNC BODY (categories) >>> ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to load categories (status ${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message'] ?? body['error'] ?? 'Unknown error loading categories');
    }

    final List<dynamic> data = body['data'] as List<dynamic>? ?? [];

    // ignore: avoid_print
    print('SYNC PARSED COUNT (categories) >>> ${data.length}');

    return data
        .map((item) => ItemCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Calls GET {apiBaseUrl}/item/GetVanItems?VanID=..&CompanyId=..
  static Future<List<ProductData>> fetchVanItems({
    required int vanId,
    required int companyId,
  }) async {
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.getVanItemsUrl}').replace(
      queryParameters: {
        'VanID': vanId.toString(),
        'CompanyId': companyId.toString(),
      },
    );

    // ignore: avoid_print
    print('SYNC URL (van items) >>> $uri');
    // ignore: avoid_print
    print('SYNC PARAMS (van items) >>> vanId=$vanId, companyId=$companyId');

    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    // ignore: avoid_print
    print('SYNC STATUS (van items) >>> ${response.statusCode}');
    // ignore: avoid_print
    print('SYNC BODY (van items) >>> ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to load van items (status ${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message'] ?? body['error'] ?? 'Unknown error loading van items');
    }

    final List<dynamic> data = body['data'] as List<dynamic>? ?? [];

    // ignore: avoid_print
    print('SYNC PARSED COUNT (van items) >>> ${data.length}');

    return data
        .map((item) => ProductData.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

