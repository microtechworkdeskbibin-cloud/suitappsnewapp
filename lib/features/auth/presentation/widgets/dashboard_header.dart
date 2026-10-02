import 'package:flutter/material.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_constants.dart';
import 'package:suitapps/shared/extensions/responsive.dart'; // adjust path to your Responsive file

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.name,
    required this.dateText,
    this.profileImageUrl,
    this.profileImageAssetPath,
    this.onMenuTap,
    this.onProfileTap,
  });

  final String name;
  final String dateText;

  final String? profileImageUrl; // network image
  final String? profileImageAssetPath; // fallback asset (logo)

  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;

  String _getGreetingByTime() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "Good Morning";
    if (hour >= 12 && hour < 17) return "Good Afternoon";
    if (hour >= 17 && hour < 21) return "Good Evening";
    return "Good Night";
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreetingByTime();

    // Responsive values
    final double pad = Responsive.pad(context, 10.0);
    final double iconPad = Responsive.pad(context, 6.0);
    final double iconSize = Responsive.scale(context, 32.0);

    final double greetFont = Responsive.font(context, 16.0);
    final double dateFont = Responsive.font(context, 12.0);

    final double gapW = Responsive.pad(context, 12.0);

    final double avatarSize = Responsive.scale(context, 52.0); // outer circle
    final double avatarRing = Responsive.pad(context, 5.0); // white ring
    final double menuRadius = Responsive.radius(context, 12.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT: menu icon (fixed size)
          InkWell(
            onTap: onMenuTap,
            borderRadius: BorderRadius.circular(menuRadius),
            child: Padding(
              padding: EdgeInsets.all(iconPad),
              child: Icon(Icons.segment, color: Colors.white, size: iconSize),
            ),
          ),

          // MIDDLE: greeting + date, allowed to shrink and truncate
          // instead of forcing the Row wider than the screen.
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gapW / 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: greetFont,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(text: "$greeting, "),
                        TextSpan(
                          text: name.isEmpty ? "User" : name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.pad(context, 2.0)),
                  Text(
                    dateText,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: dateFont,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT: profile image (fixed size, click opens profile page)
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: EdgeInsets.all(avatarRing),
              child: ClipOval(
                child: _AvatarImage(
                  imageUrl: profileImageUrl,
                  assetPath: profileImageAssetPath,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.imageUrl, required this.assetPath});

  final String? imageUrl;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    if (assetPath != null && assetPath!.trim().isNotEmpty) {
      return Image.asset(assetPath!, fit: BoxFit.cover);
    }

    return Container(
      color: const Color(0xFFEAF0FF),
      child: Icon(
        Icons.person_rounded,
        color: DashboardConstants.brandBlue,
        size: Responsive.scale(context, 24.0),
      ),
    );
  }
}