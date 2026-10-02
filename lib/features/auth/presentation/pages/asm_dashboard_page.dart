import 'package:flutter/material.dart';

import 'sales_head_dashboard_page.dart';

class ASMDashboardPage extends StatelessWidget {
  final Map<String, dynamic> userDecoded;
  final String sessionId;

  const ASMDashboardPage({
    super.key,
    required this.userDecoded,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return SalesHeadDashboardPage(
      userDecoded: userDecoded,
      sessionId: sessionId,
    );
  }
}