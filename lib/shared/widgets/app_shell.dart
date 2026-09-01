import 'package:flutter/material.dart';
import 'package:suitapps/features/auth/presentation/pages/login_page.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String? title;

  final String backgroundImage;

  const AppShell({
    super.key,
    required this.child,
    this.title,
    this.backgroundImage = 'assets/images/login-bg-1.jpg',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              backgroundColor: LoginPage.brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
      body: Stack(
        children: [
          Image.asset(
            backgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: DefaultTextStyle(
                      style:
                          theme.textTheme.bodyMedium ??
                          const TextStyle(fontSize: 14),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
