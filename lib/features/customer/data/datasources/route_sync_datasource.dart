import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/features/auth/data/repositories/auth_session_repository.dart';

/// Fetches which route is allocated to the logged-in employee TODAY and
/// saves it locally along with the time it was synced.
///
/// Call `fetchAndSaveTodayRoute(empId)` once right after a successful login.
/// After that, `getTodayRouteSyncInfo()` tells you which route is "today's
/// route" and when it was last synced - so the Existing Customers page (or
/// anywhere else) can pin that route to the top of the route list.
class RouteSyncService {
  static const _kTodayRouteId = 'TodayRouteId';
  static const _kTodayRouteName = 'TodayRouteName';
  static const _kTodayRouteSyncTime = 'TodayRouteSyncTime';
  static const _kTodayRouteSyncDate = 'TodayRouteSyncDate'; // yyyy-MM-dd

  /// Fetches today's allocated route for [empId] from the API and saves:
  ///  - the route id/name (also pushed into AuthSessionService so existing
  ///    "current route" logic keeps working unchanged)
  ///  - the exact time of this sync (`TodayRouteSyncTime`)
  ///  - the calendar date this sync was for (`TodayRouteSyncDate`), so you
  ///    can tell later whether "today's route" is still actually today's.
  ///
  /// Returns the saved route info, or null if the API call failed or
  /// returned no route.
  Future<Map<String, dynamic>?> fetchAndSaveTodayRoute(int empId) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.getrootNameUrl}?EmpID=$empId&Date=$dateStr',
      );

      print('Route Sync API URL: $uri');

      final res = await http.get(uri).timeout(const Duration(seconds: 20));

      print('Route Sync Status: ${res.statusCode}');
      print('Route Sync Response: ${res.body}');

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(res.body);

      // Be flexible about the response shape: it might come back as a bare
      // object, a list of one route, or wrapped in a "data"/"Table" field.
      Map<String, dynamic>? routeData;
      if (decoded is List && decoded.isNotEmpty) {
        routeData = Map<String, dynamic>.from(decoded.first as Map);
      } else if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map['data'] is List && (map['data'] as List).isNotEmpty) {
          routeData = Map<String, dynamic>.from(map['data'].first as Map);
        } else if (map['Table'] is List && (map['Table'] as List).isNotEmpty) {
          routeData = Map<String, dynamic>.from(map['Table'].first as Map);
        } else if (map.containsKey('RootID') || map.containsKey('RouteID')) {
          routeData = map;
        }
      }

      if (routeData == null) {
        print('Route Sync: no route found in response for empId=$empId');
        return null;
      }

      final routeId =
          routeData['RootID']?.toString() ?? routeData['RouteID']?.toString();
      final routeName =
          routeData['RootName']?.toString() ??
          routeData['RouteName']?.toString() ??
          '';

      if (routeId == null || routeId.isEmpty) {
        print('Route Sync: route id missing in response');
        return null;
      }

      // Keep the existing "current route" mechanism in sync too, so any
      // screen that already reads AuthSessionService.getRouteInfo() picks
      // this up automatically.
      await AuthSessionService().setRouteInfo(
        routeId: routeId,
        routeName: routeName,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTodayRouteId, routeId);
      await prefs.setString(_kTodayRouteName, routeName);
      await prefs.setString(_kTodayRouteSyncTime, now.toIso8601String());
      await prefs.setString(_kTodayRouteSyncDate, dateStr);

      return {
        'routeId': routeId,
        'routeName': routeName,
        'syncTime': now,
        'syncDate': dateStr,
      };
    } catch (e) {
      print('Route Sync ERROR: $e');
      return null;
    }
  }

  /// Returns today's synced route info, or null if nothing has been synced
  /// yet (e.g. first-ever login before any sync completed).
  ///
  /// `isStale` is true if the saved sync happened on a previous calendar
  /// day - useful if you want to trigger a fresh `fetchAndSaveTodayRoute`
  /// call rather than trust yesterday's route.
  Future<Map<String, dynamic>?> getTodayRouteSyncInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final routeId = prefs.getString(_kTodayRouteId);
    final routeName = prefs.getString(_kTodayRouteName);
    final syncTimeStr = prefs.getString(_kTodayRouteSyncTime);
    final syncDate = prefs.getString(_kTodayRouteSyncDate);

    if (routeId == null || syncTimeStr == null) return null;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return {
      'routeId': routeId,
      'routeName': routeName ?? '',
      'syncTime': DateTime.parse(syncTimeStr),
      'syncDate': syncDate,
      'isStale': syncDate != todayStr,
    };
  }
}
