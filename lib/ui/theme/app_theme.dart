import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the Material theme from the game palette.
class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'Outfit';

  /// Fallback for symbols Outfit lacks (★, ≤). On a phone the system fonts
  /// already cover them and this name is simply skipped; the store
  /// screenshots, rendered without system fonts, register a font under it.
  static const List<String> symbolFallback = ['SBM Symbols'];

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.violet,
      onPrimary: Colors.white,
      secondary: p.cyan,
      onSecondary: brightness == Brightness.dark
          ? p.backgroundDeep
          : Colors.white,
      tertiary: p.gold,
      onTertiary: p.backgroundDeep,
      error: p.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      surfaceContainerHighest: p.surfaceHigh,
      outline: p.stroke,
      outlineVariant: p.stroke,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: symbolFallback,
      scaffoldBackgroundColor: p.background,
      extensions: [p],
    );

    final text = base.textTheme.apply(
      bodyColor: p.text,
      displayColor: p.text,
      fontFamily: fontFamily,
      fontFamilyFallback: symbolFallback,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: text.displayMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        bodyMedium: text.bodyMedium?.copyWith(color: p.textMuted, height: 1.4),
        bodySmall: text.bodySmall?.copyWith(color: p.textMuted, height: 1.35),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.violet,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: symbolFallback,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(64, 52),
          side: BorderSide(color: p.stroke, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: symbolFallback,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.violet,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: symbolFallback,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.stroke,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      // Selected segments use the primary accent like switches and buttons
      // (white on violet reads clearly in both themes).
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.violet
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? p.textMuted
                : states.contains(WidgetState.selected)
                ? Colors.white
                : p.text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.stroke)),
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: symbolFallback,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.violet : p.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.stroke),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.violet,
        inactiveTrackColor: p.surfaceHigh,
        thumbColor: p.violet,
        overlayColor: p.violet.withValues(alpha: 0.16),
      ),
      dividerTheme: DividerThemeData(color: p.stroke, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        minVerticalPadding: Space.md,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceHigh,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: symbolFallback,
          color: p.text,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.text,
        unselectedLabelColor: p.textMuted,
        indicatorColor: p.violet,
        dividerColor: p.stroke,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: symbolFallback,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: symbolFallback,
          color: p.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.violet),
    );
  }
}
