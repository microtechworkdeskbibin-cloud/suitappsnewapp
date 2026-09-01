import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/features/auth/presentation/pages/login_page.dart';

class SessionTimeoutService {
  Timer? _timer;

  void start(BuildContext context) {
    _scheduleLogout(context);
  }

  void _scheduleLogout(BuildContext context) {

    final now = DateTime.now();

    final midnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
      0,
      0,
      0,
    );

    final remaining = midnight.difference(now);

    debugPrint("Auto logout scheduled at: $midnight");
    debugPrint("Remaining: $remaining");


    _timer = Timer(remaining, () async {

      debugPrint("AUTO LOGOUT TRIGGERED");

      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn =
          prefs.getBool('isLoggedIn') ?? false;

      debugPrint("LOGIN STATUS = $isLoggedIn");


      if (isLoggedIn) {

        await prefs.clear();

        debugPrint("SESSION CLEARED");

        if (!context.mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginPage(),
          ),
          (route) => false,
        );

        debugPrint("MOVED TO LOGIN");
      }


      // next day timer
      _scheduleLogout(context);
    });
  }


  void stop() {
    _timer?.cancel();
  }
}
