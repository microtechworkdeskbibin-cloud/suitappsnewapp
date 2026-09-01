import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/features/odo_meter/presentation/pages/odometer_page.dart';

// import '../dashboard_page.dart';

// â”€â”€â”€ Design Tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _C {
  static const primaryBlue = Color(0xFF1433C3);
  static const secondaryBlue = Color(0xFF6F7FDB);
  static const background = Color(0xFFF5F7FB);
  static const cardBg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
}

class _R {
  static const card = 16.0;
  static const button = 12.0;
  static const textField = 12.0;
}

class _Sp {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: _C.cardBg,
  borderRadius: BorderRadius.circular(_R.card),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

// â”€â”€â”€ Page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AttendancePage extends StatefulWidget {
  final Map<String, dynamic> userDecoded;
  final String sessionId;

  const AttendancePage({
    super.key,
    required this.userDecoded,
    required this.sessionId,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool loading = true;
  bool submitting = false;

  List attendanceTypes = [];
  int? selectedAttendanceTypeId;

  final TextEditingController remarksController = TextEditingController();
  File? attendancePhoto;

  @override
  void initState() {
    super.initState();
    loadAttendanceTypes();
  }

  @override
  void dispose() {
    remarksController.dispose();
    super.dispose();
  }

  // â”€â”€â”€ Data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> loadAttendanceTypes() async {
    try {
      final companyId = widget.userDecoded["CompanyID"].toString();
      final response = await http.get(
        Uri.parse(
         '${ApiConfig.baseUrl}${ApiConfig.getAttendanceTypes}?CompanyID=$companyId',
        ),
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        attendanceTypes = data["data"] ?? [];
        if (attendanceTypes.isNotEmpty) {
          final presentType = attendanceTypes.firstWhere(
            (e) => e["TypeName"].toString().toLowerCase() == "present",
            orElse: () => attendanceTypes.first,
          );
          selectedAttendanceTypeId = presentType["AttendanceTypeID"];
        }
      }
    } catch (e) {
      debugPrint("Attendance Type Error: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pickPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) setState(() => attendancePhoto = File(image.path));
    } catch (e) {
      debugPrint("Photo Error: $e");
    }
  }

  Future<String?> getPhotoBase64() async {
    if (attendancePhoto == null) return null;
    final bytes = await attendancePhoto!.readAsBytes();
    return base64Encode(bytes);
  }

  Future<String> getAddress(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isNotEmpty) {
        final p = places.first;
        return [
          p.name,
          p.street,
          p.locality,
          p.administrativeArea,
          p.country,
        ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
      }
    } catch (_) {}
    return '';
  }

  Future<void> markAttendance() async {
    if (selectedAttendanceTypeId == null) {
      _showSnack("Please select an attendance type.", isError: true);
      return;
    }

    setState(() => submitting = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permission denied");
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final address = await getAddress(position.latitude, position.longitude);
      final photoB64 = await getPhotoBase64();

      final selectedType = attendanceTypes.firstWhere(
        (e) => e["AttendanceTypeID"] == selectedAttendanceTypeId,
      );

      final payload = {
        "CompanyID": int.parse(widget.userDecoded["CompanyID"].toString()),
        "EmployeeID": int.parse(widget.userDecoded["UserId"].toString()),
        "AttendanceTypeID": selectedAttendanceTypeId,
        // "AttendanceDate": DateTime.now().toIso8601String().split('T')[0],
        // "CheckInTime": DateTime.now().toString(),
        "CheckInLatitude": position.latitude.toString(),
        "CheckInLongitude": position.longitude.toString(),
        "CheckInAddress": address,
        "CheckInPhotoURL": photoB64 ?? "",
        "CheckOutTime": null,
        "CheckOutLatitude": null,
        "CheckOutLongitude": null,
        "CheckOutAddress": null,
        "CheckOutPhotoURL": null,
        "Remarks": remarksController.text.trim(),
        "Status": selectedType["TypeName"].toString(),
        "CreatedBy": widget.userDecoded["Name"].toString(),
        "Geoplace": address,
        "UserRoleId": int.parse(widget.userDecoded["UserRoleId"].toString()),
        "SuitAppID": "FlutterApp",
      };

      final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.insertEmployeeAttendance}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) throw Exception(response.body);

      final result = jsonDecode(response.body);

      // if (result["success"] == true) {
      //   if (!mounted) return;
      //   Navigator.pushReplacement(
      //     context,
      //     MaterialPageRoute(
      //       builder: (_) => DashboardPage(
      //         userDecoded: widget.userDecoded,
      //         sessionId: widget.sessionId,
      //       ),
      //     ),
      //   );
      // } 
      if (result["success"] == true) {

  if (!mounted) return;


  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => OdometerPage(
        userDecoded: widget.userDecoded,
      ),
    ),
  );

}
      
      else {
        throw Exception(result["message"] ?? "Attendance failed");
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }

    if (mounted) setState(() => submitting = false);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? _C.error : _C.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_R.button),
        ),
        margin: const EdgeInsets.all(_Sp.lg),
      ),
    );
  }

  // â”€â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.background,
      appBar: _buildAppBar(),
      body: loading
          ? _buildLoader()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(_Sp.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(),
                  const SizedBox(height: _Sp.xl),
                  _buildTypeSection(),
                  const SizedBox(height: _Sp.lg),
                  _buildRemarksSection(),
                  const SizedBox(height: _Sp.lg),
                  _buildPhotoSection(),
                  const SizedBox(height: _Sp.xxl),
                  _buildSubmitButton(),
                  const SizedBox(height: _Sp.xl),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.cardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: _C.textPrimary,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        "Mark Attendance",
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _C.textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(_C.primaryBlue),
        strokeWidth: 2.5,
      ),
    );
  }

  Widget _buildGreeting() {
    final name =
        widget.userDecoded["Name"]?.toString().split(" ").first ?? "there";
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? "Good morning"
        : hour < 17
        ? "Good afternoon"
        : "Good evening";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$greeting, $name ðŸ‘‹",
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: _Sp.xs),
        Text(
          _formatDate(now),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _C.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return "${days[dt.weekday % 7]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}";
  }

  Widget _buildTypeSection() {
    return _SectionCard(
      label: "Attendance Type",
      icon: Icons.checklist_rounded,
      child: DropdownButtonFormField<int>(
        value: selectedAttendanceTypeId,
        decoration: InputDecoration(
          hintText: "Select type",
          hintStyle: GoogleFonts.inter(fontSize: 14, color: _C.textSecondary),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: _Sp.md,
            vertical: _Sp.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_R.textField),
            borderSide: const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_R.textField),
            borderSide: const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_R.textField),
            borderSide: const BorderSide(color: _C.primaryBlue, width: 1.5),
          ),
          filled: true,
          fillColor: _C.background,
        ),
        style: GoogleFonts.inter(fontSize: 14, color: _C.textPrimary),
        dropdownColor: _C.cardBg,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _C.textSecondary,
        ),
        items: attendanceTypes.map<DropdownMenuItem<int>>((e) {
          final name = e["TypeName"].toString();
          return DropdownMenuItem<int>(
            value: e["AttendanceTypeID"],
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _typeColor(name),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: _Sp.sm),
                Text(
                  name,
                  style: GoogleFonts.inter(fontSize: 14, color: _C.textPrimary),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (v) => setState(() => selectedAttendanceTypeId = v),
      ),
    );
  }

  Color _typeColor(String name) {
    switch (name.toLowerCase()) {
      case 'present':
        return _C.success;
      case 'absent':
        return _C.error;
      case 'leave':
        return _C.warning;
      default:
        return _C.secondaryBlue;
    }
  }

  Widget _buildRemarksSection() {
    return _SectionCard(
      label: "Remarks",
      icon: Icons.notes_rounded,
      child: TextField(
        controller: remarksController,
        maxLines: 3,
        style: GoogleFonts.inter(fontSize: 14, color: _C.textPrimary),
        decoration: InputDecoration(
          hintText: "Add a note (optional)",
          hintStyle: GoogleFonts.inter(fontSize: 14, color: _C.textSecondary),
          contentPadding: const EdgeInsets.all(_Sp.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_R.textField),
            borderSide: const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_R.textField),
            borderSide: const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_R.textField),
            borderSide: const BorderSide(color: _C.primaryBlue, width: 1.5),
          ),
          filled: true,
          fillColor: _C.background,
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return _SectionCard(
      label: "Photo Verification",
      icon: Icons.camera_alt_rounded,
      child: GestureDetector(
        onTap: pickPhoto,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: attendancePhoto == null ? _C.background : Colors.transparent,
            borderRadius: BorderRadius.circular(_R.textField),
            border: Border.all(
              color: attendancePhoto == null ? _C.border : _C.primaryBlue,
              width: attendancePhoto == null ? 1.5 : 2,
              style: attendancePhoto == null
                  ? BorderStyle.solid
                  : BorderStyle.solid,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: attendancePhoto == null
              ? _buildPhotoPlaceholder()
              : _buildPhotoPreview(),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(_Sp.md),
          decoration: BoxDecoration(
            color: _C.primaryBlue.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            size: 28,
            color: _C.primaryBlue,
          ),
        ),
        const SizedBox(height: _Sp.sm),
        Text(
          "Tap to capture photo",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _C.primaryBlue,
          ),
        ),
        const SizedBox(height: _Sp.xs),
        Text(
          "Required for attendance verification",
          style: GoogleFonts.inter(fontSize: 11, color: _C.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(attendancePhoto!, fit: BoxFit.cover),
        Positioned(
          top: _Sp.sm,
          right: _Sp.sm,
          child: GestureDetector(
            onTap: pickPhoto,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _Sp.sm,
                vertical: _Sp.xs,
              ),
              decoration: BoxDecoration(
                color: _C.primaryBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: _Sp.xs),
                  Text(
                    "Retake",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: submitting ? null : markAttendance,
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.primaryBlue,
          disabledBackgroundColor: _C.secondaryBlue.withOpacity(0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_R.button),
          ),
        ),
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 20),
                  const SizedBox(width: _Sp.sm),
                  Text(
                    "Mark Attendance",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// â”€â”€â”€ Section Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.label,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(_Sp.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _C.primaryBlue),
              const SizedBox(width: _Sp.xs),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _C.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: _Sp.md),
          child,
        ],
      ),
    );
  }
}
