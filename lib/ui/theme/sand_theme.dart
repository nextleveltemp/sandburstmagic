import 'package:flutter/material.dart';

/// Sand colours (palettes) and board themes. Cosmetic only: every palette
/// keeps ten clearly different colours, so the game plays the same.
class SandPalette {
  const SandPalette(this.id, this.colours);
  final String id;

  /// Ten colours, then the packed grey of filled traps.
  final List<Color> colours;

  Color of(int colour) => colours[colour.clamp(0, colours.length - 1)];

  Color light(int colour) => Color.lerp(of(colour), Colors.white, 0.35)!;
  Color dark(int colour) => Color.lerp(of(colour), Colors.black, 0.35)!;

  static const classic = SandPalette('classic', [
    Color(0xFFE0245E), // ruby red
    Color(0xFFFF8A1F), // sunset orange
    Color(0xFFFFD23F), // golden yellow
    Color(0xFF2ECC71), // emerald green
    Color(0xFF2E86FF), // ocean blue
    Color(0xFF8E44EC), // royal purple
    Color(0xFFFF6FC8), // bubblegum pink
    Color(0xFF1FD6C8), // turquoise
    Color(0xFFFF6F59), // coral
    Color(0xFFB9A6FF), // lavender
    Color(0xFF8A8FA8), // packed grey
  ]);

  static const pastel = SandPalette('pastel', [
    Color(0xFFF28BA8),
    Color(0xFFFFB877),
    Color(0xFFFFE58F),
    Color(0xFF8EE3B0),
    Color(0xFF8CC2FF),
    Color(0xFFC3A1F5),
    Color(0xFFFFB3E1),
    Color(0xFF8DEBE2),
    Color(0xFFFFA99A),
    Color(0xFFDCD3FF),
    Color(0xFFB3B6C6),
  ]);

  static const neon = SandPalette('neon', [
    Color(0xFFFF2D6F),
    Color(0xFFFF9E00),
    Color(0xFFF5FF2E),
    Color(0xFF39FF88),
    Color(0xFF2EC4FF),
    Color(0xFFB026FF),
    Color(0xFFFF4FE0),
    Color(0xFF00FFE1),
    Color(0xFFFF5E3A),
    Color(0xFFC6B3FF),
    Color(0xFF9AA0BE),
  ]);

  static const jewel = SandPalette('jewel', [
    Color(0xFFB0103F),
    Color(0xFFD9640B),
    Color(0xFFE3B21E),
    Color(0xFF0F9D58),
    Color(0xFF1858C9),
    Color(0xFF6A1FB5),
    Color(0xFFD94C9F),
    Color(0xFF0FA3A0),
    Color(0xFFE0543C),
    Color(0xFF9580E8),
    Color(0xFF6E7389),
  ]);

  static const all = [classic, pastel, neon, jewel];

  static SandPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => classic);
}

/// Background and board look.
class BoardTheme {
  const BoardTheme({
    required this.id,
    required this.top,
    required this.bottom,
    required this.board,
    required this.cell,
    required this.line,
    required this.accent,
    this.light = false,
  });

  final String id;
  final Color top;
  final Color bottom;
  final Color board;
  final Color cell;
  final Color line;
  final Color accent;
  final bool light;

  static const midnight = BoardTheme(
    id: 'midnight',
    top: Color(0xFF1A1150),
    bottom: Color(0xFF070B22),
    board: Color(0xFF0E1236),
    cell: Color(0xFF181D4C),
    line: Color(0xFF2A3070),
    accent: Color(0xFFB45CFF),
  );

  static const all = <BoardTheme>[
    midnight,
    BoardTheme(
      id: 'candy',
      top: Color(0xFF4A1650),
      bottom: Color(0xFF1C0B2E),
      board: Color(0xFF2A0F3A),
      cell: Color(0xFF3A1650),
      line: Color(0xFF5A2470),
      accent: Color(0xFFFF6FC8),
    ),
    BoardTheme(
      id: 'crystal',
      top: Color(0xFF123A5A),
      bottom: Color(0xFF071628),
      board: Color(0xFF0B2340),
      cell: Color(0xFF123156),
      line: Color(0xFF1F4C7C),
      accent: Color(0xFF7FE7FF),
    ),
    BoardTheme(
      id: 'ocean',
      top: Color(0xFF07466A),
      bottom: Color(0xFF031C33),
      board: Color(0xFF052A45),
      cell: Color(0xFF0A3A5C),
      line: Color(0xFF13557F),
      accent: Color(0xFF1FD6C8),
    ),
    BoardTheme(
      id: 'sunset',
      top: Color(0xFF6A2338),
      bottom: Color(0xFF240B1E),
      board: Color(0xFF34101F),
      cell: Color(0xFF4A1A2C),
      line: Color(0xFF6E2C40),
      accent: Color(0xFFFF8A1F),
    ),
    BoardTheme(
      id: 'forest',
      top: Color(0xFF1C4A33),
      bottom: Color(0xFF0B1C1A),
      board: Color(0xFF102A22),
      cell: Color(0xFF173A2E),
      line: Color(0xFF245440),
      accent: Color(0xFFB9A6FF),
    ),
    BoardTheme(
      id: 'cosmic',
      top: Color(0xFF2B0E5C),
      bottom: Color(0xFF05030F),
      board: Color(0xFF110829),
      cell: Color(0xFF1C0F3E),
      line: Color(0xFF34205E),
      accent: Color(0xFF00FFE1),
    ),
    BoardTheme(
      id: 'daylight',
      top: Color(0xFFFFF1DC),
      bottom: Color(0xFFE6EEFF),
      board: Color(0xFFFFFFFF),
      cell: Color(0xFFF1F3FA),
      line: Color(0xFFD9DEEE),
      accent: Color(0xFF6A3DF0),
      light: true,
    ),
  ];

  static BoardTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => midnight);
}

/// The player's chosen look (from the shop), resolved once per build.
class Look {
  const Look({
    this.board = BoardTheme.midnight,
    this.palette = SandPalette.classic,
    this.grain = 'round',
    this.burst = 'sparks',
    this.piece = 'glossy',
  });

  final BoardTheme board;
  final SandPalette palette;
  final String grain;
  final String burst;
  final String piece;
}
