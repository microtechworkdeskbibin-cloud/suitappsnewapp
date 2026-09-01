import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionService {
  static const _keyRouteId = 'routeId';
  static const _keyRouteName = 'routeName';

  /// Save route info (non-sensitive) in session prefs
  Future<void> setRouteInfo({
    required String routeId,
    required String routeName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRouteId, routeId);
    await prefs.setString(_keyRouteName, routeName);
  }

  Future<Map<String, String?>> getRouteInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'routeId': prefs.getString(_keyRouteId),
      'routeName': prefs.getString(_keyRouteName),
    };
  }

  Future<void> printRouteInfo() async {
    final routeInfo = await getRouteInfo();
    print('Route Info: $routeInfo');
  }

  /// Clear stored session-related keys (route info only here)
  Future<void> clearRouteInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRouteId);
    await prefs.remove(_keyRouteName);
  }
}
