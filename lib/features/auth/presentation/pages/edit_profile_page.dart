import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/shared/extensions/responsive.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.initialName,
    required this.initialUsername,
  });

  final String initialName;
  final String initialUsername;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _usernameCtrl = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final newName = _nameCtrl.text.trim();
      final newUsername = _usernameCtrl.text.trim();

      if (newName.isNotEmpty) {
        await prefs.setString('Name', newName);
      }
      if (newUsername.isNotEmpty) {
        await prefs.setString('Username', newUsername);
      }

      if (!mounted) return;
      Navigator.pop(context); // return to Profile
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to save profile")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double fieldRadius = Responsive.radius(context, 14);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF2300C4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.pad(context, 16)),
          child: Column(
            children: [
              _field(
                label: "Name",
                controller: _nameCtrl,
                fieldRadius: fieldRadius,
                icon: Icons.person_outline,
              ),
              SizedBox(height: Responsive.pad(context, 12)),
              _field(
                label: "Username",
                controller: _usernameCtrl,
                fieldRadius: fieldRadius,
                icon: Icons.alternate_email_rounded,
              ),
              SizedBox(height: Responsive.pad(context, 18)),
              SizedBox(
                width: double.infinity,
                height: Responsive.scale(context, 48),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2300C4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        Responsive.radius(context, 14),
                      ),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          height: Responsive.scale(context, 20),
                          width: Responsive.scale(context, 20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Save",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required double fieldRadius,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2A2E),
            fontSize: Responsive.font(context, 13.5),
          ),
        ),
        SizedBox(height: Responsive.pad(context, 8)),
        TextField(
          controller: controller,
          cursorColor: const Color(0xFF2300C4),
          style: TextStyle(fontSize: Responsive.font(context, 14.5)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF2300C4)),
            filled: true,
            fillColor: const Color(0xFFF6F7FF),
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.pad(context, 14),
              vertical: Responsive.pad(context, 14),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(fieldRadius),
              borderSide: BorderSide(
                color: const Color(0xFF2300C4).withValues(alpha: 0.22),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(fieldRadius),
              borderSide: BorderSide(
                color: const Color(0xFF2300C4).withValues(alpha: 0.22),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(fieldRadius),
              borderSide: BorderSide(
                color: const Color(0xFF2300C4).withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
