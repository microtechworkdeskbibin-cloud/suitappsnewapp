import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';
import 'package:suitapps/shared/extensions/ui_helpers.dart'; // EllipsizeText, FitText

// class OverviewCards extends StatelessWidget {
//   const OverviewCards({super.key});

//   @override
//   Widget build(BuildContext context) {
class OverviewCards extends StatefulWidget {
  const OverviewCards({super.key});
  @override
  State<OverviewCards> createState() => _OverviewCardsState();
}

class _OverviewCardsState extends State<OverviewCards> {
  Map<String, dynamic>? summaryData;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  String _firstVal(
    Map<String, dynamic>? m,
    List<String> keys,
    String fallback,
  ) {
    if (m == null) return fallback;
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k].toString();
    }
    return fallback;
  }

  Future<void> _loadSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserId')?.toString() ?? '';
      final roleId = prefs.getInt('UserRoleId')?.toString() ?? '';
      final companyId =
          prefs.getString('CompanyID') ??
          prefs.getString('SelectedCompanyId') ??
          '';

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      print("Prefs UserId = $userId");
      print("Prefs RoleId = $roleId");
      print("Prefs CompanyId = $companyId");

      final url =
          '${ApiConfig.baseUrl}/GetSaleSummary?TodayDate=$today&UserID=$userId&UserRoleid=$roleId&CompanyId=$companyId';
      print('========== DASHBOARD API ==========');
      print('UserID: $userId');
      print('RoleID: $roleId');
      print('CompanyID: $companyId');
      print('URL: $url');

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);

        print('Status Code: ${res.statusCode}');
        print('Response Body: ${res.body}');

        Map<String, dynamic>? data;

        if (decoded is List && decoded.isNotEmpty) {
          data = Map<String, dynamic>.from(decoded.first);
          print('SummaryData = $data');
        }

        if (!mounted) return;

        setState(() {
          summaryData = data;
          loading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Parent scaling only for gaps / heading (not the card contents)
        final parentUi = _ParentUi(constraints);

        final headingSize = parentUi.font(16);
        final headingBottom = parentUi.pad(8);
        final rowGap = parentUi.pad(8);
        final colGap = parentUi.pad(8);

        // âœ… ALWAYS 2 columns (2 x 2 arrangement)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: headingBottom),
              child: Text(
                "Overview",
                style: TextStyle(
                  fontSize: headingSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),

            // Row 1
            Row(
              children: [
                Expanded(
                  child: _TotalOrderCard(
                    total: _firstVal(summaryData, ['TodayBillCount'], '0'),
                    percent: '0%',
                    isUp: true,
                    yesterday: _firstVal(summaryData, [
                      'YesterdayBillCount',
                    ], '0'),
                  ),
                ),
                SizedBox(width: colGap),
                Expanded(
                  child: _WhiteInfoCard(
                    title: "Total Sales",
                    value: _firstVal(summaryData, ['TodayBillAmount'], '0'),
                    percent: '0%',
                    isUp: true,
                    yesterday: _firstVal(summaryData, [
                      'YesterdayBillAmount',
                    ], '0'),
                    icon: Icons.currency_rupee_rounded,
                  ),
                ),
              ],
            ),

            SizedBox(height: rowGap),

            // Row 2
            Row(
              children: [
                Expanded(
                  child: _WhiteInfoCard(
                    title: "Payment Collected",
                    value: _firstVal(summaryData, ['TodayReceiptAmount'], '0'),
                    percent: '0%',
                    isUp: true,
                    yesterday: _firstVal(summaryData, [
                      'YesterdayReceiptAmount',
                    ], '0'),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                SizedBox(width: colGap),
                Expanded(
                  child: _WhiteInfoCard(
                    title: "Open Invoice",
                    value: _firstVal(summaryData, [
                      'TodayOpenInvoiceAmount',
                    ], '0'),
                    percent: '0%',
                    isUp: true,
                    yesterday: _firstVal(summaryData, [
                      'YesterdayOpenInvoiceAmount',
                    ], '0'),
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/* ------------------------------------------------------------ */
/* âœ… Parent UI scaler (just for heading + gaps)                  */
/* ------------------------------------------------------------ */
class _ParentUi {
  _ParentUi(this.c) {
    final w = c.maxWidth;
    s = (w / 390.0).clamp(0.85, 1.15);
  }
  final BoxConstraints c;
  late final double s;

  double pad(double v) => v * s;
  double font(double v) => (v * (0.6 + 0.4 * s)).clamp(v * 0.9, v * 1.1);
}

/* ------------------------------------------------------------ */
/* âœ… Card UI scaler (based on *card width*)                      */
/* ------------------------------------------------------------ */
class _CardUi {
  _CardUi(this.c) {
    final w = c.maxWidth;

    // When 2 columns on phones, card width is often 160~200.
    // Scale from a "comfortable card width" baseline.
    final base = 200.0;

    // Clamp hard so tiny cards still look ok.
    s = (w / base).clamp(0.78, 1.05);

    // Extra squeeze for very narrow cards
    tight = w < 175;
  }

  final BoxConstraints c;
  late final double s;
  late final bool tight;

  double pad(double v) => (v * s).clamp(v * 0.75, v);
  double size(double v) => v * s;
  double radius(double v) => v * s;

  double font(double v) {
    // Damp fonts a bit more than padding
    final f = v * (0.65 + 0.35 * s);
    return f.clamp(v * 0.78, v * 1.02);
  }
}

/* ------------------------------------------------------------ */
/* ðŸ”µ TOTAL ORDER CARD (2-column safe)                            */
/* ------------------------------------------------------------ */
class _TotalOrderCard extends StatelessWidget {
  const _TotalOrderCard({
    required this.total,
    required this.percent,
    required this.isUp,
    required this.yesterday,
  });

  final String total;
  final String percent;
  final bool isUp;
  final String yesterday;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ui = _CardUi(constraints);

        final double minH = ui.size(ui.tight ? 96.0 : 110.0);
        final double pad = ui.pad(ui.tight ? 8.0 : 10.0);
        final double radius = ui.radius(16.0);

        final double titleSize = ui.font(ui.tight ? 11.5 : 12.5);
        final double valueSize = ui.font(ui.tight ? 18.0 : 20.0);
        final double smallSize = ui.font(10.0);

        final double shadowBlur = ui.size(10.0);
        final double shadowY = ui.size(4.0);

        return Container(
          constraints: BoxConstraints(minHeight: minH),
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF1433C3), Color(0xFF6F7FDB)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: shadowBlur,
                offset: Offset(0, shadowY),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TITLE + ICON
              Row(
                children: [
                  Expanded(
                    child: EllipsizeText(
                      "Total Order",
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: ui.pad(6)),
                  _RoundIcon(
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFF1433C3),
                    bgColor: Colors.white,
                    box: ui.size(ui.tight ? 26.0 : 30.0),
                    iconSize: ui.size(ui.tight ? 14.0 : 16.0),
                  ),
                ],
              ),

              SizedBox(height: ui.pad(6)),

              // VALUE + PERCENT (âœ… overflow-safe)
              Row(
                children: [
                  Expanded(
                    child: FitText(
                      total,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: valueSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: ui.pad(4)),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _PercentPill(
                          text: percent,
                          up: isUp,
                          dark: true,
                          ui: ui,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: ui.pad(4)),

              Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: smallSize,
                      ),
                      children: [
                        const TextSpan(
                          text: "Yesterday ",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextSpan(
                          text: yesterday,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ------------------------------------------------------------ */
/* âšª WHITE INFO CARD (2-column safe)                              */
/* ------------------------------------------------------------ */
class _WhiteInfoCard extends StatelessWidget {
  const _WhiteInfoCard({
    required this.title,
    required this.value,
    required this.percent,
    required this.isUp,
    required this.yesterday,
    required this.icon,
  });

  final String title;
  final String value;
  final String percent;
  final bool isUp;
  final String yesterday;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ui = _CardUi(constraints);

        final double minH = ui.size(ui.tight ? 96.0 : 110.0);
        final double pad = ui.pad(ui.tight ? 8.0 : 10.0);
        final double radius = ui.radius(16.0);

        final double titleSize = ui.font(ui.tight ? 11.0 : 12.0);
        final double valueSize = ui.font(ui.tight ? 18.0 : 20.0);
        final double smallSize = ui.font(10.0);

        final double shadowBlur = ui.size(8.0);
        final double shadowY = ui.size(4.0);

        return Container(
          constraints: BoxConstraints(minHeight: minH),
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: shadowBlur,
                offset: Offset(0, shadowY),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TITLE + ICON
              Row(
                children: [
                  Expanded(
                    child: EllipsizeText(
                      title,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: ui.pad(6)),
                  _RoundIcon(
                    icon: icon,
                    iconColor: DashboardConstants.brandBlue,
                    bgColor: DashboardConstants.brandBlue.withValues(alpha: 0.12),
                    box: ui.size(ui.tight ? 26.0 : 30.0),
                    iconSize: ui.size(ui.tight ? 14.0 : 16.0),
                  ),
                ],
              ),

              SizedBox(height: ui.pad(6)),

              // VALUE + PERCENT (âœ… overflow-safe)
              Row(
                children: [
                  Expanded(
                    child: FitText(
                      value,
                      style: TextStyle(
                        fontSize: valueSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: ui.pad(4)),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _PercentPill(
                          text: percent,
                          up: isUp,
                          dark: false,
                          ui: ui,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: ui.pad(4)),

              Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: smallSize,
                        color: Colors.black54,
                      ),
                      children: [
                        const TextSpan(
                          text: "Yesterday ",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextSpan(
                          text: yesterday,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ------------------------------------------------------------ */
/* ðŸ”˜ ROUND ICON                                                  */
/* ------------------------------------------------------------ */
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.box,
    required this.iconSize,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final double box;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

/* ------------------------------------------------------------ */
/* ðŸ“ˆ PERCENT PILL                                                */
/* ------------------------------------------------------------ */
class _PercentPill extends StatelessWidget {
  const _PercentPill({
    required this.text,
    required this.up,
    required this.dark,
    required this.ui,
  });

  final String text;
  final bool up;
  final bool dark;
  final _CardUi ui;

  @override
  Widget build(BuildContext context) {
    final color = up ? Colors.green : Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui.pad(ui.tight ? 4.0 : 5.0),
        vertical: ui.pad(2.0),
      ),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.85) : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ui.radius(16.0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: ui.size(ui.tight ? 9.0 : 10.0),
            color: dark ? DashboardConstants.brandBlue : color,
          ),
          SizedBox(width: ui.pad(3.0)),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui.font(10.0),
              fontWeight: FontWeight.w900,
              color: dark ? DashboardConstants.brandBlue : color,
            ),
          ),
        ],
      ),
    );
  }
}
