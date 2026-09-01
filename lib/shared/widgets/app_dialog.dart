import 'package:flutter/material.dart';

class AppDialog {
  AppDialog._();

  static Future<void> showMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
}
