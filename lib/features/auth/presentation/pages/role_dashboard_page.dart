import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'sales_head_dashboard_page.dart';
import 'tsm_dashboard_page.dart';
import 'asm_dashboard_page.dart';
import 'salesman_dashboard_page.dart';

class RoleDashboardPage extends StatelessWidget {
  final Map<String, dynamic> userDecoded;
  final String sessionId;

  const RoleDashboardPage({
    super.key,
    required this.userDecoded,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {

    final roleName = (
      userDecoded['UserRoleName'] ??
      userDecoded['RoleName'] ??
      userDecoded['UserRole'] ??
      ''
    ).toString().trim().toLowerCase();

    final roleId = int.tryParse(
      (
        userDecoded['UserRoleId'] ??
        userDecoded['RoleID'] ??
        0
      ).toString(),
    ) ?? 0;

    debugPrint('================================');
    debugPrint('ROLE DASHBOARD');
    debugPrint('User ID  : ${userDecoded['UserId']}');
    debugPrint('Role ID  : $roleId');
    debugPrint('Role     : $roleName');
    debugPrint('================================');


    // ========================================================
    // SALES HEAD
    // ========================================================

    if (roleName == 'Sales Head' || roleId == 10) {

      return SalesHeadDashboardPage(
        userDecoded: userDecoded,
        sessionId: sessionId,
      );
    }


    // ========================================================
    // REGIONAL HEAD
    // ========================================================

    if (roleName == 'Regional Head' || roleId == 11) {

      return SalesHeadDashboardPage(
        userDecoded: userDecoded,
        sessionId: sessionId,
      );
    }


    // ========================================================
    // TSM
    // ========================================================

    if (roleName == 'TSM' || roleId == 12) {

      return TSMDashboardPage(
        userDecoded: userDecoded,
        sessionId: sessionId,
      );
    }


    // ========================================================
    // ASM
    // ========================================================

    if (roleName == 'ASM' || roleId == 13) {

      return ASMDashboardPage(
        userDecoded: userDecoded,
        sessionId: sessionId,
      );
    }


    // ========================================================
    // SALESMAN
    // ========================================================

    if (roleName == 'Salesman' ||
        roleName == 'sales representative' ||
        roleId == 23) {

      return SalesmanDashboardPage(
        userDecoded: userDecoded,
        sessionId: sessionId,
      );
    }


    // ========================================================
    // ADMIN / OTHER ROLES
    // ========================================================

    return DashboardPage(
      userDecoded: userDecoded,
      sessionId: sessionId,
    );
  }
}