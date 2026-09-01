import 'package:flutter/material.dart';
import 'package:suitapps/features/splash/presentation/pages/splash_page.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SuitappsSplashPage(),
  };
}
