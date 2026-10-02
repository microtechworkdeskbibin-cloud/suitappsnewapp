import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/shared/widgets/app_drawer.dart';
import 'package:suitapps/shared/widgets/common_bottom_nav.dart';
import 'package:suitapps/shared/widgets/expandable_fab.dart';
import 'package:suitapps/features/auth/presentation/pages/login_page.dart';
import 'package:suitapps/features/auth/presentation/pages/profile_page.dart';
import 'package:suitapps/features/auth/data/repositories/session_timeout_service.dart';
import 'package:suitapps/features/auth/presentation/widgets/dashboard_header.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';

class SalesHeadDashboardPage extends StatefulWidget {
  final Map<String, dynamic> userDecoded;
  final String sessionId;
  const SalesHeadDashboardPage({
    super.key,
    required this.userDecoded,
    required this.sessionId,
  });
  @override
  State<SalesHeadDashboardPage> createState() => _SalesHeadDashboardPageState();
}

class _SalesHeadDashboardPageState extends State<SalesHeadDashboardPage> {
  static const primary = Color(0xFF2300C4),
      blue = Color(0xFF5265E8),
      soft = Color(0xFFEDEEFC);
  static const bg = Color(0xFFF5F7FB),
      text = Color(0xFF15161A),
      sub = Color(0xFF737781);
  static const border = Color(0xFFE4E7EF),
      green = Color(0xFF16A34A),
      orange = Color(0xFFE79A17),
      red = Color(0xFFD64545),
      teal = Color(0xFF0E9F8A);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final SessionTimeoutService sessionService = SessionTimeoutService();
  bool loading = true;
  // Dashboard is fully date-range based.
  // No Today / This Week / This Month / Quarter presets.
  String period = 'Custom';
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  Map<String, dynamic> summary = {};
  List<dynamic> performance = [],
      funnel = [],
      territory = [],
      products = [],
      customers = [],
      inactive = [],
      hierarchy = [];
  Map<String, dynamic> actions = {};

  // Transaction detail lists returned by the dashboard API.
  // Expected keys: orders, bills, receipts.
  List<dynamic> orders = [], bills = [], receipts = [];

  // Day-wise sales & orders trend, one row per calendar date
  // in the selected range. Expected key: dayWiseSalesOrders.
  List<dynamic> dayWise = [];

  // ============================================================
  // TEAM MONITORING DATA
  // ============================================================
  Map<String, dynamic> attendanceSummary = {};
  List<dynamic> salesmanAttendance = [];

  Map<String, dynamic> loginSummary = {};
  List<dynamic> loginDetails = [];

  Map<String, dynamic> leaveSummary = {};
  List<dynamic> leaveDetails = [];

  List<dynamic> workSummary = [];

  Map<String, dynamic> odometerSummary = {};
  List<dynamic> salesmanOdometer = [];

  Map<String, dynamic> visitSummary = {};
  List<dynamic> salesmanVisits = [];

  @override
  void initState() {
    super.initState();
    sessionService.start(context);
    load();
  }

  @override
  void dispose() {
    sessionService.stop();
    super.dispose();
  }

  int n(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  double d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  String s(dynamic v, [String f = '-']) {
    final x = '$v'.trim();
    return x.isEmpty || x == 'null' ? f : x;
  }

  String money(dynamic v) {
    final x = d(v);
    if (x >= 10000000) return '₹${(x / 10000000).toStringAsFixed(2)} Cr';
    if (x >= 100000) return '₹${(x / 100000).toStringAsFixed(2)} L';
    if (x >= 1000) return '₹${(x / 1000).toStringAsFixed(1)} K';
    return '₹${x.toStringAsFixed(0)}';
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final uid = n(widget.userDecoded['UserId']),
          cid = n(widget.userDecoded['CompanyID']);
      if (uid == 0 || cid == 0)
        throw Exception('UserId or CompanyID is missing');
      final uri =
          Uri.parse(
            '${ApiConfig.apiBaseUrl}${ApiConfig.getTSMDashboard}',
          ).replace(
            queryParameters: {
              'UserId': '$uid',
              'CompanyID': '$cid',
              'FromDate': DateFormat('yyyy-MM-dd').format(from),
              'ToDate': DateFormat('yyyy-MM-dd').format(to),
            },
          );
      debugPrint('Dashboard URL: $uri');
      final r = await http.get(uri).timeout(ApiConfig.connectionTimeout);
      debugPrint('Dashboard ${r.statusCode}: ${r.body}');
      if (r.statusCode < 200 || r.statusCode >= 300)
        throw Exception('API Error ${r.statusCode}');
      final j = jsonDecode(r.body);
      if (j['success'] != true)
        throw Exception(s(j['message'], 'Dashboard API failed'));
      final x = Map<String, dynamic>.from(j['data'] ?? {});
      debugPrint('Dashboard data keys: ${x.keys.toList()}');
      final h = await loadHierarchy(uid, cid);
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(x['summary'] ?? {});
        performance = List.from(x['salesmanPerformance'] ?? []);
        funnel = List.from(x['salesFunnel'] ?? []);
        territory = List.from(x['territoryPerformance'] ?? []);
        products = List.from(x['topProducts'] ?? []);
        customers = List.from(x['topCustomers'] ?? []);
        inactive = List.from(x['inactiveCustomers'] ?? []);
        actions = Map<String, dynamic>.from(x['actionRequired'] ?? {});
        orders = List.from(x['orders'] ?? x['orderDetails'] ?? []);
        bills = List.from(x['bills'] ?? x['billDetails'] ?? []);
        receipts = List.from(x['receipts'] ?? x['receiptDetails'] ?? []);
        dayWise = List.from(
          x['dayWiseSalesOrders'] ??
              x['DayWiseSalesOrders'] ??
              x['dailyTrend'] ??
              x['dailySalesOrders'] ??
              x['salesTrend'] ??
              x['trend'] ??
              [],
        );

        // Team monitoring / field-work data
        attendanceSummary = Map<String, dynamic>.from(
          x['attendanceSummary'] ?? {},
        );
        salesmanAttendance = List.from(
          x['salesmanAttendance'] ?? [],
        );

        loginSummary = Map<String, dynamic>.from(
          x['loginSummary'] ?? {},
        );
        loginDetails = List.from(
          x['loginDetails'] ?? [],
        );

        leaveSummary = Map<String, dynamic>.from(
          x['leaveSummary'] ?? {},
        );
        leaveDetails = List.from(
          x['leaveDetails'] ?? [],
        );

        workSummary = List.from(
          x['workSummary'] ?? [],
        );

        odometerSummary = Map<String, dynamic>.from(
          x['odometerSummary'] ?? {},
        );
        salesmanOdometer = List.from(
          x['salesmanOdometer'] ?? [],
        );

        visitSummary = Map<String, dynamic>.from(
          x['visitSummary'] ?? {},
        );
        salesmanVisits = List.from(
          x['salesmanVisits'] ?? [],
        );

        hierarchy = h;
        loading = false;
      });
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load dashboard: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<List<dynamic>> loadHierarchy(int uid, int cid) async {
    try {
      final u = Uri.parse(
        '${ApiConfig.apiBaseUrl}${ApiConfig.getUserHierarchy}',
      ).replace(queryParameters: {'UserId': '$uid', 'CompanyID': '$cid'});
      final r = await http.get(u).timeout(ApiConfig.connectionTimeout);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final j = jsonDecode(r.body);
        if (j['success'] == true) return List.from(j['data'] ?? []);
      }
    } catch (e) {
      debugPrint('Hierarchy error: $e');
    }
    return [];
  }

  Future<void> customDate() async {
    final x = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (x == null) return;
    setState(() {
      period = 'Custom';
      from = x.start;
      to = x.end;
    });
    load();
  }

  // ----------------------------------------------------------------
  // DRILL-DOWN NAVIGATION
  //
  // Tapping a team member re-opens THIS SAME page, but scoped to
  // that member's own UserId. The stored procedure builds the
  // hierarchy from whatever @UserId is passed, so this works for
  // any role (TSM, ASM, Salesman) without needing separate pages -
  // JISSO (TSM) will see their own target/achieved plus whoever
  // reports to them, and their own customer list.
  //
  // CompanyID, SessionId, and anything else in the original
  // userDecoded is preserved; only the identity fields are swapped
  // out for the tapped member.
  // ----------------------------------------------------------------

  void _openMemberDashboard(Map<String, dynamic> member) {
    final tappedUserId = n(member['UserId']);
    if (tappedUserId == 0) return;

    // Don't push a new copy of the same user's own dashboard.
    if (tappedUserId == n(widget.userDecoded['UserId'])) return;

    final drillUserDecoded = {
      ...widget.userDecoded,
      'UserId': tappedUserId,
      'Name': member['UserName'] ?? member['Name'],
      'UserName': member['UserName'] ?? member['Name'],
      'UserRoleId': member['UserRoleId'],
      'RoleName': member['RoleName'],
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesHeadDashboardPage(
          userDecoded: drillUserDecoded,
          sessionId: widget.sessionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: DashboardConstants.bg,
      drawer: AppDrawer(
        profileUrl: _profile(),
        onLogout: () => logout(context),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 82),
        child: ExpandableFab(onCustomerTap: () {}),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(color: primary),
                        )
                      : RefreshIndicator(
                          color: primary,
                          onRefresh: load,
                          child: body(),
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

  int _bottomIndex = 0;

  String? _profile() {
    final x = widget.userDecoded['ProfileImage'] ?? widget.userDecoded['IMAGE'];
    return x == null || '$x'.trim().isEmpty ? null : '$x';
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  Widget _buildHeader() {
    final dateText = DateFormat('d MMMM yyyy, hh:mm a').format(DateTime.now());

    final name = s(
      widget.userDecoded['Name'] ?? widget.userDecoded['UserName'],
      'Sales Head',
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: DashboardConstants.brandBlue,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          DashboardHeader(
            name: name,
            dateText: dateText,
            profileImageUrl: _profile(),
            profileImageAssetPath: 'assets/icon/sp-logo.png',
            onMenuTap: _openDrawer,
            onProfileTap: _openProfile,
          ),
        ],
      ),
    );
  }

  Widget body() {
    // Dynamic title: "Sales Head Dashboard" at the top of the
    // tree, or "<Role> Dashboard" (e.g. "TSM Dashboard") once
    // drilled into a specific member.
    final roleName = s(widget.userDecoded['RoleName'], '');
    final dashboardTitle = roleName.isEmpty || roleName == '-'
        ? 'Sales Head Dashboard'
        : '$roleName Dashboard';

    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 30),
      children: [
        periodFilter(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                dashboardTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '${DateFormat('dd MMM').format(from)} - ${DateFormat('dd MMM yyyy').format(to)}',
                style: const TextStyle(
                  color: primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        targetCard(),
        const SizedBox(height: 14),
        kpis(),
        const SizedBox(height: 14),
        dailyOrderSaleCountChart(),
        const SizedBox(height: 14),
        dailySalesChart(),
        const SizedBox(height: 14),
        team(),
        const SizedBox(height: 14),
        teamChart(),
        const SizedBox(height: 14),
        funnelCard(),
        const SizedBox(height: 14),
        territoryCard(),
        const SizedBox(height: 14),
        customersCard(),
        const SizedBox(height: 14),
        inactiveCard(),
        const SizedBox(height: 14),
        productsCard(),
        const SizedBox(height: 14),
        actionsCard(),
        const SizedBox(height: 14),
        teamMonitoringCard(),
        const SizedBox(height: 14),
        salesmanAttendanceCard(),
        const SizedBox(height: 14),
        loginMonitoringCard(),
        const SizedBox(height: 14),
        leaveMonitoringCard(),
        const SizedBox(height: 14),
        workSummaryCard(),
        const SizedBox(height: 14),
        odometerCard(),
        const SizedBox(height: 14),
        shopVisitCard(),
        const SizedBox(height: 14),
        hierarchyCard(),
      ],
    );
  }

  Widget periodFilter() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.calendar_month_rounded, color: primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: customDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATE RANGE',
                    style: TextStyle(
                      color: sub,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(from)} - '
                    '${DateFormat('dd MMM yyyy').format(to)}',
                    style: const TextStyle(
                      color: text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: customDate,
          tooltip: 'Select date range',
          icon: const Icon(Icons.edit_calendar_rounded, color: primary),
        ),
      ],
    ),
  );

  Widget targetCard() {
    final t = d(summary['SalesTarget']),
        a = d(summary['SalesAchieved']),
        api = d(summary['AchievementPercentage']);
    final p = t > 0 ? a / t * 100 : api;
    final progress = t > 0 ? (a / t).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primary, blue]),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Color(0x332300C4),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SALES TARGET VS ACHIEVED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${p.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: amount('TARGET', money(t))),
              Container(width: 1, height: 48, color: Colors.white24),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: amount('ACHIEVED', money(a)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 11,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Achieved ${money(a)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Target ${money(t)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget amount(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
  Widget kpis() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 11,
    mainAxisSpacing: 11,
    childAspectRatio: 1.55,
    children: [
      kpi(
        'Period Sales',
        money(
          summary['PeriodSales'] ??
              summary['TodaySales'] ??
              summary['SalesAchieved'],
        ),
        Icons.calendar_today_rounded,
        primary,
        onTap: () => _showDetails('sales', 'Period Sales'),
      ),
      kpi(
        'Orders',
        '${n(summary['Orders'])}',
        Icons.receipt_long_rounded,
        teal,
        amount: money(summary['OrderAmount'] ?? summary['Pipeline']),
        onTap: () => _showDetails('orders', 'Orders'),
      ),
      kpi(
        'Bills',
        '${n(summary['Bills'] ?? summary['BillCount'])}',
        Icons.description_rounded,
        blue,
        amount: money(summary['BillAmount']),
        onTap: () => _showDetails('bills', 'Bills'),
      ),
      kpi(
        'Receipts',
        '${n(summary['Receipts'] ?? summary['ReceiptCount'])}',
        Icons.payments_rounded,
        green,
        amount: money(summary['ReceiptAmount']),
        onTap: () => _showDetails('receipts', 'Receipts'),
      ),
      kpi(
        'Active Customers',
        '${n(summary['ActiveCustomers'])}',
        Icons.groups_rounded,
        blue,
      ),
      kpi(
        'Pipeline',
        money(summary['Pipeline']),
        Icons.trending_up_rounded,
        orange,
      ),
      kpi(
        'Outstanding',
        money(summary['Outstanding']),
        Icons.account_balance_wallet_rounded,
        red,
      ),
      kpi(
        'Achievement',
        '${d(summary['AchievementPercentage']).toStringAsFixed(0)}%',
        Icons.emoji_events_rounded,
        green,
      ),
    ],
  );

  Widget kpi(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? amount,
    VoidCallback? onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: sub,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    amount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: sub, size: 18),
        ],
      ),
    ),
  );

  Future<void> _showDetails(String type, String title) async {
    List<dynamic> data;
    switch (type) {
      case 'orders':
        data = orders;
        break;
      case 'bills':
        data = bills;
        break;
      case 'receipts':
        data = receipts;
        break;
      default:
        data = [];
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _detailSheet(type, title, data),
    );
  }

  Widget _detailSheet(String type, String title, List<dynamic> data) {
    double total = 0;
    for (final x in data) {
      total += d(
        x['Amount'] ??
            x['OrderAmount'] ??
            x['BillAmount'] ??
            x['ReceiptAmount'] ??
            x['TotAmo'] ??
            x['NetAmount'],
      );
    }

    final summaryAmount = type == 'orders'
        ? d(summary['OrderAmount'] ?? summary['Pipeline'])
        : type == 'bills'
        ? d(summary['BillAmount'])
        : d(summary['ReceiptAmount']);

    if (data.isEmpty) total = summaryAmount;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * .82,
        decoration: const BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      type == 'orders'
                          ? Icons.receipt_long_rounded
                          : type == 'bills'
                          ? Icons.description_rounded
                          : Icons.payments_rounded,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('dd MMM yyyy').format(from)} - ${DateFormat('dd MMM yyyy').format(to)}',
                          style: const TextStyle(
                            color: sub,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _detailSummary(
                      'COUNT',
                      '${data.isEmpty ? _detailCount(type) : data.length}',
                    ),
                  ),
                  Container(width: 1, height: 35, color: border),
                  Expanded(child: _detailSummary('AMOUNT', money(total))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: data.isEmpty
                  ? _empty(message: 'No detail records available from API')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _transactionRow(type, data[i], i + 1),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _detailCount(String type) {
    if (type == 'orders') return '${n(summary['Orders'])}';
    if (type == 'bills')
      return '${n(summary['Bills'] ?? summary['BillCount'])}';
    return '${n(summary['Receipts'] ?? summary['ReceiptCount'])}';
  }

  Widget _detailSummary(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: sub,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );

  Widget _transactionRow(String type, dynamic raw, int index) {
    final x = Map<String, dynamic>.from(raw as Map);
    final name = s(
      x['CustomerName'] ?? x['PartyName'] ?? x['AccountName'] ?? x['Name'],
      'Customer',
    );
    final number = s(
      x['BillNo'] ??
          x['InvoiceNo'] ??
          x['OrderNo'] ??
          x['OrderNumber'] ??
          x['Slno'] ??
          x['ID'],
      '#$index',
    );
    final date = s(
      x['Date'] ?? x['BillDate'] ?? x['OrderDate'] ?? x['RDate'],
      '',
    );
    final amount = d(
      x['Amount'] ??
          x['OrderAmount'] ??
          x['BillAmount'] ??
          x['ReceiptAmount'] ??
          x['TotAmo'] ??
          x['NetAmount'],
    );

    final icon = type == 'orders'
        ? Icons.receipt_long_rounded
        : type == 'bills'
        ? Icons.description_rounded
        : Icons.payments_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$number${date.isEmpty ? '' : ' • $date'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: sub,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            money(amount),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TEAM PERFORMANCE
  //
  // Each row is now wrapped in InkWell -> tapping a member opens
  // their own dashboard (see _openMemberDashboard above).
  // ------------------------------------------------------------

  Widget team() => card(
    'TEAM PERFORMANCE',
    Icons.groups_rounded,
    'View all',
    performance.isEmpty
        ? _empty()
        : Column(
            children: performance.take(8).map((x) {
              final name = s(x['UserName'] ?? x['Name'], 'User'),
                  role = s(x['RoleName'], ''),
                  t = d(x['SalesTarget']),
                  a = d(x['SalesAchieved']),
                  orderAmount = d(x['OrderAmount']),
                  orders = n(x['Orders']),
                  p = t > 0 ? a / t * 100 : d(x['AchievementPercentage']);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openMemberDashboard(x),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          avatar(name),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  role.isEmpty
                                      ? '$orders orders'
                                      : '$role • $orders orders',
                                  style: const TextStyle(
                                    color: sub,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Target ${money(t)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: sub,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Achieved ${money(a)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: sub,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        money(orderAmount),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Order Amount',
                                        style: TextStyle(
                                          color: sub,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 7),
                                  percent(p),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: sub,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: t > 0 ? (a / t).clamp(0.0, 1.0) : 0,
                        minHeight: 6,
                        backgroundColor: soft,
                        valueColor: AlwaysStoppedAnimation(_pc(p)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
    () => {},
  );

  // ------------------------------------------------------------
  // TEAM PERFORMANCE COMPARISON CHART
  //
  // Bar chart of each team member's Achievement % (Achieved /
  // Target * 100), color coded the same way as the list rows
  // (green >= 80%, orange >= 60%, red below). Tapping a bar shows
  // the member's name and exact percentage as a tooltip.
  // ------------------------------------------------------------

  Widget teamChart() {
    final members = performance.take(8).toList();
    if (members.isEmpty) {
      return card(
        'TEAM PERFORMANCE COMPARISON',
        Icons.bar_chart_rounded,
        '',
        _empty(),
        () => {},
      );
    }

    final bars = <BarChartGroupData>[];
    for (int i = 0; i < members.length; i++) {
      final x = members[i];
      final t = d(x['SalesTarget']);
      final a = d(x['SalesAchieved']);
      final p = t > 0 ? (a / t * 100) : d(x['AchievementPercentage']);
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: p.clamp(0, 150),
              color: _pc(p),
              width: 18,
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 100,
                color: soft,
              ),
            ),
          ],
        ),
      );
    }

    return card(
      'TEAM PERFORMANCE COMPARISON',
      Icons.bar_chart_rounded,
      '',
      SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: 120,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final name = s(
                    members[group.x.toInt()]['UserName'] ??
                        members[group.x.toInt()]['Name'],
                    'User',
                  );
                  return BarTooltipItem(
                    '$name\n${rod.toY.toStringAsFixed(0)}%',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 20,
                  getTitlesWidget: (v, meta) => Text(
                    '${v.toInt()}%',
                    style: const TextStyle(
                      color: sub,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= members.length) {
                      return const SizedBox.shrink();
                    }
                    final name = s(
                      members[i]['UserName'] ?? members[i]['Name'],
                      'User',
                    );
                    final label = name.length > 6 ? name.substring(0, 6) : name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: sub,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: bars,
          ),
        ),
      ),
      () => {},
    );
  }

  // ------------------------------------------------------------
  // SHARED LEGEND DOT
  // ------------------------------------------------------------

  Widget legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          color: sub,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  // ------------------------------------------------------------
  // DAY-WISE ORDER & SALE COUNT
  //
  // Grouped bars per day: Orders (teal) vs Sales/Bills (blue).
  // Tapping a bar shows the count plus the corresponding
  // rupee amount for that day (Order Amount / Sales Amount).
  //
  // Axis labels are skipped manually by index (not by interval)
  // so long date ranges never overlap, and the max-Y is rounded
  // to a clean multiple of 5 so the grid never shows a duplicate
  // top label.
  // ------------------------------------------------------------

  Widget dailyOrderSaleCountChart() {
    if (dayWise.isEmpty) {
      return card(
        'DAY-WISE ORDER & SALE COUNT',
        Icons.bar_chart_rounded,
        '',
        _empty(message: 'No day-wise data available from API'),
        () => {},
      );
    }

    final rows = dayWise
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final dates = <DateTime>[];
    final orderAmounts = <double>[];
    final saleAmounts = <double>[];
    final bars = <BarChartGroupData>[];
    int maxCount = 0;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final dt = DateTime.tryParse(s(r['TrendDate'], '')) ?? DateTime.now();
      final oc = n(r['OrderCount']);
      final sc = n(r['SaleCount'] ?? r['BillCount']);
      dates.add(dt);
      orderAmounts.add(d(r['OrderAmount']));
      saleAmounts.add(d(r['SalesAmount']));
      if (oc > maxCount) maxCount = oc;
      if (sc > maxCount) maxCount = sc;

      bars.add(
        BarChartGroupData(
          x: i,
          barsSpace: 3,
          barRods: [
            BarChartRodData(
              toY: oc.toDouble(),
              color: teal,
              width: 7,
              borderRadius: BorderRadius.circular(3),
            ),
            BarChartRodData(
              toY: sc.toDouble(),
              color: blue,
              width: 7,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }

    // Round the axis max up to a clean multiple of 5 so grid
    // labels never duplicate near the top.
    final niceMax = maxCount == 0 ? 5 : (((maxCount * 1.2) / 5).ceil() * 5);
    final interval = (niceMax / 5).clamp(1, double.infinity).toDouble();

    // Only draw every Nth date label so long ranges never overlap.
    final labelStep = (rows.length / 6).ceil().clamp(1, rows.length);

    return card(
      'DAY-WISE ORDER & SALE COUNT',
      Icons.bar_chart_rounded,
      '',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              legendDot(teal, 'Orders'),
              const SizedBox(width: 14),
              legendDot(blue, 'Sales'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: niceMax.toDouble(),
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final i = group.x.toInt();
                      final dateLabel = DateFormat('d MMM').format(dates[i]);
                      final isOrder = rodIndex == 0;
                      final label = isOrder ? 'Orders' : 'Sales';
                      final amount =
                          isOrder ? orderAmounts[i] : saleAmounts[i];
                      return BarTooltipItem(
                        '$dateLabel\n$label: ${rod.toY.toInt()}\n${money(amount)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: interval,
                      getTitlesWidget: (v, meta) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                          color: sub,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        // Manual skip — only draw every Nth label so
                        // dates never overlap regardless of range length.
                        if (i < 0 ||
                            i >= dates.length ||
                            i % labelStep != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('d MMM').format(dates[i]),
                            style: const TextStyle(
                              color: sub,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: bars,
              ),
            ),
          ),
        ],
      ),
      () => {},
    );
  }

  // ------------------------------------------------------------
  // DAY-WISE SALES AMOUNT
  // ------------------------------------------------------------

  Widget dailySalesChart() {
    if (dayWise.isEmpty) {
      return card(
        'DAY-WISE SALES & ORDERS',
        Icons.show_chart_rounded,
        '',
        _empty(message: 'No day-wise transaction data available from API'),
        () => {},
      );
    }

    final rows = dayWise
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final dates = <DateTime>[];
    final salesSpots = <FlSpot>[];
    final orderSpots = <FlSpot>[];
    double maxSales = 0;
    int maxOrders = 0;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final dt = DateTime.tryParse(s(r['TrendDate'], '')) ?? DateTime.now();
      final sv = d(r['SalesAmount']);
      final ov = n(r['OrderCount']);
      dates.add(dt);
      salesSpots.add(FlSpot(i.toDouble(), sv));
      orderSpots.add(FlSpot(i.toDouble(), ov.toDouble()));
      if (sv > maxSales) maxSales = sv;
      if (ov > maxOrders) maxOrders = ov;
    }

    final scale = (maxOrders > 0 && maxSales > 0) ? maxSales / maxOrders : 1.0;
    final scaledOrderSpots = orderSpots
        .map((p) => FlSpot(p.x, p.y * scale))
        .toList();

    final labelStep = (rows.length / 6).ceil().clamp(1, rows.length);

    return card(
      'DAY-WISE SALES & ORDERS',
      Icons.show_chart_rounded,
      '',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              legendDot(primary, 'Sales Amount'),
              const SizedBox(width: 14),
              legendDot(teal, 'Orders'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (rows.length - 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxSales > 0 ? maxSales / 4 : 1,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final i = spot.x.toInt();
                        final dateLabel = DateFormat('d MMM').format(dates[i]);
                        if (spot.barIndex == 0) {
                          return LineTooltipItem(
                            '$dateLabel\n${money(salesSpots[i].y)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          );
                        }
                        return LineTooltipItem(
                          '$dateLabel\n${orderSpots[i].y.toInt()} orders',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, meta) => Text(
                        money(v),
                        style: const TextStyle(
                          color: sub,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: labelStep.toDouble(),
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= dates.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('d MMM').format(dates[i]),
                            style: const TextStyle(
                              color: sub,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: salesSpots,
                    isCurved: true,
                    color: primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0x1A2300C4),
                    ),
                  ),
                  LineChartBarData(
                    spots: scaledOrderSpots,
                    isCurved: true,
                    color: teal,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      () => {},
    );
  }

  Widget avatar(String name) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: soft, shape: BoxShape.circle),
    child: Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: const TextStyle(color: primary, fontWeight: FontWeight.w900),
    ),
  );
  Widget percent(double p) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(
      color: _pc(p).withOpacity(.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '${p.toStringAsFixed(0)}%',
      style: TextStyle(
        color: _pc(p),
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
  Color _pc(double p) => p >= 80
      ? green
      : p >= 60
      ? orange
      : red;

  Widget funnelCard() => card(
    'SALES FUNNEL',
    Icons.filter_alt_rounded,
    'Details',
    funnel.isEmpty
        ? _empty()
        : Row(
            children: funnel.take(4).map((x) {
              final stage = s(
                    x['FunnelStage'] ?? x['Stage'] ?? x['Name'],
                    'Stage',
                  ),
                  count = n(x['TotalCount'] ?? x['Count'] ?? x['Value']);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$count',
                        style: const TextStyle(
                          color: primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stage,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: sub,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
    () => {},
  );
  Widget territoryCard() => card(
    'TERRITORY PERFORMANCE',
    Icons.location_on_rounded,
    'View all',
    territory.isEmpty
        ? _empty()
        : Column(
            children: territory
                .take(8)
                .map(
                  (x) => listRow(
                    Icons.location_on_rounded,
                    s(x['ZoneName'], 'Unassigned Zone'),
                    '${n(x['Salesmen'])} salesmen • ${n(x['InvoiceCount'])} invoices',
                    money(x['SalesAchieved']),
                  ),
                )
                .toList(),
          ),
    () => {},
  );
  Widget customersCard() => card(
    'TOP CUSTOMERS',
    Icons.groups_rounded,
    'View all',
    customers.isEmpty
        ? _empty()
        : Column(
            children: customers
                .take(8)
                .map(
                  (x) => listRow(
                    Icons.person_rounded,
                    s(
                      x['CustomerName'] ?? x['Name'],
                      'Customer ${s(x['CustomerID'])}',
                    ),
                    '${n(x['OrderCount'])} orders',
                    money(x['OrderAmount'] ?? x['SalesAmount'] ?? x['Amount']),
                  ),
                )
                .toList(),
          ),
    () => {},
  );
  Widget inactiveCard() => card(
    'INACTIVE CUSTOMERS',
    Icons.person_off_rounded,
    'View all',
    inactive.isEmpty
        ? _empty()
        : Column(
            children: inactive
                .take(8)
                .map(
                  (x) => listRow(
                    Icons.person_off_rounded,
                    s(
                      x['CustomerName'] ?? x['Name'],
                      'Customer ${s(x['CustomerID'])}',
                    ),
                    '${n(x['InactiveDays'] ?? x['DaysInactive'] ?? x['Days'])} days inactive',
                    '',
                  ),
                )
                .toList(),
          ),
    () => {},
  );
  Widget productsCard() => card(
    'TOP PRODUCTS',
    Icons.inventory_2_rounded,
    'View all',
    products.isEmpty
        ? _empty(message: 'No product detail available from API')
        : Column(
            children: products
                .take(8)
                .map(
                  (x) => listRow(
                    Icons.inventory_2_rounded,
                    s(x['ProductName'] ?? x['Name'], 'Product'),
                    'Qty ${d(x['Quantity']).toStringAsFixed(0)}',
                    money(
                      x['SalesAmount'] ?? x['Amount'] ?? x['SalesAchieved'],
                    ),
                  ),
                )
                .toList(),
          ),
    () => {},
  );
  Widget actionsCard() {
    final below = n(
          actions['BelowTargetSalesmen'] ?? actions['SalesmenBelowTarget'],
        ),
        out = d(actions['OutstandingCustomers'] ?? summary['Outstanding']),
        ina = n(actions['InactiveCustomers']),
        pending = n(actions['PendingOrders'] ?? actions['OrdersPending']);
    return card(
      'ACTION REQUIRED',
      Icons.notifications_active_rounded,
      'Details',
      Column(
        children: [
          actionRow(
            Icons.warning_amber_rounded,
            'Salesmen below target',
            '$below',
            red,
          ),
          actionRow(
            Icons.currency_rupee_rounded,
            'Outstanding',
            money(out),
            orange,
          ),
          actionRow(
            Icons.person_off_rounded,
            'Customers inactive',
            '$ina',
            red,
          ),
          actionRow(
            Icons.pending_actions_rounded,
            'Orders pending',
            '$pending',
            orange,
          ),
        ],
      ),
      () => {},
    );
  }

  // ============================================================
  // TEAM MONITORING HELPERS
  // ============================================================

  String minutesText(dynamic value) {
    final mins = n(value);
    if (mins <= 0) return '0 min';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String firstValue(Map<String, dynamic> x, List<String> keys,
      [String fallback = '-']) {
    for (final key in keys) {
      final value = x[key];
      if (value != null && '$value'.trim().isNotEmpty && '$value' != 'null') {
        return '$value';
      }
    }
    return fallback;
  }

  double firstDouble(Map<String, dynamic> x, List<String> keys) {
    for (final key in keys) {
      if (x[key] != null) return d(x[key]);
    }
    return 0;
  }

  int firstInt(Map<String, dynamic> x, List<String> keys) {
    for (final key in keys) {
      if (x[key] != null) return n(x[key]);
    }
    return 0;
  }

  Widget smallMetric(String title, String value, IconData icon,
      {Color color = primary}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: sub,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget teamMonitoringCard() {
    final total = firstInt(attendanceSummary, [
      'TotalUsers',
      'TotalEmployees',
      'TeamCount',
      'TotalTeam',
    ]);
    final present = firstInt(attendanceSummary, [
      'PresentCount',
      'Present',
      'Attended',
      'PresentUsers',
    ]);
    final absent = firstInt(attendanceSummary, [
      'AbsentCount',
      'Absent',
      'AbsentUsers',
    ]);
    final leave = firstInt(attendanceSummary, [
      'LeaveCount',
      'OnLeave',
      'Leave',
    ]);
    final pct = firstDouble(attendanceSummary, [
      'AttendancePercentage',
      'AttendancePercent',
      'PresentPercentage',
    ]);

    return card(
      'TEAM ATTENDANCE',
      Icons.fact_check_rounded,
      '',
      Column(
        children: [
          Row(
            children: [
              smallMetric('TOTAL', '$total', Icons.groups_rounded),
              const SizedBox(width: 8),
              smallMetric('PRESENT', '$present', Icons.check_circle_rounded,
                  color: green),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              smallMetric('ABSENT', '$absent', Icons.cancel_rounded,
                  color: red),
              const SizedBox(width: 8),
              smallMetric('LEAVE', '$leave', Icons.event_busy_rounded,
                  color: orange),
            ],
          ),
          if (pct > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Attendance',
                  style: TextStyle(
                    color: sub,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: soft,
                valueColor: const AlwaysStoppedAnimation(green),
              ),
            ),
          ],
          if (attendanceSummary.isEmpty)
            _empty(message: 'No attendance summary available from API'),
        ],
      ),
      () => {},
    );
  }

  Widget salesmanAttendanceCard() {
    return card(
      'SALESMAN ATTENDANCE',
      Icons.people_alt_rounded,
      '',
      salesmanAttendance.isEmpty
          ? _empty(message: 'No salesman attendance data available')
          : Column(
              children: salesmanAttendance.take(10).map((raw) {
                final x = Map<String, dynamic>.from(raw as Map);
                final name = firstValue(x,
                    ['UserName', 'EmployeeName', 'Name', 'SalesmanName'],
                    'Salesman');
                final role = firstValue(x, ['RoleName', 'Role'], '');
                final present = firstInt(x,
                    ['PresentDays', 'PresentCount', 'Present', 'AttendedDays']);
                final absent = firstInt(x,
                    ['AbsentDays', 'AbsentCount', 'Absent', 'MissedDays']);
                final leave = firstInt(
                    x, ['LeaveDays', 'LeaveCount', 'Leave', 'OnLeaveDays']);
                final percentage = firstDouble(x, [
                  'AttendancePercentage',
                  'AttendancePercent',
                  'PresentPercentage',
                ]);
                final color = percentage >= 80
                    ? green
                    : percentage >= 60
                        ? orange
                        : red;

                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      avatar(name),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              role.isEmpty
                                  ? 'P $present • A $absent • L $leave'
                                  : '$role • P $present • A $absent • L $leave',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: sub,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
      () => {},
    );
  }

  Widget loginMonitoringCard() {
    final total = firstInt(loginSummary, [
      'TotalUsers',
      'TotalEmployees',
      'TeamCount',
      'TotalTeam',
    ]);
    final loggedIn = firstInt(loginSummary, [
      'LoggedInCount',
      'LoginCount',
      'LoggedIn',
      'ActiveUsers',
    ]);
    final notLogged = firstInt(loginSummary, [
      'NotLoggedInCount',
      'NotLoggedCount',
      'NotLoggedIn',
    ]);
    final sessions = firstInt(loginSummary, [
      'SessionCount',
      'Sessions',
      'TotalSessions',
    ]);

    return card(
      'LOGIN MONITORING',
      Icons.login_rounded,
      '',
      Column(
        children: [
          Row(
            children: [
              smallMetric('TEAM', '$total', Icons.groups_rounded),
              const SizedBox(width: 8),
              smallMetric('LOGGED IN', '$loggedIn', Icons.login_rounded,
                  color: green),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              smallMetric('NOT LOGGED', '$notLogged', Icons.logout_rounded,
                  color: red),
              const SizedBox(width: 8),
              smallMetric('SESSIONS', '$sessions', Icons.history_rounded,
                  color: blue),
            ],
          ),
          if (loginDetails.isNotEmpty) ...[
            const SizedBox(height: 11),
            ...loginDetails.take(8).map((raw) {
              final x = Map<String, dynamic>.from(raw as Map);
              final name = firstValue(x,
                  ['UserName', 'EmployeeName', 'Name', 'SalesmanName'],
                  'User');
              final login = firstValue(x,
                  ['LoginTime', 'LogInTime', 'LoginDate', 'AttendanceTime'],
                  '');
              final logout = firstValue(x,
                  ['LogoutTime', 'LogOutTime', 'LogoutDate'], '');
              final duration = firstValue(x,
                  ['WorkingHours', 'Duration', 'WorkingDuration'], '');
              final status = firstValue(x, ['Status', 'LoginStatus'], '');
              final isActive = status.toLowerCase().contains('active') ||
                  status.toLowerCase().contains('login') ||
                  logout.isEmpty;

              return listRow(
                isActive ? Icons.circle : Icons.history_rounded,
                name,
                '$login${logout.isEmpty ? '' : ' → $logout'}${duration.isEmpty ? '' : ' • $duration'}',
                status.isEmpty ? (isActive ? 'Online' : 'Logged') : status,
              );
            }),
          ],
          if (loginSummary.isEmpty && loginDetails.isEmpty)
            _empty(message: 'No login monitoring data available'),
        ],
      ),
      () => {},
    );
  }

  Widget leaveMonitoringCard() {
    final total = firstInt(leaveSummary, [
      'TotalLeaveDays',
      'LeaveDays',
      'TotalLeaves',
      'LeaveCount',
    ]);
    final requests = firstInt(leaveSummary, [
      'RequestCount',
      'TotalRequests',
      'Requests',
    ]);
    final approved = firstInt(leaveSummary, [
      'ApprovedCount',
      'Approved',
      'ApprovedLeaves',
    ]);
    final pending = firstInt(leaveSummary, [
      'PendingCount',
      'Pending',
      'PendingLeaves',
    ]);

    return card(
      'LEAVE MONITORING',
      Icons.event_note_rounded,
      '',
      Column(
        children: [
          Row(
            children: [
              smallMetric('LEAVE DAYS', '$total', Icons.event_busy_rounded,
                  color: orange),
              const SizedBox(width: 8),
              smallMetric('REQUESTS', '$requests', Icons.assignment_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              smallMetric('APPROVED', '$approved', Icons.check_circle_rounded,
                  color: green),
              const SizedBox(width: 8),
              smallMetric('PENDING', '$pending', Icons.pending_actions_rounded,
                  color: red),
            ],
          ),
          if (leaveDetails.isNotEmpty) ...[
            const SizedBox(height: 11),
            ...leaveDetails.take(8).map((raw) {
              final x = Map<String, dynamic>.from(raw as Map);
              final name = firstValue(x,
                  ['UserName', 'EmployeeName', 'Name', 'SalesmanName'],
                  'Employee');
              final fromDate = firstValue(x,
                  ['FromDate', 'LeaveFrom', 'StartDate'], '');
              final toDate = firstValue(x,
                  ['ToDate', 'LeaveTo', 'EndDate'], '');
              final type = firstValue(x,
                  ['LeaveType', 'Type', 'LeaveName'], 'Leave');
              final status = firstValue(x, ['Status', 'LeaveStatus'], '');
              return listRow(
                Icons.event_rounded,
                name,
                '$type • $fromDate${toDate.isEmpty ? '' : ' → $toDate'}',
                status,
              );
            }),
          ],
          if (leaveSummary.isEmpty && leaveDetails.isEmpty)
            _empty(message: 'No leave data available'),
        ],
      ),
      () => {},
    );
  }

  Widget workSummaryCard() {
    if (workSummary.isEmpty) {
      return card(
        'WORKING HOURS',
        Icons.schedule_rounded,
        '',
        _empty(message: 'No working-hours data available'),
        () => {},
      );
    }

    return card(
      'WORKING HOURS',
      Icons.schedule_rounded,
      '',
      Column(
        children: workSummary.take(10).map((raw) {
          final x = Map<String, dynamic>.from(raw as Map);
          final name = firstValue(x,
              ['UserName', 'EmployeeName', 'Name', 'SalesmanName'], 'Employee');
          final hours = firstValue(x,
              ['WorkingHours', 'TotalWorkingHours', 'WorkHours'], '');
          final minutes = firstInt(x,
              ['WorkingMinutes', 'TotalWorkingMinutes', 'MinutesWorked']);
          final login = firstValue(x,
              ['LoginTime', 'FirstLogin', 'FirstLoginTime'], '');
          final logout = firstValue(x,
              ['LogoutTime', 'LastLogout', 'LastLogoutTime'], '');
          final displayHours = hours.isNotEmpty
              ? hours
              : minutes > 0
                  ? minutesText(minutes)
                  : '0h';

          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                avatar(name),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$login${logout.isEmpty ? '' : ' → $logout'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: sub,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  displayHours,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      () => {},
    );
  }

  Widget odometerCard() {
    final totalDistance = firstDouble(odometerSummary, [
      'TotalDistance',
      'TotalKM',
      'DistanceKM',
      'TravelDistance',
      'TotalTravel',
    ]);
    final totalUsers = firstInt(odometerSummary, [
      'TotalUsers',
      'Users',
      'TeamCount',
    ]);

    return card(
      'ODOMETER / TRAVEL',
      Icons.speed_rounded,
      '',
      Column(
        children: [
          Row(
            children: [
              smallMetric(
                'TOTAL DISTANCE',
                '${totalDistance.toStringAsFixed(1)} km',
                Icons.route_rounded,
                color: teal,
              ),
              const SizedBox(width: 8),
              smallMetric(
                'USERS',
                '$totalUsers',
                Icons.groups_rounded,
                color: blue,
              ),
            ],
          ),
          if (salesmanOdometer.isNotEmpty) ...[
            const SizedBox(height: 11),
            ...salesmanOdometer.take(10).map((raw) {
              final x = Map<String, dynamic>.from(raw as Map);
              final name = firstValue(x,
                  ['UserName', 'EmployeeName', 'Name', 'SalesmanName'],
                  'Salesman');
              final opening = firstDouble(x, [
                'OpeningOdometer',
                'StartOdometer',
                'OdometerStart',
                'OpeningReading',
              ]);
              final closing = firstDouble(x, [
                'ClosingOdometer',
                'EndOdometer',
                'OdometerEnd',
                'ClosingReading',
              ]);
              final distance = firstDouble(x, [
                'Distance',
                'DistanceKM',
                'TravelDistance',
                'TotalDistance',
              ]);
              final calculated = distance > 0
                  ? distance
                  : (closing > opening ? closing - opening : 0);

              return listRow(
                Icons.speed_rounded,
                name,
                'Start ${opening.toStringAsFixed(0)} • End ${closing.toStringAsFixed(0)}',
                '${calculated.toStringAsFixed(1)} km',
              );
            }),
          ],
          if (odometerSummary.isEmpty && salesmanOdometer.isEmpty)
            _empty(message: 'No odometer data available'),
        ],
      ),
      () => {},
    );
  }

  Widget shopVisitCard() {
    final total = firstInt(visitSummary, [
      'TotalVisits',
      'VisitCount',
      'TotalShopVisits',
      'Visits',
    ]);
    final visited = firstInt(visitSummary, [
      'VisitedShops',
      'VisitedCount',
      'ShopsVisited',
    ]);
    final planned = firstInt(visitSummary, [
      'PlannedVisits',
      'PlannedCount',
      'PlannedShops',
    ]);
    final notVisited = firstInt(visitSummary, [
      'NotVisitedShops',
      'NotVisitedCount',
      'MissedVisits',
    ]);

    return card(
      'SHOP VISITS / ROUTE',
      Icons.storefront_rounded,
      '',
      Column(
        children: [
          Row(
            children: [
              smallMetric('TOTAL VISITS', '$total', Icons.store_rounded,
                  color: primary),
              const SizedBox(width: 8),
              smallMetric('VISITED', '$visited', Icons.check_circle_rounded,
                  color: green),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              smallMetric('PLANNED', '$planned', Icons.route_rounded,
                  color: blue),
              const SizedBox(width: 8),
              smallMetric('NOT VISITED', '$notVisited', Icons.location_off_rounded,
                  color: red),
            ],
          ),
          if (salesmanVisits.isNotEmpty) ...[
            const SizedBox(height: 11),
            ...salesmanVisits.take(10).map((raw) {
              final x = Map<String, dynamic>.from(raw as Map);
              final name = firstValue(x,
                  ['UserName', 'EmployeeName', 'Name', 'SalesmanName'],
                  'Salesman');
              final visits = firstInt(x,
                  ['VisitCount', 'TotalVisits', 'Visits', 'VisitedCount']);
              final shops = firstInt(x,
                  ['ShopCount', 'ShopsVisited', 'UniqueShops']);
              final missed = firstInt(x,
                  ['NotVisitedCount', 'MissedVisits', 'NotVisitedShops']);
              final route = firstValue(x,
                  ['RouteName', 'Route', 'AreaName', 'Territory'], '');

              return listRow(
                Icons.storefront_rounded,
                name,
                '${route.isEmpty ? '' : '$route • '}$shops shops • $missed missed',
                '$visits visits',
              );
            }),
          ],
          if (visitSummary.isEmpty && salesmanVisits.isEmpty)
            _empty(message: 'No shop visit data available'),
        ],
      ),
      () => {},
    );
  }

  // ------------------------------------------------------------
  // TEAM HIERARCHY
  //
  // Rows are also tappable here for the same drill-down.
  // ------------------------------------------------------------

  Widget hierarchyCard() => card(
    'TEAM HIERARCHY',
    Icons.account_tree_rounded,
    'View tree',
    hierarchy.isEmpty
        ? _empty(message: 'Hierarchy data unavailable')
        : Column(
            children: hierarchy.take(10).map((x) {
              final level = n(x['TreeLevel']);
              return Padding(
                padding: EdgeInsets.only(left: level * 16, bottom: 7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openMemberDashboard(x),
                  child: Row(
                    children: [
                      avatar(s(x['Name'], 'User')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${s(x['Name'])} • ${s(x['RoleName'], 'User')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: sub,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
    () => {},
  );
  Widget listRow(
    IconData icon,
    String title,
    String subtitle,
    String value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: const BoxDecoration(color: soft, shape: BoxShape.circle),
          child: Icon(icon, color: primary, size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: sub,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        if (value.isNotEmpty)
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
      ],
    ),
  );
  Widget actionRow(IconData icon, String title, String value, Color color) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
  Widget card(
    String title,
    IconData icon,
    String action,
    Widget child,
    VoidCallback onTap,
  ) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primary, size: 21),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (action.isNotEmpty)
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
  Widget _empty({String message = 'No data available'}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inbox_outlined, color: primary),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: const TextStyle(
              color: sub,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> logout(BuildContext context) async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }
}