import 'dart:math' as math;
import 'package:flutter/material.dart';

class Responsive {
  /// Choose a design size (what your UI was designed on).
  /// Most Flutter UIs are designed around 375x812 (iPhone X/11/12/13/14 base).
  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  static MediaQueryData mq(BuildContext context) => MediaQuery.of(context);
  static Size size(BuildContext context) => mq(context).size;

  static double w(BuildContext context) => size(context).width;
  static double h(BuildContext context) => size(context).height;

  /// Continuous width scale relative to design width
  static double _ws(BuildContext context) => w(context) / _designWidth;

  /// Continuous height scale relative to design height
  static double _hs(BuildContext context) => h(context) / _designHeight;

  /// A balanced scale (prevents height-only weirdness)
  static double _scale(BuildContext context) =>
      math.min(_ws(context), _hs(context));

  /// Clamp scaling to avoid too tiny/too huge UI
  static double _clampedScale(BuildContext context) =>
      _scale(context).clamp(0.85, 1.25);

  /// Scaled font size (respects device text scaling but clamps it)
  static double font(BuildContext context, double base) {
    final textScale = mq(context).textScaler.scale(1).clamp(0.90, 1.20);
    return base * _clampedScale(context) * textScale;
  }

  /// Scaled padding
  static double pad(BuildContext context, double base) {
    return base * _clampedScale(context);
  }

  /// Scaled radius
  static double radius(BuildContext context, double base) {
    return base * _clampedScale(context);
  }

  /// Generic scaling for heights, widths, icons
  static double scale(BuildContext context, double base) {
    return base * _clampedScale(context);
  }

  /// Sometimes you specifically want width scaling (e.g. horizontal spacing)
  static double scaleW(BuildContext context, double base) {
    return base * _ws(context).clamp(0.85, 1.25);
  }

  /// Sometimes you specifically want height scaling (e.g. vertical spacing)
  static double scaleH(BuildContext context, double base) {
    return base * _hs(context).clamp(0.85, 1.25);
  }
}
