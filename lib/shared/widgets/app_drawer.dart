import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/features/customer/presentation/pages/customer_list_page.dart';
import 'package:suitapps/shared/extensions/responsive.dart';
import 'package:suitapps/features/auth/presentation/pages/profile_page.dart';
import 'package:suitapps/features/auth/presentation/pages/settings_page.dart';
import 'package:suitapps/features/customer/presentation/pages/customer_create_page.dart';
import 'package:suitapps/features/odo_meter/presentation/pages/end_odometer_page.dart';
import 'package:suitapps/features/customer/presentation/pages/existing_customers_page.dart';
import 'package:suitapps/features/auth/presentation/pages/apply_leave_page.dart';
import 'package:suitapps/features/receipt/presentation/pages/receipt_list_page.dart';
import 'package:suitapps/features/direct_sale/presentation/pages/direct_sale_list_page.dart'; // adjust path if different

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onLogout, this.profileUrl});

  final String? profileUrl;
  final VoidCallback onLogout;

  Future<_DrawerUserData> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final name = (prefs.getString('Name') ?? '').trim();
    final role = (prefs.getString('UserRoleName') ?? '').trim();
    final company = (prefs.getString('SelectedCompanyName') ?? '').trim();

    // UserID may have been stored as an int or a string depending on where
    // it was written, so accept either.
    final userId = prefs.getInt('UserID') ??
        int.tryParse(prefs.getString('UserID') ?? '') ??
        0;

    final loginDate = (prefs.getString('loginDate') ?? '').trim();
    final loginTime = (prefs.getString('loginTime') ?? '').trim();

    String loginText = '';
    if (loginDate.isNotEmpty && loginTime.isNotEmpty) {
      loginText = "$loginDate â€¢ $loginTime";
    } else if (loginDate.isNotEmpty) {
      loginText = loginDate;
    }

    String versionText = '';
    try {
      final info = await PackageInfo.fromPlatform();
      versionText = "v${info.version} (${info.buildNumber})";
    } catch (_) {}

    return _DrawerUserData(
      name: name.isEmpty ? "User" : name,
      role: role,
      company: company,
      loginText: loginText,
      versionText: versionText,
      userId: userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = Responsive.w(context);

    // âœ… Auto drawer width (no breakpoints)
    final double drawerW = (screenW * 0.78).clamp(280.0, 380.0);

    final double pad = Responsive.pad(context, 16);
    final double logoH = Responsive.scale(context, 44);
    final double sectionGap = Responsive.pad(context, 14);

    return Drawer(
      width: drawerW,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: FutureBuilder<_DrawerUserData>(
            future: _loadUserData(),
            builder: (context, snap) {
              final d =
                  snap.data ??
                  const _DrawerUserData(
                    name: "User",
                    role: "",
                    company: "",
                    loginText: "",
                    versionText: "",
                  );

              final String nameWithRole = (d.role.trim().isNotEmpty)
                  ? "${d.name} (${d.role})"
                  : d.name;

              return Column(
                children: [
                  // LOGO
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      "assets/images/sp-logo.png",
                      height: logoH,
                    ),
                  ),

                  SizedBox(height: sectionGap),
                  Divider(height: Responsive.scale(context, 1)),
                  SizedBox(height: Responsive.pad(context, 8)),

                  // MENU
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _drawerItem(
                          context,
                          icon: Icons.home_rounded,
                          title: "Home",
                          onTap: () => Navigator.pop(context),
                        ),

                        //
                        ExpansionTile(
                          leading: Icon(
                            Icons.people_rounded,
                            color: Colors.black87,
                          ),
                          title: const Text("Customer"),
                          children: [
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.add_circle_outline),
                              title: const Text("Create New Customer"),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CustomerDashboardPage(),
                                  ),
                                );
                              },
                            ),

                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.people_alt_rounded),
                              title: const Text("New Customers"),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CustomerListPage(),
                                  ),
                                );
                              },
                            ),

                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.people_alt_rounded),
                              title: const Text("Existing Customers"),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ExistingCustomersPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        // ADD THIS AFTER ExpansionTile
                        _drawerItem(
                          context,
                          icon: Icons.beach_access_rounded,
                          title: "Apply Leave",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ApplyLeavePage(),
                              ),
                            );
                          },
                        ),
                        _drawerItem(
                          context,
                          icon: Icons.request_page_rounded,
                          title: "Receipts",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReceiptListPage(userId: d.userId),
                              ),
                            );
                          },
                        ),
                        // NEW: opens DirectSaleListPage, which shows every
                        // locally-saved bill (see DatabaseHelper.getAllBills)
                        // and lets the user tap one to edit it via
                        // DirectSaleOfCustomer(billToEdit: ..., ...).
                        _drawerItem(
                          context,
                          icon: Icons.point_of_sale_rounded,
                          title: "Direct Sale",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DirectSaleListPage(),
                              ),
                            );
                          },
                        ),
                        _drawerItem(
                          context,
                          icon: Icons.receipt_long_rounded,
                          title: "Orders",
                          onTap: () => Navigator.pop(context),
                        ),
                        _drawerItem(
                          context,
                          icon: Icons.bar_chart_rounded,
                          title: "Reports",
                          onTap: () => Navigator.pop(context),
                        ),
                        _drawerItem(
                          context,
                          icon: Icons.description_rounded,
                          title: "Invoices",
                          onTap: () => Navigator.pop(context),
                        ),
                        _drawerItem(
                          context,
                          icon: Icons.person_rounded,
                          title: "Profile",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfilePage(),
                              ),
                            );
                          },
                        ),
                        _drawerItem(
                          context,
                          icon: Icons.speed_rounded,
                          title: "End Odometer",
                          onTap: () {
                            Navigator.pop(context);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EndOdometerPage(),
                              ),
                            );
                          },
                        ),
                        _drawerItem(
                          context,
                          icon: Icons.settings_rounded,
                          title: "Settings",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  Divider(height: Responsive.scale(context, 1)),
                  SizedBox(height: Responsive.pad(context, 10)),

                  // PROFILE SECTION
                  Row(
                    children: [
                      _profileAvatar(context),
                      SizedBox(width: Responsive.pad(context, 10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameWithRole,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: Responsive.font(context, 14),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (d.company.isNotEmpty) ...[
                              SizedBox(height: Responsive.pad(context, 2)),
                              Text(
                                d.company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.font(context, 11.5),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                            if (d.loginText.isNotEmpty) ...[
                              SizedBox(height: Responsive.pad(context, 2)),
                              Text(
                                "Logged in: ${d.loginText}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.font(context, 11.0),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: Responsive.pad(context, 12)),

                  // LOGOUT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: Responsive.scale(context, 46),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.radius(context, 14),
                          ),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onLogout();
                      },
                      icon: Icon(
                        Icons.logout_rounded,
                        size: Responsive.scale(context, 18),
                      ),
                      label: Text(
                        "Logout",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: Responsive.font(context, 13.5),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: Responsive.pad(context, 10)),

                  // FOOTER
                  Column(
                    children: [
                      Text(
                        "MICROTECH SOFTWARE SOLUTIONS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Responsive.font(context, 10.8),
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: Responsive.pad(context, 4)),
                      if (d.versionText.isNotEmpty)
                        Text(
                          d.versionText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: Responsive.font(context, 10.8),
                            fontWeight: FontWeight.w700,
                            color: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _profileAvatar(BuildContext context) {
    final double size = Responsive.scale(context, 46);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: ClipOval(
        child: (profileUrl != null && profileUrl!.trim().isNotEmpty)
            ? Image.network(
                profileUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person_rounded,
                  size: Responsive.scale(context, 22),
                  color: const Color(0xFF2300C4),
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: Responsive.scale(context, 22),
                color: const Color(0xFF2300C4),
              ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.pad(context, 6),
      ),
      leading: Icon(
        icon,
        color: Colors.black87,
        size: Responsive.scale(context, 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.font(context, 13.8),
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.radius(context, 12)),
      ),
    );
  }
}

class _DrawerUserData {
  final String name;
  final String role;
  final String company;
  final String loginText;
  final String versionText;
  final int userId;

  const _DrawerUserData({
    required this.name,
    required this.role,
    required this.company,
    required this.loginText,
    required this.versionText,
    this.userId = 0,
  });
}
