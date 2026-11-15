import 'package:flutter/material.dart';

/// Spacing scale (logical pixels). Everything snaps to multiples of 4.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii. Larger surfaces get larger radii.
abstract final class Radii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Motion timing used across the app. Effects are skipped or shortened when
/// reduced motion is on.
abstract final class Timings {
  static const Duration tap = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration lift = Duration(milliseconds: 140);
}

/// Semantic colours for the app chrome and the glass (not the liquids).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.backgroundDeep,
    required this.surface,
    required this.surfaceHigh,
    required this.stroke,
    required this.text,
    required this.textMuted,
    required this.violet,
    required this.cyan,
    required this.gold,
    required this.danger,
    required this.glassEdge,
    required this.glassFill,
  });

  final Color background;
  final Color backgroundDeep;
  final Color surface;
  final Color surfaceHigh;
  final Color stroke;
  final Color text;
  final Color textMuted;

  /// Primary accent: actions, focus and the selected tube.
  final Color violet;

  /// Secondary accent: hints, progress, information.
  final Color cyan;

  /// Reserved for rewards, stars, records and achievements.
  final Color gold;
  final Color danger;

  /// Outline of a glass tube (must stand out from the background).
  final Color glassEdge;

  /// Faint body tint of a glass tube.
  final Color glassFill;

  static const dark = AppPalette(
    background: Color(0xFF0D1433),
    backgroundDeep: Color(0xFF080D24),
    surface: Color(0xFF151E4D),
    surfaceHigh: Color(0xFF1E2A61),
    stroke: Color(0xFF2B3A7A),
    text: Color(0xFFF3F5FF),
    textMuted: Color(0xFFA6B0DA),
    violet: Color(0xFF8C5CFF),
    cyan: Color(0xFF34D6E8),
    gold: Color(0xFFF6C453),
    danger: Color(0xFFFF6F86),
    glassEdge: Color(0xFFC9D4FF),
    glassFill: Color(0x14FFFFFF),
  );

  static const light = AppPalette(
    background: Color(0xFFEDF0FA),
    backgroundDeep: Color(0xFFE0E5F5),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE6EAF8),
    stroke: Color(0xFFC9D1EC),
    text: Color(0xFF131A3E),
    textMuted: Color(0xFF4F5A86),
    violet: Color(0xFF6A3DF0),
    cyan: Color(0xFF0A8FA3),
    gold: Color(0xFF9E6F0B),
    danger: Color(0xFFC92C4A),
    glassEdge: Color(0xFF4A5590),
    glassFill: Color(0x33FFFFFF),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? dark;

  bool get isDark => background.computeLuminance() < 0.2;

  @override
  AppPalette copyWith({
    Color? background,
    Color? backgroundDeep,
    Color? surface,
    Color? surfaceHigh,
    Color? stroke,
    Color? text,
    Color? textMuted,
    Color? violet,
    Color? cyan,
    Color? gold,
    Color? danger,
    Color? glassEdge,
    Color? glassFill,
  }) {
    return AppPalette(
      background: background ?? this.background,
      backgroundDeep: backgroundDeep ?? this.backgroundDeep,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      stroke: stroke ?? this.stroke,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      violet: violet ?? this.violet,
      cyan: cyan ?? this.cyan,
      gold: gold ?? this.gold,
      danger: danger ?? this.danger,
      glassEdge: glassEdge ?? this.glassEdge,
      glassFill: glassFill ?? this.glassFill,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppPalette(
      background: l(background, other.background),
      backgroundDeep: l(backgroundDeep, other.backgroundDeep),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      stroke: l(stroke, other.stroke),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      violet: l(violet, other.violet),
      cyan: l(cyan, other.cyan),
      gold: l(gold, other.gold),
      danger: l(danger, other.danger),
      glassEdge: l(glassEdge, other.glassEdge),
      glassFill: l(glassFill, other.glassFill),
    );
  }
}
