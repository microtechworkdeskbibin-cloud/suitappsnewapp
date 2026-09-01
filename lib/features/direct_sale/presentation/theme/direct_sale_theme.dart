import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DsColors {
  static const Color primary = Color(0xFF0B6B4C);
  static const Color primaryDark = Color(0xFF0A5C41);
  static const Color primaryLight = Color(0xFFE3F3EC);

  static const Color background = Color(0xFFF4F6F8);
  static const Color cardBg = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color border = Color(0xFFE5E7EB);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
}

class DsFonts {
  static TextStyle pageTitle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle pageSubtitle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.white70,
  );

  static TextStyle sectionTitle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: DsColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: DsColors.textPrimary,
  );

  static TextStyle bodyBold = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: DsColors.textPrimary,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: DsColors.textSecondary,
  );

  static TextStyle smallText = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: DsColors.textSecondary,
  );
}

class DsSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class DsRadius {
  static const double card = 14;
  static const double button = 10;
  static const double chip = 20;
  static const double sheet = 20;
}
