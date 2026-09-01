import 'package:flutter/material.dart';
import 'package:suitapps/routes/app_routes.dart';
import 'package:suitapps/shared/theme/app_theme.dart';

void main() => runApp(const SuitAppsApp());

class SuitAppsApp extends StatelessWidget {
  const SuitAppsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Suitapps',
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
