# suitapps

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

lib/
|   main.dart
|
+---config
|       api_config.dart
|
+---core
|       session_store.dart
|
+---features  
|   |
|   +---auth
|   |   +---dashboard
|   |   |   |   dashboard_constants.dart
|   |   |   |   dashboard_page.dart
|   |   |   |
|   |   |   \---widgets
|   |   |           activity_timeline.dart
|   |   |           dashboard_header.dart
|   |   |           dashboard_segments.dart
|   |   |           overview_cards.dart
|   |   |           sales_orders_chart.dart
|   |   |
|   |   +---login
|   |   |       login_page.dart
|   |   |
|   |   +---profile
|   |   |       edit_profile_page.dart
|   |   |       profile_page.dart
|   |   |
|   |   \---settings
|   |           settings_page.dart
|   |
|   \---splash
|           splash_page.dart
|
\---shared
    +---utils
    |       responsive.dart
    |       ui_helpers.dart
    \
    \---widgets
            app_drawer.dart
            app_shell.dart
            common_bottom_nav.dart
