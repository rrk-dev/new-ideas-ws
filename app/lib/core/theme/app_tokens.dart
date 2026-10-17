import 'package:flutter/material.dart';
import 'package:vaultvoice/core/branding/lumen_logo.dart';

/// Design tokens (APP-08). Widgets use these instead of literals; raw
/// `Color(0x…)` values live only here and in `core/branding`.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Soft, almost flat elevations; separation comes from tonal surfaces.
abstract final class AppElevation {
  static const double none = 0;
  static const double raised = 1;
  static const double overlay = 3;
}

/// Sizes of icons, illustrations and key controls.
abstract final class AppSizes {
  static const double iconSm = 20;
  static const double icon = 24;
  static const double iconMd = 32;
  static const double iconLg = 40;
  static const double sideButton = 64;
  static const double illustration = 56;
  static const double logoSm = 28;
  static const double logoLg = 72;
  static const double recordButton = 112;
  static const double recordRing = 148;
  static const double meterHeight = 12;
  static const double waveformHeight = 40;
  static const double waveformBar = 4;
  static const double waveformGap = 3;
  static const double waveformMinAlpha = 0.35;
  static const int waveformCapacity = 96;
  static const double progressHeight = 6;
  static const double stepDot = 8;
  static const double stepDotActive = 24;
  static const double borderWidth = 1;
  static const double maxContentWidth = 640;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;

  /// [d], or zero when the user asked to reduce motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Calm neutrals plus one teal accent (the Lumen logo teal) and a warm light
/// dot used sparingly.
abstract final class AppColors {
  static const Color teal = LumenColors.teal;
  static const Color mint = LumenColors.mint;

  // Light neutrals.
  static const Color paper = LumenColors.paper;
  static const Color lightText = LumenColors.lightText;
  static const Color lightTextMuted = Color(0xFF52605C);
  static const Color lightOutline = Color(0xFF6C7874);
  static const Color lightOutlineSoft = Color(0xFFD9DEDC);
  static const Color lightSurfaceLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceLow = Color(0xFFFBFCFB);
  static const Color lightSurfaceMid = Color(0xFFF3F5F4);
  static const Color lightSurfaceHigh = Color(0xFFEEF1F0);
  static const Color lightSurfaceHighest = Color(0xFFE9EDEB);
  static const Color lightTealContainer = Color(0xFFD6EFEB);
  static const Color lightOnTealContainer = Color(0xFF0A4741);
  static const Color lightSecondary = Color(0xFF4A5A56);
  static const Color lightSecondaryContainer = Color(0xFFE4EBE9);
  static const Color lightError = Color(0xFFB3261E);
  static const Color lightErrorContainer = Color(0xFFFBE5E2);
  static const Color lightOnErrorContainer = Color(0xFF7A1712);
  static const Color lightGlowOn = Color(0xFF5C4700);

  // Dark neutrals.
  static const Color ink = LumenColors.ink;
  static const Color darkText = LumenColors.darkText;
  static const Color darkTextMuted = Color(0xFFA9B8B4);
  static const Color darkOutline = Color(0xFF7F8F8B);
  static const Color darkOutlineSoft = Color(0xFF2C3936);
  static const Color darkSurfaceLowest = Color(0xFF0A110F);
  static const Color darkSurfaceLow = Color(0xFF131C1A);
  static const Color darkSurfaceMid = Color(0xFF17211F);
  static const Color darkSurfaceHigh = Color(0xFF1D2825);
  static const Color darkSurfaceHighest = Color(0xFF243230);
  static const Color darkOnTeal = Color(0xFF04302B);
  static const Color darkTealContainer = Color(0xFF124A44);
  static const Color darkOnTealContainer = Color(0xFFC2F3EC);
  static const Color darkSecondary = Color(0xFFB4C4C0);
  static const Color darkSecondaryContainer = Color(0xFF263330);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF55120D);
  static const Color darkErrorContainer = Color(0xFF7A1F18);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);
  static const Color darkGlowOn = Color(0xFFFFF4C9);
  static const Color darkGlowContainer = Color(0xFF4A3D0B);

  static const Color glow = LumenColors.glow;
}

/// Extra semantic colours that Material's [ColorScheme] has no slot for.
@immutable
class LumenExtras extends ThemeExtension<LumenExtras> {
  const LumenExtras({
    required this.glow,
    required this.onGlow,
    required this.recording,
    required this.onRecording,
  });

  /// Warm light dot: highlights, "new" markers. Use sparingly.
  final Color glow;
  final Color onGlow;

  /// Active-recording colour (the record button while capturing).
  final Color recording;
  final Color onRecording;

  static const light = LumenExtras(
    glow: AppColors.glow,
    onGlow: AppColors.lightGlowOn,
    recording: AppColors.lightError,
    onRecording: AppColors.lightSurfaceLowest,
  );

  static const dark = LumenExtras(
    glow: AppColors.darkGlowContainer,
    onGlow: AppColors.darkGlowOn,
    recording: AppColors.darkError,
    onRecording: AppColors.darkOnError,
  );

  static LumenExtras of(BuildContext context) =>
      Theme.of(context).extension<LumenExtras>() ?? light;

  @override
  LumenExtras copyWith({
    Color? glow,
    Color? onGlow,
    Color? recording,
    Color? onRecording,
  }) => LumenExtras(
    glow: glow ?? this.glow,
    onGlow: onGlow ?? this.onGlow,
    recording: recording ?? this.recording,
    onRecording: onRecording ?? this.onRecording,
  );

  @override
  LumenExtras lerp(ThemeExtension<LumenExtras>? other, double t) {
    if (other is! LumenExtras) return this;
    return LumenExtras(
      glow: Color.lerp(glow, other.glow, t)!,
      onGlow: Color.lerp(onGlow, other.onGlow, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      onRecording: Color.lerp(onRecording, other.onRecording, t)!,
    );
  }
}

/// Minimum touch target on both platforms (Material 48dp / HIG 44pt).
const double kMinTapTarget = 48;
