import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:suitapps/features/auth/presentation/pages/login_page.dart';
import 'package:suitapps/features/auth/presentation/pages/dashboard_page.dart';
import 'package:suitapps/features/auth/presentation/pages/role_dashboard_page.dart';

import 'package:suitapps/shared/extensions/responsive.dart';

class SuitappsSplashPage extends StatefulWidget {
  const SuitappsSplashPage({super.key});

  @override
  State<SuitappsSplashPage> createState() =>
      _SuitappsSplashPageState();
}

class _SuitappsSplashPageState
    extends State<SuitappsSplashPage>
    with TickerProviderStateMixin {

  // ============================================================
  // DESIGN COLORS
  // ============================================================

  static const Color _primaryBlue =
      Color(0xFF1433C3);

  static const Color _secondaryBlue =
      Color(0xFF6F7FDB);


  // ============================================================
  // ANIMATION
  // ============================================================

  late AnimationController _controller;

  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _gifOpacity;
  late Animation<double> _rowOpacity;
  late Animation<double> _poweredOpacity;


  // ============================================================
  // GIF RESET
  // ============================================================

  int _gifKey = 0;

  Timer? _gifResetTimer;


  // ============================================================
  // FEATURE HIGHLIGHT
  // ============================================================

  int _activeFeature = -1;

  Timer? _featureTimer;


  // ============================================================
  // FEATURES
  // ============================================================

  static const _features = [

    {
      'image': 'assets/images/time.png',
      'title': 'Any Time'
    },

    {
      'image': 'assets/images/compass.png',
      'title': 'Any Where'
    },

    {
      'image': 'assets/images/phone.png',
      'title': 'Any Device'
    },

  ];


  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {

    super.initState();


    // ----------------------------------------------------------
    // MAIN ANIMATION
    // ----------------------------------------------------------

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 6000,
      ),
    );


    // ----------------------------------------------------------
    // LOGO OPACITY
    // ----------------------------------------------------------

    _logoOpacity =
        Tween<double>(
          begin: 0,
          end: 1,
        ).animate(

          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.05,
              0.40,
              curve: Curves.easeOut,
            ),
          ),

        );


    // ----------------------------------------------------------
    // LOGO SCALE
    // ----------------------------------------------------------

    _logoScale =
        Tween<double>(
          begin: 0.90,
          end: 1,
        ).animate(

          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.08,
              0.55,
              curve: Curves.easeOutCubic,
            ),
          ),

        );


    // ----------------------------------------------------------
    // GIF OPACITY
    // ----------------------------------------------------------

    _gifOpacity =
        Tween<double>(
          begin: 0,
          end: 1,
        ).animate(

          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.38,
              0.70,
              curve: Curves.easeOut,
            ),
          ),

        );


    // ----------------------------------------------------------
    // FEATURE ROW OPACITY
    // ----------------------------------------------------------

    _rowOpacity =
        Tween<double>(
          begin: 0,
          end: 1,
        ).animate(

          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.45,
              0.78,
              curve: Curves.easeOut,
            ),
          ),

        );


    // ----------------------------------------------------------
    // FOOTER OPACITY
    // ----------------------------------------------------------

    _poweredOpacity =
        Tween<double>(
          begin: 0,
          end: 1,
        ).animate(

          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              0.72,
              1.0,
              curve: Curves.easeOut,
            ),
          ),

        );


    // ----------------------------------------------------------
    // START ANIMATION
    // ----------------------------------------------------------

    _controller.forward();


    // ==========================================================
    // FEATURE HIGHLIGHT TIMER
    // ==========================================================

    Future.delayed(
      const Duration(
        milliseconds: 1400,
      ),
      () {

        if (!mounted) return;

        setState(() {
          _activeFeature = 0;
        });


        _featureTimer =
            Timer.periodic(
          const Duration(
            milliseconds: 1100,
          ),
          (_) {

            if (!mounted) return;

            setState(() {

              _activeFeature =
                  (_activeFeature + 1) % 3;

            });
          },
        );
      },
    );


    // ==========================================================
    // RESET GIF EVERY 3 SECONDS
    // ==========================================================

    _gifResetTimer =
        Timer.periodic(
      const Duration(
        milliseconds: 3000,
      ),
      (_) {

        if (!mounted) return;

        setState(() {
          _gifKey++;
        });
      },
    );


    // ==========================================================
    // GO TO NEXT PAGE
    // ==========================================================

    Future.delayed(
      const Duration(
        seconds: 7,
      ),
      _goNext,
    );
  }


  // ============================================================
  // GO NEXT
  // ============================================================

  Future<void> _goNext() async {

    try {

      final prefs =
          await SharedPreferences.getInstance();


      // --------------------------------------------------------
      // CHECK LOGIN STATUS
      // --------------------------------------------------------

      final logged =
          prefs.getBool(
            'isLoggedIn',
          ) ??
          false;


      // --------------------------------------------------------
      // CHECK LOGIN DATE
      // --------------------------------------------------------

      final saved =
          prefs.getString(
            'loginDate',
          ) ??
          '';


      final today =
          DateFormat(
            'yyyy-MM-dd',
          ).format(
            DateTime.now(),
          );


      debugPrint(
        '========================================',
      );

      debugPrint(
        'SPLASH LOGIN CHECK',
      );

      debugPrint(
        'isLoggedIn : $logged',
      );

      debugPrint(
        'loginDate  : $saved',
      );

      debugPrint(
        'today      : $today',
      );

      debugPrint(
        '========================================',
      );


      // ========================================================
      // ALREADY LOGGED IN TODAY
      // ========================================================

      if (logged && saved == today) {

        Map<String, dynamic> user = {};


        // ------------------------------------------------------
        // GET SAVED USER
        // ------------------------------------------------------

        final savedUser =
            prefs.getString(
              'user',
            ) ??
            '{}';


        debugPrint(
          '========================================',
        );

        debugPrint(
          'SAVED USER DATA',
        );

        debugPrint(
          savedUser,
        );

        debugPrint(
          '========================================',
        );


        // ------------------------------------------------------
        // DECODE USER
        // ------------------------------------------------------

        try {

          final decoded =
              jsonDecode(
                savedUser,
              );


          if (decoded is Map) {

            user =
                Map<String, dynamic>.from(
              decoded,
            );
          }

        } catch (e) {

          debugPrint(
            'USER JSON ERROR: $e',
          );

          user = {};
        }


        // ------------------------------------------------------
        // DEBUG USER INFORMATION
        // ------------------------------------------------------

        debugPrint(
          '========================================',
        );

        debugPrint(
          'ROLE INFORMATION',
        );

        debugPrint(
          'UserId       : ${user['UserId']}',
        );

        debugPrint(
          'Name         : ${user['Name']}',
        );

        debugPrint(
          'UserRoleId   : ${user['UserRoleId']}',
        );

        debugPrint(
          'UserRoleName : ${user['UserRoleName']}',
        );

        debugPrint(
          'RoleName     : ${user['RoleName']}',
        );

        debugPrint(
          'CompanyID    : ${user['CompanyID']}',
        );

        debugPrint(
          '========================================',
        );


        // ======================================================
        // CHECK USER DATA
        // ======================================================

        if (user.isEmpty) {

          debugPrint(
            'NO USER DATA FOUND',
          );


          await prefs.clear();


          if (!mounted) return;


          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const LoginPage(),
            ),
          );

          return;
        }


        // ======================================================
        // OPEN ROLE DASHBOARD
        // ======================================================

        if (!mounted) return;


        debugPrint(
          'OPENING ROLE DASHBOARD',
        );


        Navigator.pushReplacement(
          context,

          MaterialPageRoute(
            builder: (_) =>
                DashboardPage(
              userDecoded: user,

              sessionId:
                  prefs.getString(
                    'sessionId',
                  ) ??
                  '',
            ),
          ),
        );


        return;
      }


      // ========================================================
      // LOGIN EXPIRED / NOT LOGGED IN
      // ========================================================

      debugPrint(
        'LOGIN EXPIRED OR USER NOT LOGGED IN',
      );


      await prefs.clear();


      if (!mounted) return;


      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
          builder: (_) =>
              const LoginPage(),
        ),
      );

    } catch (e) {

      // ========================================================
      // SPLASH ERROR
      // ========================================================

      debugPrint(
        'Splash navigation error: $e',
      );


      if (!mounted) return;


      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
          builder: (_) =>
              const LoginPage(),
        ),
      );
    }
  }


  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {

    _gifResetTimer?.cancel();

    _featureTimer?.cancel();

    _controller.dispose();

    super.dispose();
  }


  // ============================================================
  // FEATURE ITEM
  // ============================================================

  Widget _featureItem(
    BuildContext context,
    int index,
  ) {

    final active =
        _activeFeature == index;


    final iconSize =
        (
          Responsive.w(context) * 0.13
        ).clamp(
          42.0,
          68.0,
        );


    return Expanded(

      child: AnimatedScale(

        scale:
            active
                ? 1.13
                : 1.0,

        duration:
            const Duration(
              milliseconds: 380,
            ),

        curve:
            Curves.easeOutCubic,

        child: AnimatedOpacity(

          opacity:
              _activeFeature == -1
                  ? 0.75
                  : (
                      active
                          ? 1.0
                          : 0.38
                    ),

          duration:
              const Duration(
                milliseconds: 380,
              ),

          child: Column(

            mainAxisSize:
                MainAxisSize.min,

            children: [

              // ------------------------------------------------
              // ICON
              // ------------------------------------------------

              AnimatedContainer(

                duration:
                    const Duration(
                      milliseconds: 380,
                    ),

                curve:
                    Curves.easeOutCubic,

                width:
                    iconSize,

                height:
                    iconSize,

                decoration:
                    BoxDecoration(

                  shape:
                      BoxShape.circle,

                  color:
                      active
                          ? _primaryBlue
                              .withOpacity(
                                0.09,
                              )
                          : Colors.transparent,

                  border:
                      Border.all(

                    color:
                        active
                            ? _secondaryBlue
                                .withOpacity(
                                  0.55,
                                )
                            : Colors.transparent,

                    width: 1.5,
                  ),
                ),

                padding:
                    const EdgeInsets.all(
                      8,
                    ),

                child:
                    Image.asset(

                  _features[index]['image']!,

                  fit:
                      BoxFit.contain,

                  cacheWidth:
                      144,
                ),
              ),


              const SizedBox(
                height: 7,
              ),


              // ------------------------------------------------
              // LABEL
              // ------------------------------------------------

              AnimatedDefaultTextStyle(

                duration:
                    const Duration(
                      milliseconds: 380,
                    ),

                curve:
                    Curves.easeOutCubic,

                style:
                    TextStyle(

                  fontFamily:
                      'Inter',

                  fontSize:
                      Responsive.font(
                    context,
                    13,
                  ),

                  fontWeight:
                      FontWeight.w700,

                  letterSpacing:
                      0.2,

                  color:
                      active
                          ? _primaryBlue
                          : _secondaryBlue,
                ),

                child:
                    Text(

                  _features[index]['title']!,

                  textAlign:
                      TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    final logoWidth =
        (
          Responsive.w(context) * 0.60
        ).clamp(
          220.0,
          340.0,
        );


    final gifWidth =
        (
          Responsive.w(context) * 0.72
        ).clamp(
          200.0,
          380.0,
        );


    return Scaffold(

      backgroundColor:
          Colors.white,

      body:

          SafeArea(

        child:

            Padding(

          padding:
              EdgeInsets.symmetric(

            horizontal:
                Responsive.pad(
              context,
              24,
            ),
          ),

          child:

              Column(

            children: [

              // =================================================
              // TOP SPACE
              // =================================================

              const Spacer(
                flex: 15,
              ),


              // =================================================
              // LOGO
              // =================================================

              FadeTransition(

                opacity:
                    _logoOpacity,

                child:

                    ScaleTransition(

                  scale:
                      _logoScale,

                  child:
                      Image.asset(

                    'assets/images/sp-logo.png',

                    width:
                        logoWidth,

                    fit:
                        BoxFit.contain,
                  ),
                ),
              ),


              // =================================================
              // LOGO → GIF SPACE
              // =================================================

              SizedBox(
                height:
                    Responsive.pad(
                  context,
                  36,
                ),
              ),


              // =================================================
              // GIF
              // =================================================

              FadeTransition(

                opacity:
                    _gifOpacity,

                child:
                    Image.asset(

                  'assets/images/gifloading.gif',

                  key:
                      ValueKey(
                    _gifKey,
                  ),

                  width:
                      gifWidth,

                  fit:
                      BoxFit.contain,

                  cacheWidth:
                      600,
                ),
              ),


              // =================================================
              // GIF → FEATURES
              // =================================================

              SizedBox(
                height:
                    Responsive.pad(
                  context,
                  32,
                ),
              ),


              // =================================================
              // FEATURES
              // =================================================

              FadeTransition(

                opacity:
                    _rowOpacity,

                child:

                    Row(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children:

                      List.generate(
                    3,

                    (i) =>
                        _featureItem(
                      context,
                      i,
                    ),
                  ),
                ),
              ),


              // =================================================
              // BOTTOM SPACE
              // =================================================

              const Spacer(
                flex: 20,
              ),


              // =================================================
              // FOOTER
              // =================================================

              FadeTransition(

                opacity:
                    _poweredOpacity,

                child:

                    Padding(

                  padding:
                      EdgeInsets.only(

                    bottom:
                        Responsive.pad(
                      context,
                      24,
                    ),
                  ),

                  child:

                      Text(

                    'MICROTECH SOFTWARE SOLUTIONS',

                    style:
                        TextStyle(

                      fontFamily:
                          'Inter',

                      fontSize:
                          Responsive.font(
                        context,
                        11,
                      ),

                      fontWeight:
                          FontWeight.w700,

                      letterSpacing:
                          1.4,

                      color:
                          _secondaryBlue,
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