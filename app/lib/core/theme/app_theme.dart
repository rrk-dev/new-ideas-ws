import 'package:flutter/material.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';

/// The single definition of the Lumen look (APP-08): Material 3, calm
/// neutrals, one teal accent. Light and dark are built here and nowhere else.
abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, LumenExtras.light);

  static ThemeData get dark => _build(_darkScheme, LumenExtras.dark);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.teal,
    onPrimary: AppColors.lightSurfaceLowest,
    primaryContainer: AppColors.lightTealContainer,
    onPrimaryContainer: AppColors.lightOnTealContainer,
    secondary: AppColors.lightSecondary,
    onSecondary: AppColors.lightSurfaceLowest,
    secondaryContainer: AppColors.lightSecondaryContainer,
    onSecondaryContainer: AppColors.lightText,
    tertiary: AppColors.lightGlowOn,
    onTertiary: AppColors.lightSurfaceLowest,
    tertiaryContainer: AppColors.glow,
    onTertiaryContainer: AppColors.lightGlowOn,
    error: AppColors.lightError,
    onError: AppColors.lightSurfaceLowest,
    errorContainer: AppColors.lightErrorContainer,
    onErrorContainer: AppColors.lightOnErrorContainer,
    surface: AppColors.paper,
    onSurface: AppColors.lightText,
    onSurfaceVariant: AppColors.lightTextMuted,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineSoft,
    shadow: AppColors.ink,
    scrim: AppColors.ink,
    inverseSurface: AppColors.lightText,
    onInverseSurface: AppColors.paper,
    inversePrimary: AppColors.mint,
    surfaceTint: AppColors.teal,
    surfaceContainerLowest: AppColors.lightSurfaceLowest,
    surfaceContainerLow: AppColors.lightSurfaceLow,
    surfaceContainer: AppColors.lightSurfaceMid,
    surfaceContainerHigh: AppColors.lightSurfaceHigh,
    surfaceContainerHighest: AppColors.lightSurfaceHighest,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.mint,
    onPrimary: AppColors.darkOnTeal,
    primaryContainer: AppColors.darkTealContainer,
    onPrimaryContainer: AppColors.darkOnTealContainer,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkOnTeal,
    secondaryContainer: AppColors.darkSecondaryContainer,
    onSecondaryContainer: AppColors.darkText,
    tertiary: AppColors.glow,
    onTertiary: AppColors.darkGlowContainer,
    tertiaryContainer: AppColors.darkGlowContainer,
    onTertiaryContainer: AppColors.darkGlowOn,
    error: AppColors.darkError,
    onError: AppColors.darkOnError,
    errorContainer: AppColors.darkErrorContainer,
    onErrorContainer: AppColors.darkOnErrorContainer,
    surface: AppColors.ink,
    onSurface: AppColors.darkText,
    onSurfaceVariant: AppColors.darkTextMuted,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkOutlineSoft,
    shadow: AppColors.darkSurfaceLowest,
    scrim: AppColors.darkSurfaceLowest,
    inverseSurface: AppColors.darkText,
    onInverseSurface: AppColors.ink,
    inversePrimary: AppColors.teal,
    surfaceTint: AppColors.mint,
    surfaceContainerLowest: AppColors.darkSurfaceLowest,
    surfaceContainerLow: AppColors.darkSurfaceLow,
    surfaceContainer: AppColors.darkSurfaceMid,
    surfaceContainerHigh: AppColors.darkSurfaceHigh,
    surfaceContainerHighest: AppColors.darkSurfaceHighest,
  );

  /// Larger, lighter headings; calm body text. System font on each platform.
  static TextTheme _textTheme(TextTheme base, ColorScheme c) {
    TextStyle s(
      TextStyle? t,
      double size,
      FontWeight w, {
      double spacing = 0,
      double height = 1.4,
    }) => (t ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: w,
      letterSpacing: spacing,
      height: height,
      color: c.onSurface,
    );
    return base.copyWith(
      displayLarge: s(base.displayLarge, 57, FontWeight.w300, spacing: -1),
      displayMedium: s(base.displayMedium, 45, FontWeight.w300, spacing: -0.5),
      displaySmall: s(base.displaySmall, 36, FontWeight.w300),
      headlineLarge: s(base.headlineLarge, 32, FontWeight.w300, spacing: -0.5),
      headlineMedium: s(base.headlineMedium, 28, FontWeight.w300),
      headlineSmall: s(base.headlineSmall, 24, FontWeight.w400),
      titleLarge: s(base.titleLarge, 22, FontWeight.w400),
      titleMedium: s(base.titleMedium, 16, FontWeight.w500, spacing: 0.1),
      titleSmall: s(base.titleSmall, 14, FontWeight.w500, spacing: 0.1),
      bodyLarge: s(
        base.bodyLarge,
        16,
        FontWeight.w400,
        spacing: 0.15,
        height: 1.5,
      ),
      bodyMedium: s(
        base.bodyMedium,
        14,
        FontWeight.w400,
        spacing: 0.2,
        height: 1.5,
      ),
      bodySmall: s(
        base.bodySmall,
        12,
        FontWeight.w400,
        spacing: 0.3,
        height: 1.5,
      ).copyWith(color: c.onSurfaceVariant),
      labelLarge: s(base.labelLarge, 14, FontWeight.w500, spacing: 0.1),
      labelMedium: s(base.labelMedium, 12, FontWeight.w500, spacing: 0.3),
      labelSmall: s(
        base.labelSmall,
        11,
        FontWeight.w500,
        spacing: 0.4,
      ).copyWith(color: c.onSurfaceVariant),
    );
  }

  static ThemeData _build(ColorScheme c, LumenExtras extras) {
    final base = ThemeData(brightness: c.brightness, useMaterial3: true);
    final text = _textTheme(base.textTheme, c);
    const minSize = Size(kMinTapTarget, kMinTapTarget);
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: c.outlineVariant),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: c.outline),
    );
    return base.copyWith(
      colorScheme: c,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [extras],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(
        color: c.outlineVariant,
        space: AppSizes.borderWidth,
        thickness: AppSizes.borderWidth,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          elevation: AppElevation.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: minSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          elevation: AppElevation.none,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          side: BorderSide(color: c.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minSize),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: AppElevation.none,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        iconColor: c.onSurfaceVariant,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.error, width: 2),
        ),
        // The default helper colour measured 4.33:1 (WCAG AA needs 4.5).
        helperStyle: text.bodySmall?.copyWith(color: c.onSurface),
        hintStyle: text.bodyLarge?.copyWith(color: c.onSurfaceVariant),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(AppElevation.none),
        backgroundColor: WidgetStatePropertyAll(c.surfaceContainer),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceContainer,
        selectedColor: c.primaryContainer,
        labelStyle: text.labelMedium,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.none,
        indicatorColor: c.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: text.headlineSmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInverseSurface),
        actionTextColor: c.inversePrimary,
        elevation: AppElevation.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceContainerHighest,
        circularTrackColor: c.surfaceContainerHighest,
        linearMinHeight: AppSizes.progressHeight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.primary
              : c.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.transparent : c.outline,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: c.outlineVariant,
        indicatorColor: c.primary,
        labelColor: c.primary,
        unselectedLabelColor: c.onSurfaceVariant,
      ),
    );
  }
}
