import 'package:flutter/material.dart';

import 'sales_head_dashboard_page.dart';

class TSMDashboardPage extends StatelessWidget {
  final Map<String, dynamic> userDecoded;
  final String sessionId;

  const TSMDashboardPage({
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