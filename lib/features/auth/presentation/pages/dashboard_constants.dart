import 'package:flutter/material.dart';

class DashboardConstants {
  static const Color brandBlue = Color(
    0xFF2300C4,
  );
  static const Color bg = Color(0xFFF6F7FB);

  static const double radiusLg = 26;
  static const double radiusCard = 16;

  static String monthLabel(int i) {
    const labels = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    if (i < 0 || i >= labels.length) return "";
    return labels[i];
  }
}


//ALTER PROCEDURE [dbo].[APPGEtAllocation]
