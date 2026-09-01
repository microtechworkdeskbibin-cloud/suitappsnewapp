import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/features/auth/data/datasources/permissions_local_datasource.dart';
import 'package:suitapps/features/auth/data/datasources/permissions_api_datasource.dart';
import 'package:suitapps/shared/extensions/responsive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final PermissionsApiService _permissionsApi = PermissionsApiService();
  final PermissionsLocalDbService _permissionsLocalDb =
      PermissionsLocalDbService();

  bool _syncingPermissions = false;

  // â”€â”€ Sync Permissions: API -> local DB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _syncPermissions() async {
    if (_syncingPermissions) return;

    setState(() => _syncingPermissions = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final empId =
          (prefs.getInt('UserId') ?? prefs.getString('UserId'))
              ?.toString() ??
          '';
      final companyId =
          prefs.getString('CompanyID') ??
          prefs.getString('SelectedCompanyId') ??
          '';

      if (empId.isEmpty || companyId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Missing employee/company info - cannot sync'),
            ),
          );
        }
        return;
      }

      // 1. Fetch latest permissions from the API.
      final permissions = await _permissionsApi.fetchPermissions(
        employeeCode: empId,
        companyId: companyId,
      );

      // 2. Save (replace) them in the local cache.
      await _permissionsLocalDb.savePermissions(
        employeeCode: empId,
        companyId: companyId,
        permissions: permissions,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permissions synced (${permissions.length} rules)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingPermissions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: const Color(0xFF2300C4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(Responsive.pad(context, 16)),
          children: [
            _tile(
              context,
              icon: Icons.lock_outline,
              title: "Change Password",
              onTap: () {},
            ),
            _tile(
              context,
              icon: Icons.notifications_none_rounded,
              title: "Notifications",
              onTap: () {},
            ),
            _tile(
              context,
              icon: Icons.sync_rounded,
              title: "Sync Permissions",
              onTap: _syncPermissions,
              loading: _syncingPermissions,
            ),
            _tile(
              context,
              icon: Icons.info_outline_rounded,
              title: "About",
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.pad(context, 10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FF),
        borderRadius: BorderRadius.circular(Responsive.radius(context, 14)),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2300C4)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: Responsive.font(context, 13.8),
          ),
        ),
        trailing: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF2300C4),
                  ),
                ),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: loading ? null : onTap,
      ),
    );
  }
}
