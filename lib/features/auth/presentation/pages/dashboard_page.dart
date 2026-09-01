import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/features/auth/presentation/pages/settings_page.dart';
import 'package:suitapps/features/auth/presentation/pages/profile_page.dart';
import 'package:suitapps/features/auth/presentation/pages/login_page.dart';
import 'package:suitapps/shared/widgets/common_bottom_nav.dart';
import 'package:suitapps/shared/widgets/expandable_fab.dart';
import 'package:suitapps/shared/extensions/responsive.dart';
import 'package:suitapps/features/auth/data/repositories/session_timeout_service.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';
import 'package:suitapps/features/auth/presentation/widgets/dashboard_header.dart';
import 'package:suitapps/features/auth/presentation/widgets/overview_cards.dart';
import 'package:suitapps/features/auth/presentation/widgets/sales_orders_chart.dart';
import 'package:suitapps/features/auth/presentation/widgets/dashboard_segments.dart';
import 'package:suitapps/features/auth/presentation/widgets/activity_timeline.dart';
import 'package:suitapps/shared/widgets/app_drawer.dart';
import 'package:suitapps/features/customer/presentation/pages/customer_create_page.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> userDecoded;
  final String sessionId;

  const DashboardPage({
    super.key,
    required this.userDecoded,
    required this.sessionId,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final SessionTimeoutService sessionService = SessionTimeoutService();

  int _bottomIndex = 0;
  int _segmentIndex = 0;

  String _name = "User";
  String? _profileUrl;

  final _orderHistory = const [
    TimelineItemData(
      title: "Order Placed",
      time: "Wed, 23 Dec 2024 20:12 PM",
      showProfile: true,
      name: "Emily Johnson",
      email: "emilyjohnson@example.com",
    ),
    TimelineItemData(title: "Order Placed", time: "Wed, 23 Dec 2024 21:56 PM"),
    TimelineItemData(title: "Order Placed", time: "Wed, 23 Dec 2024 23:59 PM"),
  ];

  final _salesHistory = const [
    TimelineItemData(
      title: "Sale Completed",
      time: "Wed, 23 Dec 2024 11:10 AM",
    ),
    TimelineItemData(
      title: "Sale Completed",
      time: "Wed, 23 Dec 2024 12:05 PM",
    ),
    TimelineItemData(title: "Sale Refunded", time: "Wed, 23 Dec 2024 01:40 PM"),
  ];

  final _paymentCollection = const [
    TimelineItemData(
      title: "Payment Received",
      time: "Wed, 23 Dec 2024 02:15 PM",
    ),
    TimelineItemData(
      title: "Payment Pending",
      time: "Wed, 23 Dec 2024 03:10 PM",
    ),
  ];

  final _invoiceHistory = const [
    TimelineItemData(
      title: "Invoice Created",
      time: "Wed, 23 Dec 2024 04:20 PM",
    ),
    TimelineItemData(title: "Invoice Sent", time: "Wed, 23 Dec 2024 04:45 PM"),
    TimelineItemData(title: "Invoice Paid", time: "Wed, 23 Dec 2024 06:00 PM"),
  ];

  List<TimelineItemData> get _currentTimeline {
    switch (_segmentIndex) {
      case 0:
        return _orderHistory;
      case 1:
        return _salesHistory;
      case 2:
        return _paymentCollection;
      case 3:
        return _invoiceHistory;
      default:
        return _orderHistory;
    }
  }

  // @override
  // void initState() {
  //   super.initState();

  //   final name = (widget.userDecoded['Name'] ?? '').toString().trim();
  //   _name = name.isEmpty ? "User" : name;

  //   final p = (widget.userDecoded['ProfileImage'] ?? '').toString().trim();
  //   _profileUrl = p.isEmpty ? null : p;

  //   _hydrateFromPrefs();
  // }
  @override
  void initState() {
    super.initState();

    // auto logout at 12:00 AM
    sessionService.start(context);

    final name = (widget.userDecoded['Name'] ?? '').toString().trim();
    _name = name.isEmpty ? "User" : name;

    final p = (widget.userDecoded['ProfileImage'] ?? '').toString().trim();
    _profileUrl = p.isEmpty ? null : p;

    _hydrateFromPrefs();
  }

  Future<void> _hydrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final name = (prefs.getString('Name') ?? '').trim();
      final userJson = (prefs.getString('user') ?? '').trim();

      String? profile;
      if (userJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(userJson);
          if (decoded is Map<String, dynamic>) {
            final p = (decoded['ProfileImage'] ?? '').toString().trim();
            profile = p.isEmpty ? null : p;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _name = name.isEmpty ? _name : name;
        _profileUrl = profile ?? _profileUrl;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    sessionService.stop();

    super.dispose();
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    int hour = dt.hour;
    final ampm = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return "${dt.day} ${months[dt.month - 1]} ${dt.year}, "
        "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDateTime(DateTime.now());
    const appLogoForHeaderFallback = "assets/icon/sp-logo.png";

    final double outerRadius = Responsive.radius(context, 32);

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        profileUrl: _profileUrl,
        onLogout: () => _logout(context),
      ),
      backgroundColor: DashboardConstants.bg,
      // floatingActionButton: const ExpandableFab(),
      // floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // floatingActionButton: Padding(
      //   padding: EdgeInsets.only(bottom: Responsive.pad(context, 70)),
      //   child: const ExpandableFab(),
      // ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: Responsive.pad(context, 90)),
        child: ExpandableFab(
          onCustomerTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerDashboardPage()),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.fromLTRB(
                    Responsive.pad(context, 8),
                    Responsive.pad(context, 8),
                    Responsive.pad(context, 8),
                    Responsive.pad(context, 6),
                  ),
                  decoration: BoxDecoration(
                    color: DashboardConstants.brandBlue,
                    borderRadius: BorderRadius.circular(outerRadius),
                  ),
                  child: Column(
                    children: [
                      DashboardHeader(
                        name: _name,
                        dateText: dateText,
                        profileImageUrl: _profileUrl,
                        profileImageAssetPath: appLogoForHeaderFallback,
                        onMenuTap: _openDrawer,

                        // âœ… THIS IS THE IMPORTANT PART:
                        onProfileTap: _openProfile,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          Responsive.pad(context, 8),
                          Responsive.pad(context, 8),
                          Responsive.pad(context, 8),
                          Responsive.pad(context, 8),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(Responsive.pad(context, 16)),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              Responsive.radius(context, 28),
                            ),
                          ),
                          child: const OverviewCards(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.pad(context, 14),
                      Responsive.pad(context, 8),
                      Responsive.pad(context, 14),
                      Responsive.pad(context, 120),
                    ),
                    child: Column(
                      children: [
                        const SalesOrdersChart(),
                        SizedBox(height: Responsive.pad(context, 14)),
                        DashboardSegments(
                          selectedIndex: _segmentIndex,
                          onChanged: (i) => setState(() => _segmentIndex = i),
                        ),
                        SizedBox(height: Responsive.pad(context, 14)),
                        ActivityTimeline(items: _currentTimeline),
                        SizedBox(height: Responsive.pad(context, 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: CommonBottomNav(
              index: _bottomIndex,
              onChanged: (i) => setState(() => _bottomIndex = i),
              activeColor: DashboardConstants.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}
