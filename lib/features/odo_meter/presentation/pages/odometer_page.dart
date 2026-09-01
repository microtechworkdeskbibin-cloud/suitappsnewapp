import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suitapps/core/config/api_config.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_page.dart';
import 'package:suitapps/features/odo_meter/presentation/pages/end_odometer_page.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DESIGN SYSTEM
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class AppColors {
  static const Color primary = Color.fromARGB(255, 35, 0, 196);
  static const Color secondary = Color(0xFF6F7FDB);

  static const Color background = Color(0xFFF5F7FB);
  static const Color cardBg = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color border = Color(0xFFE5E7EB);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
}

class AppFonts {
  static TextStyle pageTitle = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle sectionTitle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static TextStyle cardValue = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
  );

  static TextStyle cardTitle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  static TextStyle buttonText = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.cardBg,
  );

  static TextStyle inputText = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle smallText = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double card = 16;
  static const double button = 12;
  static const double textField = 12;
  static const double dialog = 16;
  static const double bottomSheet = 20;
  static const double badge = 16;
}

class AppShadows {
  static BoxShadow card = BoxShadow(
    color: AppColors.textPrimary.withOpacity(0.05),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );
}

class AppIcons {
  static const double cardIcon = 16;
  static const double listTile = 20;
  static const double appBar = 24;
  static const double fab = 24;
}

class AppLayout {
  static const double screenPadding = 16;
  static const double cardGap = 8;
  static const double sectionGap = 16;
  static const double pageGap = 24;
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// ODOMETER PAGE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class OdometerPage extends StatefulWidget {
  final Map<String, dynamic> userDecoded;

  const OdometerPage({super.key, required this.userDecoded});

  @override
  State<OdometerPage> createState() => _OdometerPageState();
}

class _OdometerPageState extends State<OdometerPage> {
  final kmController = TextEditingController();

  File? photo;

  double? latitude;
  double? longitude;

  bool loading = false;
  bool checking = true;

  @override
  void initState() {
    super.initState();

    checkOdometer();
  }

  @override
  void dispose() {
    kmController.dispose();

    super.dispose();
  }

  // CHECK TODAY RECORD

  Future<void> checkOdometer() async {
    try {
      final empId = widget.userDecoded["UserId"].toString();

      debugPrint("CHECK EMPID $empId");

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/checkOdometer?EMPID=$empId'),
      );

      debugPrint("CHECK ${res.body}");

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        final exists = data["exists"] == true;
        final completed = data["completed"] == true;

          if (exists && completed) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove("OdometerID");

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardPage(
                userDecoded: widget.userDecoded,
                sessionId: "",
              ),
            ),
          );
          return;
        }

        if (exists && !completed) {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EndOdometerPage(
                userDecoded: widget.userDecoded,
              ),
            ),
          );
          return;
        }
      } else {
        msg(data["message"] ?? "Failed to check odometer status");
      }
    } catch (e) {
      debugPrint("CHECK ERROR $e");
    }

    setState(() => checking = false);
  }

  // CAMERA

  Future pickPhoto() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 30,
      maxWidth: 800,
    );

    if (img != null) {
      setState(() {
        photo = File(img.path);
      });

      debugPrint("PHOTO OK");
    }
  }

  Future<String?> image64() async {
    if (photo == null) return null;

    return base64Encode(await photo!.readAsBytes());
  }

  // GPS

  Future getGPS() async {
    LocationPermission p = await Geolocator.checkPermission();

    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    latitude = pos.latitude;

    longitude = pos.longitude;

    debugPrint("GPS $latitude $longitude");
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Shared validation for both Start and End submissions.
  // Returns the parsed KM value on success, or null (after
  // showing a message) on failure.
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  int? _validateAndParseKm() {
    final kmText = kmController.text.trim();

    if (kmText.isEmpty) {
      msg("Enter starting KM");
      return null;
    }

    final km = int.tryParse(kmText);

    if (km == null) {
      msg("KM must be a valid whole number");
      return null;
    }

    if (km <= 0) {
      msg("KM reading must be greater than 0");
      return null;
    }

    if (photo == null) {
      msg("Please take a photo of the odometer");
      return null;
    }

    return km;
  }

  // START INSERT

  Future startOdometer() async {
    if (loading) return; // prevent double-tap insert

    final km = _validateAndParseKm();
    if (km == null) return;

    setState(() => loading = true);

    try {
      await getGPS();

      // ISO 8601 so the Node route's `new Date(StartingDate)` parses
      // it unambiguously (DateTime.toString() is not standard ISO).
      final nowIso = DateTime.now().toIso8601String();

      final body = {
        "EMPID": int.parse(widget.userDecoded["UserId"].toString()),
        "StartingDate": nowIso,
        "StartingKm": km,
        "StartingPic": await image64(),
        "StartLatitude": latitude,
        "StartLongitude": longitude,
      };

      debugPrint("START BODY $body");

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/saveOdometer'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      debugPrint("START RESPONSE ${res.body}");

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();

        // Response row now comes back nested under "data"
        // (result.recordset[0]) with primary key "Id".
        final row = data["data"] as Map<String, dynamic>?;

        final int? savedId = (row?["Id"] is int)
            ? row!["Id"] as int
            : int.tryParse(row?["Id"]?.toString() ?? '');

        if (savedId != null) {
          await prefs.setInt("OdometerID", savedId);
          debugPrint("Saved OdometerID : $savedId");
        }

        msg("âœ“ Odometer started");

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              userDecoded: widget.userDecoded,
              sessionId: "",
            ),
          ),
        );
        return;
      } else {
        msg(data["message"] ?? "Failed to start odometer");
      }
    } catch (e) {
      debugPrint("START ERROR $e");

      msg("Start failed. Please try again.");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }


  void msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: AppFonts.body.copyWith(color: AppColors.cardBg),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        centerTitle: true,
        title: Text('Odometer', style: AppFonts.pageTitle),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: checking
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppLayout.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: AppLayout.sectionGap),
                  _buildKmCard(),
                  const SizedBox(height: AppLayout.sectionGap),
                  _buildPhotoCard(),
                  const SizedBox(height: AppLayout.pageGap),
                  _buildActionButton(),
                ],
              ),
            ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Status banner â€” shows whether the user is starting a
  // fresh trip or closing out one already in progress.
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStatusCard() {
    final color = AppColors.primary;
    final icon = Icons.play_circle_outline;
    final title = 'Start New Trip';
    final subtitle = 'Log your starting odometer reading';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [AppShadows.card],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppFonts.sectionTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppFonts.smallText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Text(
              'Start',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // KM input card
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildKmCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.speed_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('Starting Odometer (KM)', style: AppFonts.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: kmController,
            keyboardType: TextInputType.number,
            style: AppFonts.inputText,
            decoration: InputDecoration(
              hintText: 'Enter KM reading',
              hintStyle: AppFonts.inputText.copyWith(
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              suffixText: 'km',
              suffixStyle: AppFonts.smallText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.textField),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.textField),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.textField),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Photo capture card
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 18,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('Odometer Photo', style: AppFonts.sectionTitle),
              const Spacer(),
              if (photo != null)
                Icon(Icons.check_circle, size: 18, color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: pickPhoto,
            child: Container(
              height: 220,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: photo == null
                      ? AppColors.border
                      : AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: photo == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Tap to capture photo', style: AppFonts.body),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Required to submit', style: AppFonts.caption),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(photo!, fit: BoxFit.cover),
                        Positioned(
                          right: AppSpacing.sm,
                          bottom: AppSpacing.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(
                                AppRadius.badge,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.refresh,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Retake',
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
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Primary action button
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : startOdometer,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Start Odometer',
                    style: AppFonts.buttonText.copyWith(fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }
}
