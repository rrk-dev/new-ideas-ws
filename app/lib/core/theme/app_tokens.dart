import 'package:flutter/material.dart';

/// Design tokens. Widgets use these instead of literals.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
}

abstract final class AppColors {
  static const Color seed = Color(0xFF3F51B5);
}

/// Minimum touch target on both platforms (Material 48dp / HIG 44pt).
const double kMinTapTarget = 48;
