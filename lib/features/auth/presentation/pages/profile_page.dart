import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:suitapps/shared/extensions/responsive.dart';
import 'package:suitapps/features/auth/presentation/pages/settings_page.dart';

// âœ… For device current location


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _fallbackAvatar = "assets/icon/sp-logo.png";
  static const String _footerLogo = "assets/images/sp-logo.png";

  String _name = "User";
  String _subtitle = "";
  String _company = "";
  String _loginDate = "";
  String _loginTime = "";
  String _loginDisplay = "";
  String _currentLocation = "Fetching location...";
  String? _profileUrl;

  bool _notification = true;
  bool _locLoading = false;

  // âœ… Stats (replace later with API)
  final String _ordersCompleted = "1,179";
  final String _successRate = "94.5%";
  final String _customerRating = "4.8/5";
  final String _teamRank = "#12";

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCurrentLocation();
  }

  // -----------------------------
  // HELPERS: date/time formatting
  // -----------------------------

  String _monthName(int m) {
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
    if (m < 1 || m > 12) return "";
    return months[m - 1];
  }

  DateTime? _tryParseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // 1) ISO / yyyy-mm-dd / full datetime
    try {
      return DateTime.parse(s);
    } catch (_) {}

    // 2) dd/mm/yyyy or dd-mm-yyyy
    final r = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$');
    final m = r.firstMatch(s);
    if (m != null) {
      final d = int.tryParse(m.group(1)!) ?? 0;
      final mo = int.tryParse(m.group(2)!) ?? 0;
      int y = int.tryParse(m.group(3)!) ?? 0;
      if (y < 100) y += 2000;
      if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12 && y >= 1900) {
        return DateTime(y, mo, d);
      }
    }
    return null;
  }

  String _formatLogin(String dateRaw, String timeRaw) {
    final dt = _tryParseDate(dateRaw);

    String datePart = dateRaw.trim();
    if (dt != null) {
      datePart = "${dt.day} ${_monthName(dt.month)} ${dt.year}";
    }

    final t = timeRaw.trim();

    if (datePart.isEmpty && t.isEmpty) return "";
    if (datePart.isEmpty) return t;
    if (t.isEmpty) return datePart;
    return "$datePart â€¢ $t";
  }

  // ------------------ USER LOAD ------------------

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final name = (prefs.getString("Name") ?? "").trim();
      final role = (prefs.getString("UserRoleName") ?? "").trim();
      final company = (prefs.getString("SelectedCompanyName") ?? "").trim();
      final loginDate = (prefs.getString("loginDate") ?? "").trim();
      final loginTime = (prefs.getString("loginTime") ?? "").trim();
      final notif = prefs.getBool("notificationEnabled");

      String? profile;
      final userJson = (prefs.getString("user") ?? "").trim();
      if (userJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(userJson);
          if (decoded is Map<String, dynamic>) {
            final p = (decoded["ProfileImage"] ?? "").toString().trim();
            profile = p.isEmpty ? null : p;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _name = name.isEmpty ? "User" : name;
        _subtitle = role;
        _company = company;
        _loginDate = loginDate;
        _loginTime = loginTime;
        _loginDisplay = _formatLogin(loginDate, loginTime);
        _profileUrl = profile;
        if (notif != null) _notification = notif;
      });
    } catch (_) {}
  }

  // ------------------ LOCATION ------------------

  Future<void> _loadCurrentLocation() async {
    if (_locLoading) return;
    _locLoading = true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        setState(() => _currentLocation = "Location service disabled");
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _currentLocation = "Location permission denied");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(
          () => _currentLocation = "Enable location permission in settings",
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String label =
          "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";

      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if ((p.subLocality ?? "").trim().isNotEmpty) p.subLocality!.trim(),
            if ((p.locality ?? "").trim().isNotEmpty) p.locality!.trim(),
            if ((p.country ?? "").trim().isNotEmpty) p.country!.trim(),
          ];
          if (parts.isNotEmpty) label = parts.join(", ");
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() => _currentLocation = label);
    } catch (_) {
      if (!mounted) return;
      setState(() => _currentLocation = "Unable to fetch location");
    } finally {
      _locLoading = false;
    }
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _setNotification(bool v) async {
    setState(() => _notification = v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationEnabled', v);
    } catch (_) {}
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    final double r = Responsive.radius(context, 22);
    final double pad = Responsive.pad(context, 16);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 221, 226, 252),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1433C3),
              Color.fromARGB(255, 156, 171, 255),
              Color.fromARGB(255, 237, 240, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topBar(),
                      SizedBox(height: pad),

                      _profileHeroCard(radius: r),
                      SizedBox(height: pad),

                      _sectionTitle("Performance Overview"),
                      SizedBox(height: Responsive.pad(context, 8)),
                      _statsGridCard(radius: r),

                      SizedBox(height: Responsive.pad(context, 18)),

                      _sectionTitle("Other Settings"),
                      SizedBox(height: Responsive.pad(context, 8)),
                      _card(
                        radius: r,
                        child: Column(
                          children: [
                            _tile(
                              icon: Icons.person_outline_rounded,
                              title: "Profile Details",
                              onTap: () => _open(const EditProfilePage()),
                            ),
                            _divider(),
                            _tile(
                              icon: Icons.lock_outline_rounded,
                              title: "Password",
                              onTap: () => _open(const PasswordPage()),
                            ),
                            _divider(),
                            _switchTile(
                              icon: Icons.notifications_none_rounded,
                              title: "Notifications",
                              value: _notification,
                              onChanged: _setNotification,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.pad(context, 14)),

                      _sectionTitle("Support"),
                      SizedBox(height: Responsive.pad(context, 8)),
                      _card(
                        radius: r,
                        child: Column(
                          children: [
                            _tile(
                              icon: Icons.support_agent_rounded,
                              title: "Support",
                              onTap: () => _open(const SupportPage()),
                            ),
                            _divider(),
                            _tile(
                              icon: Icons.report_gmailerrorred_rounded,
                              title: "Report an Issue",
                              onTap: () => _open(const ReportIssuePage()),
                            ),
                            _divider(),
                            _tile(
                              icon: Icons.info_outline_rounded,
                              title: "About",
                              onTap: () => _open(const AboutPage()),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.pad(context, 18)),
                    ],
                  ),
                ),
              ),

              // âœ… FIXED FOOTER
              Padding(
                padding: EdgeInsets.only(
                  left: pad,
                  right: pad,
                  bottom: Responsive.pad(context, 12),
                  top: Responsive.pad(context, 6),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Image.asset(
                        _footerLogo,
                        width: Responsive.scale(context, 200),
                        height: Responsive.scale(context, 50),
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: Responsive.pad(context, 8)),
                      Text(
                        "MICROTECH SOFTWARE SOLUTIONS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Responsive.font(context, 11.5),
                          fontWeight: FontWeight.w900,
                          color: const Color.fromARGB(
                            255,
                            0,
                            0,
                            0,
                          ).withValues(alpha: 0.95),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ UI PARTS ------------------

  Widget _topBar() {
    final double btn = Responsive.scale(context, 40);
    final double icon = Responsive.scale(context, 18);

    return Row(
      children: [
        _roundIconButton(
          size: btn,
          iconSize: icon,
          icon: Icons.chevron_left_rounded,
          onTap: () => Navigator.pop(context),
        ),
        Expanded(
          child: Center(
            child: Text(
              "Profile",
              style: TextStyle(
                fontSize: Responsive.font(context, 20),
                fontWeight: FontWeight.w900,
                color: const Color.fromARGB(255, 255, 255, 255),
              ),
            ),
          ),
        ),
        _roundIconButton(
          size: btn,
          iconSize: icon,
          icon: Icons.settings_rounded,
          onTap: () => _open(const SettingsPage()),
        ),
      ],
    );
  }

  // âœ… FIXED: this method was missing (caused your error)
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: Responsive.font(context, 12.5),
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    );
  }

  Widget _card({required double radius, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _profileHeroCard({required double radius}) {
    final double pad = Responsive.pad(context, 14);
    final double avatar = Responsive.scale(context, 78);
    final double editSize = Responsive.scale(context, 26);

    return _glassCard(
      radius: radius,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NAME ROW
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: Responsive.scale(context, 18),
                        color: Colors.black87,
                      ),
                      SizedBox(width: Responsive.pad(context, 6)),
                      Expanded(
                        child: Text(
                          _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: Responsive.font(context, 16),
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // âœ… consistent spacing between blocks
                  SizedBox(height: Responsive.pad(context, 6)),

                  // COMPANY
                  if (_company.isNotEmpty) ...[
                    _infoInline(
                      icon: Icons.apartment_rounded,
                      text: _company,
                      bold: true,
                    ),
                    SizedBox(height: Responsive.pad(context, 6)),
                  ],

                  // ROLE (subtitle)
                  if (_subtitle.trim().isNotEmpty) ...[
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.font(context, 11.5),
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: Responsive.pad(context, 6)),
                  ],

                  // LOGIN
                  if (_loginDisplay.trim().isNotEmpty) ...[
                    _infoInline(icon: Icons.login_rounded, text: _loginDisplay),
                    SizedBox(height: Responsive.pad(context, 6)),
                  ],

                  // âœ… LOCATION (allow 2 lines + better alignment)
                  _infoInlineMultiLine(
                    icon: Icons.location_on_outlined,
                    text: _currentLocation,
                    onTap: _loadCurrentLocation,
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            SizedBox(width: Responsive.pad(context, 12)),

            SizedBox(
              width: avatar,
              height: avatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: avatar,
                    height: avatar,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(child: _avatarImage()),
                  ),
                  Positioned(
                    bottom: -Responsive.pad(context, 2),
                    right: -Responsive.pad(context, 2),
                    child: InkWell(
                      onTap: () => _open(const EditProfilePage()),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: editSize,
                        height: editSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.92),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: Responsive.scale(context, 14),
                          color: Colors.black,
                        ),
                      ),
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

  Widget _infoInline({
    required IconData icon,
    required String text,
    bool bold = false,
    VoidCallback? onTap,
  }) {
    final row = Row(
      children: [
        Icon(icon, size: Responsive.scale(context, 16), color: Colors.black54),
        SizedBox(width: Responsive.pad(context, 6)),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Responsive.font(context, 11.6),
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: bold ? Colors.black87 : Colors.black54,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.pad(context, 2)),
        child: row,
      ),
    );
  }

  // âœ… NEW: multiline helper (for location)
  Widget _infoInlineMultiLine({
    required IconData icon,
    required String text,
    bool bold = false,
    VoidCallback? onTap,
    int maxLines = 2,
  }) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: Responsive.pad(context, 1)),
          child: Icon(
            icon,
            size: Responsive.scale(context, 16),
            color: Colors.black54,
          ),
        ),
        SizedBox(width: Responsive.pad(context, 6)),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Responsive.font(context, 11.6),
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: bold ? Colors.black87 : Colors.black54,
              height: 1.25,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.pad(context, 2)),
        child: row,
      ),
    );
  }

  Widget _avatarImage() {
    if (_profileUrl != null && _profileUrl!.trim().isNotEmpty) {
      return Image.network(
        _profileUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Image.asset(_fallbackAvatar, fit: BoxFit.cover),
      );
    }
    return Image.asset(_fallbackAvatar, fit: BoxFit.cover);
  }

  Widget _statsGridCard({required double radius}) {
    return _glassCard(
      radius: radius,
      child: Padding(
        padding: EdgeInsets.all(Responsive.pad(context, 12)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _statMiniCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: const Color(0xFF1433C3),
                    value: _ordersCompleted,
                    label: "Orders Completed",
                  ),
                ),
                SizedBox(width: Responsive.pad(context, 12)),
                Expanded(
                  child: _statMiniCard(
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF1433C3),
                    value: _successRate,
                    label: "Success Rate",
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.pad(context, 12)),
            Row(
              children: [
                Expanded(
                  child: _statMiniCard(
                    icon: Icons.star_border_rounded,
                    iconColor: const Color(0xFFFFB300),
                    value: _customerRating,
                    label: "Customer Rating",
                  ),
                ),
                SizedBox(width: Responsive.pad(context, 12)),
                Expanded(
                  child: _statMiniCard(
                    icon: Icons.emoji_events_outlined,
                    iconColor: Colors.black87,
                    value: _teamRank,
                    label: "Team Rank",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statMiniCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    final double r = Responsive.radius(context, 16);

    return Container(
      height: Responsive.scale(context, 92),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(Responsive.pad(context, 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: Responsive.scale(context, 30),
            height: Responsive.scale(context, 30),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(
                Responsive.radius(context, 10),
              ),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Icon(
              icon,
              size: Responsive.scale(context, 18),
              color: iconColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: Responsive.font(context, 16),
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          SizedBox(height: Responsive.pad(context, 2)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Responsive.font(context, 11.2),
              fontWeight: FontWeight.w700,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required double radius, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: _tileIcon(icon),
      title: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.font(context, 13.0),
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      dense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.pad(context, 12),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: _tileIcon(icon),
      title: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.font(context, 13.0),
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF1433C3),
      ),
      dense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.pad(context, 12),
      ),
    );
  }

  Widget _tileIcon(IconData icon) {
    final double s = Responsive.scale(context, 34);
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(Responsive.radius(context, 10)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Icon(
        icon,
        size: Responsive.scale(context, 18),
        color: Colors.black87,
      ),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    thickness: 1,
    color: Colors.black.withValues(alpha: 0.06),
    indent: Responsive.pad(context, 12),
    endIndent: Responsive.pad(context, 12),
  );

  Widget _roundIconButton({
    required double size,
    required double iconSize,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: Colors.black),
      ),
    );
  }
}

// ------------------------------------------------------
// Placeholder pages
// ------------------------------------------------------

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Edit Profile")),
    body: const Center(child: Text("TODO")),
  );
}

class PasswordPage extends StatelessWidget {
  const PasswordPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Password")),
    body: const Center(child: Text("TODO")),
  );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Notifications")),
    body: const Center(child: Text("TODO")),
  );
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Support")),
    body: const Center(child: Text("TODO")),
  );
}

class ReportIssuePage extends StatelessWidget {
  const ReportIssuePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Report an Issue")),
    body: const Center(child: Text("TODO")),
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("About")),
    body: const Center(child: Text("TODO")),
  );
}
