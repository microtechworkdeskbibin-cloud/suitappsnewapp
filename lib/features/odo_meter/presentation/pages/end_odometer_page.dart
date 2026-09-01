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
import 'package:suitapps/features/odo_meter/presentation/pages/odometer_page.dart';

class EndOdometerPage extends StatefulWidget {

  final Map<String, dynamic>? userDecoded;

  const EndOdometerPage({super.key, this.userDecoded});

  @override
  State<EndOdometerPage> createState() => _EndOdometerPageState();
}

class _EndOdometerPageState extends State<EndOdometerPage> {
  final kmController = TextEditingController();

  File? photo;

  double? lat;
  double? lng;

  bool loading = false;

  // No /checkOdometer call â€” the app's own navigation already prevents
  // reaching this page unless today's trip is open (dashboard is
  // blocked until odometer is marked complete), so we trust that and
  // POST straight to /saveOdometer as an end-of-trip update.
  String? empId;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    kmController.dispose();
    super.dispose();
  }

  Future<void> init() async {
    // Prefer the value passed in; fall back to SharedPreferences when
    // this page is opened without arguments (e.g. from AppDrawer).
    empId = widget.userDecoded?["UserId"]?.toString();

    if (empId == null || empId!.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      empId = prefs.get("UserId")?.toString();
    }

    if (empId == null || empId!.isEmpty) {
      msg("Session expired. Please login again.");
    }

    setState(() {});
  }

  // ---------------- IMAGE ----------------
  Future<void> pickPhoto() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 30,
      maxWidth: 800,
    );

    if (img != null) {
      setState(() => photo = File(img.path));
    }
  }

  Future<String?> getImage() async {
    if (photo == null) return null;
    return base64Encode(await photo!.readAsBytes());
  }

  // ---------------- GPS ----------------
  Future<void> getGPS() async {
    LocationPermission p = await Geolocator.checkPermission();

    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    lat = pos.latitude;
    lng = pos.longitude;

    debugPrint("GPS $lat $lng");
  }

  // ---------------- VALIDATION ----------------
  // Returns the parsed KM value on success, or null (after showing a
  // message) on failure. Kept as its own method so submitEnd() can
  // bail out before touching loading/GPS/network at all.
  int? _validateAndParseKm() {
    if (empId == null || empId!.isEmpty) {
      msg("Session expired. Login again.");
      return null;
    }

    final kmText = kmController.text.trim();

    if (kmText.isEmpty) {
      msg("Enter ending KM");
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
      msg("Please take a photo of the ending odometer");
      return null;
    }

    return km;
  }

  // ---------------- END ODOMETER ----------------
  Future<void> submitEnd() async {
    if (loading) return; // prevent double-tap insert

    final km = _validateAndParseKm();
    if (km == null) return;

    setState(() => loading = true);

    try {
      await getGPS();

      final nowIso = DateTime.now().toIso8601String();

      final body = {
        "EMPID": int.parse(empId!),
        // The SP finds today's row via EMPID + CAST(StartingDate AS
        // DATE) â€” only the date part matters, so "now" is fine as
        // long as this is submitted the same calendar day the trip
        // started.
        "StartingDate": nowIso,
        // Required by the route's validation on every call; the SP's
        // UPDATE branch ignores this value, so it's just a placeholder.
        "StartingKm": km,
        "EndingDate": nowIso,
        "EndingKm": km,
        "EndingPic": await getImage(),
        "EndLatitude": lat,
        "EndLongitude": lng,
      };

      debugPrint("END BODY $body");

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/saveOdometer'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      debugPrint("END RESPONSE ${res.body}");

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove("OdometerID");

        msg("âœ“ Odometer completed");

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              userDecoded: widget.userDecoded ?? {"UserId": empId},
              sessionId: "",
            ),
          ),
        );
        return; // already navigated away â€” skip resetting loading below
      } else {
        // Covers SP validation errors too, e.g. "Ending KM must be
        // greater than Starting KM." (raised via RAISERROR 50000,
        // returned by the route as a 400 with `message` set).
        msg(data["message"] ?? "Failed to submit odometer");
      }
    } catch (e) {
      debugPrint("END ERROR $e");
      msg("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void msg(String text) {
    if (!mounted) return;

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

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        centerTitle: true,
        title: Text('End Odometer', style: AppFonts.pageTitle),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
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
  // Status banner
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStatusCard() {
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
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: AppColors.warning,
              size: AppIcons.appBar,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trip In Progress', style: AppFonts.sectionTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Log your ending odometer reading',
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
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Text(
              'End',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
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
                  size: AppIcons.cardIcon,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('Ending Odometer (KM)', style: AppFonts.sectionTitle),
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
                  size: AppIcons.cardIcon,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('Odometer Photo', style: AppFonts.sectionTitle),
              const Spacer(),
              if (photo != null)
                const Icon(
                  Icons.check_circle,
                  size: AppIcons.cardIcon,
                  color: AppColors.success,
                ),
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
                            borderRadius: BorderRadius.circular(
                              AppRadius.card,
                            ),
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
        onPressed: loading ? null : submitEnd,
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
                    Icons.flag_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'End Odometer',
                    style: AppFonts.buttonText.copyWith(fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }
}
