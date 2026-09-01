import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:suitapps/features/auth/presentation/pages/login_page.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_page.dart';
import 'package:suitapps/shared/extensions/responsive.dart';

// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';

// import 'package:suitapps/features/auth/presentation/pages/login_page.dart';
// import 'package:suitapps/features/auth/presentation/pages/dashboard_page.dart';
// import 'package:suitapps/shared/extensions/responsive.dart';

// class SuitappsSplashPage extends StatefulWidget {
//   const SuitappsSplashPage({super.key});

//   @override
//   State<SuitappsSplashPage> createState() => _SuitappsSplashPageState();
// }

// class _SuitappsSplashPageState extends State<SuitappsSplashPage>
//     with SingleTickerProviderStateMixin {
//   static const Color brandBlue = Color(0xFF2300C4);

//   late final AnimationController _controller;

//   late final Animation<double> _logoOpacity;
//   late final Animation<double> _logoScale;

//   late final Animation<double> _copyOpacity;
//   late final Animation<Offset> _copySlide;

//   late final Animation<double> _poweredOpacity;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 6000),
//     );

//     _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.05, 0.40, curve: Curves.easeOut),
//       ),
//     );

//     _logoScale = Tween<double>(begin: 0.90, end: 1).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.08, 0.55, curve: Curves.easeOutCubic),
//       ),
//     );

//     _copyOpacity = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.45, 0.85, curve: Curves.easeOutQuart),
//       ),
//     );

//     _copySlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
//         .animate(
//           CurvedAnimation(
//             parent: _controller,
//             curve: const Interval(0.45, 0.85, curve: Curves.easeOutQuart),
//           ),
//         );

//     _poweredOpacity = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: const Interval(0.72, 1.0, curve: Curves.easeOut),
//       ),
//     );

//     _controller.forward();
//     Future.delayed(const Duration(milliseconds: 7000), _goNext);
//   }

//   Future<void> _goNext() async {
//     final prefs = await SharedPreferences.getInstance();

//     final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
//     final savedDate = prefs.getString('loginDate') ?? '';
//     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

//     if (isLoggedIn && savedDate == today) {
//       final userStr = prefs.getString('user') ?? '{}';
//       Map<String, dynamic> userDecoded;
//       try {
//         userDecoded = jsonDecode(userStr) as Map<String, dynamic>;
//       } catch (_) {
//         userDecoded = {};
//       }

//       final sessionId = prefs.getString('sessionId') ?? '';

//       if (!mounted) return;
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) =>
//               DashboardPage(userDecoded: userDecoded, sessionId: sessionId),
//         ),
//       );
//       return;
//     }

//     await prefs.remove('isLoggedIn');
//     await prefs.remove('loginDate');
//     await prefs.remove('sessionId');
//     await prefs.remove('user');

//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => const LoginPage()),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenW = Responsive.w(context);

//     // âœ… Smooth responsive padding
//     final double horizontalPad = Responsive.pad(context, 24.0);
//     final double bottomPad = Responsive.pad(context, 24.0);

//     // âœ… Auto logo width (percentage + clamp)
//     final double logoMaxWidth = (screenW * 0.60).clamp(220.0, 340.0);

//     final double gapAfterLogo = Responsive.pad(context, 45.0);
//     final double gapTitleToSub = Responsive.pad(context, 10.0);

//     // âœ… Smooth responsive font sizes
//     final double titleSize = Responsive.font(context, 22.0);
//     final double subTitleSize = Responsive.font(context, 16.0);
//     final double smallTextSize = Responsive.font(context, 12.0);

//     // âœ… Limit text line width for better readability (and prevents overflow)
//     final double textMaxWidth = (screenW * 0.92).clamp(320.0, 520.0);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: horizontalPad),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               const Spacer(flex: 18),

//               // LOGO
//               Center(
//                 child: FadeTransition(
//                   opacity: _logoOpacity,
//                   child: ScaleTransition(
//                     scale: _logoScale,
//                     child: ConstrainedBox(
//                       constraints: BoxConstraints(maxWidth: logoMaxWidth),
//                       child: Image.asset(
//                         'assets/images/sp-logo.png',
//                         fit: BoxFit.contain,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),

//               SizedBox(height: gapAfterLogo),

//               // TEXT
//               Center(
//                 child: ConstrainedBox(
//                   constraints: BoxConstraints(maxWidth: textMaxWidth),
//                   child: FadeTransition(
//                     opacity: _copyOpacity,
//                     child: SlideTransition(
//                       position: _copySlide,
//                       // child: Column(
//                       //   crossAxisAlignment: CrossAxisAlignment.center,
//                       //   children: [
//                       //     Text(
//                       //       'Boost your field sales with SFA automation',
//                       //       textAlign: TextAlign.center,
//                       //       style: TextStyle(
//                       //         color: brandBlue,
//                       //         fontSize: titleSize,
//                       //         fontWeight: FontWeight.w800,
//                       //         height: 1.18,
//                       //         letterSpacing: -0.2,
//                       //       ),
//                       //     ),
//                       //     SizedBox(height: gapTitleToSub),
//                       //     Text(
//                       //       'Track visits, manage leads, and close faster all in SUITAPPS.',
//                       //       textAlign: TextAlign.center,
//                       //       style: TextStyle(
//                       //         color: Colors.black.withValues(alpha: 0.68),
//                       //         fontSize: subTitleSize,
//                       //         fontWeight: FontWeight.w600,
//                       //         height: 1.45,
//                       //       ),
//                       //     ),
//                       //   ],
//                       // ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         children: [
//                           ConstrainedBox(
//                             constraints: BoxConstraints(maxWidth: logoMaxWidth),
//                             child: Image.asset(
//                               'assets/images/gifloading.gif',
//                               fit: BoxFit.contain,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),

//               const Spacer(flex: 22),

//               // POWERED BY
//               Padding(
//                 padding: EdgeInsets.only(bottom: bottomPad),
//                 child: Center(
//                   child: FadeTransition(
//                     opacity: _poweredOpacity,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         Text(
//                           'Powered by',
//                           style: TextStyle(
//                             fontSize: smallTextSize,
//                             color: Colors.grey,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         SizedBox(height: Responsive.pad(context, 4.0)),
//                         Text(
//                           'MICROTECH SOFTWARE SOLUTIONS',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             fontSize: smallTextSize,
//                             fontWeight: FontWeight.w700,
//                             letterSpacing: 1.2,
//                             color: Colors.black,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




class SuitappsSplashPage extends StatefulWidget {
  const SuitappsSplashPage({super.key});

  @override
  State<SuitappsSplashPage> createState() =>
      _SuitappsSplashPageState();
}


class _SuitappsSplashPageState
    extends State<SuitappsSplashPage>
    with TickerProviderStateMixin {

  // â”€â”€ Design tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const Color _primaryBlue   = Color(0xFF1433C3);
  static const Color _secondaryBlue = Color(0xFF6F7FDB);

  // Main entrance animation
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _gifOpacity;
  late Animation<double> _rowOpacity;
  late Animation<double> _poweredOpacity;

  // GIF reset key
  int _gifKey = 0;
  Timer? _gifResetTimer;

  // Highlight index (-1 = none yet)
  int _activeFeature = -1;
  Timer? _featureTimer;

  static const _features = [
    {'image': 'assets/images/time.png',    'title': 'Any Time'},
    {'image': 'assets/images/compass.png', 'title': 'Any Where'},
    {'image': 'assets/images/phone.png',   'title': 'Any Device'},
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.40, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.90, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _gifOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.70, curve: Curves.easeOut),
      ),
    );

    _rowOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.78, curve: Curves.easeOut),
      ),
    );

    _poweredOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.72, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Highlight cycles 0 â†’ 1 â†’ 2 â†’ 0 â€¦ after short delay
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _activeFeature = 0);

      _featureTimer = Timer.periodic(
        const Duration(milliseconds: 1100),
        (_) {
          if (!mounted) return;
          setState(() => _activeFeature = (_activeFeature + 1) % 3);
        },
      );
    });

    // Reset GIF every 3 s
    _gifResetTimer = Timer.periodic(
      const Duration(milliseconds: 3000),
      (_) {
        if (!mounted) return;
        setState(() => _gifKey++);
      },
    );

    Future.delayed(const Duration(seconds: 7), _goNext);
  }


  Future<void> _goNext() async {
    final prefs  = await SharedPreferences.getInstance();
    final logged = prefs.getBool('isLoggedIn') ?? false;
    final saved  = prefs.getString('loginDate') ?? '';
    final today  = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (logged && saved == today) {
      Map<String, dynamic> user = {};
      try { user = jsonDecode(prefs.getString('user') ?? '{}'); } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            userDecoded: user,
            sessionId: prefs.getString('sessionId') ?? '',
          ),
        ),
      );
      return;
    }

    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }


  @override
  void dispose() {
    _gifResetTimer?.cancel();
    _featureTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }


  Widget _featureItem(BuildContext context, int index) {
    final active   = _activeFeature == index;
    final iconSize = (Responsive.w(context) * 0.13).clamp(42.0, 68.0);

    return Expanded(
      child: AnimatedScale(
        scale: active ? 1.13 : 1.0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _activeFeature == -1 ? 0.75 : (active ? 1.0 : 0.38),
          duration: const Duration(milliseconds: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with animated highlight ring using brand colours
              AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? _primaryBlue.withOpacity(0.09)
                      : Colors.transparent,
                  border: Border.all(
                    color: active
                        ? _secondaryBlue.withOpacity(0.55)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  _features[index]['image']!,
                  fit: BoxFit.contain,
                  cacheWidth: 144,
                ),
              ),

              const SizedBox(height: 7),

              // Label in Primary Blue when active, Secondary Blue when not
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  // Inter â€” ensure Inter is in your pubspec fonts
                  fontFamily: 'Inter',
                  fontSize: Responsive.font(context, 13),
                  // Card Title spec: 12/W700 â€” closest match for this label
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: active ? _primaryBlue : _secondaryBlue,
                ),
                child: Text(
                  _features[index]['title']!,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final logoWidth = (Responsive.w(context) * 0.60).clamp(220.0, 340.0);
    final gifWidth  = (Responsive.w(context) * 0.72).clamp(200.0, 380.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.pad(context, 24),
          ),
          child: Column(
            children: [

              const Spacer(flex: 15),

              // â”€â”€ Logo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Image.asset(
                    'assets/images/sp-logo.png',
                    width: logoWidth,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              SizedBox(height: Responsive.pad(context, 36)),

              // â”€â”€ GIF â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              FadeTransition(
                opacity: _gifOpacity,
                child: Image.asset(
                  'assets/images/gifloading.gif',
                  key: ValueKey(_gifKey),
                  width: gifWidth,
                  fit: BoxFit.contain,
                  cacheWidth: 600,
                ),
              ),

              SizedBox(height: Responsive.pad(context, 32)),

              // â”€â”€ Feature row â€” all 3 appear together â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              FadeTransition(
                opacity: _rowOpacity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    3,
                    (i) => _featureItem(context, i),
                  ),
                ),
              ),

              const Spacer(flex: 20),

              // â”€â”€ Footer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              FadeTransition(
                opacity: _poweredOpacity,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: Responsive.pad(context, 24),
                  ),
                  child: Text(
                    'MICROTECH SOFTWARE SOLUTIONS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: Responsive.font(context, 11),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _secondaryBlue,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
