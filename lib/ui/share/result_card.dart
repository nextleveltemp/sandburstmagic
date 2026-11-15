import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/sand.dart';
import '../game/board_fx.dart';
import '../game/sand_painter.dart';
import '../theme/app_theme.dart';
import '../theme/sand_theme.dart';

/// What goes on a shared result card.
class ResultCardData {
  const ResultCardData({
    required this.modeLabel,
    required this.scoreText,
    required this.scoreLabel,
    required this.stars,
    required this.badgeText,
    required this.stats,
    required this.board,
    required this.look,
    required this.taglineText,
    required this.footerText,
  });

  /// "Level 42", "Classic", "Daily Puzzle" (drawn in capitals).
  final String modeLabel;
  final String scoreText;
  final String scoreLabel;

  /// 0: no stars row.
  final int stars;
  final String? badgeText;

  /// Up to three (label, value) pairs.
  final List<(String, String)> stats;

  /// The final board, drawn on the card.
  final Board board;
  final Look look;
  final String taglineText;
  final String footerText;
}

/// Draws the share image (1080 × 1350) in the studio's score-card layout
/// (as Block Burst Magic), with the final board drawn in sand.
abstract final class ResultCard {
  static const double width = 1080;
  static const double height = 1350;

  static Future<Uint8List?> renderPng(ResultCardData d) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));
    paint(canvas, d);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(width.toInt(), height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }

  static void _text(
    Canvas canvas,
    String text,
    double size,
    FontWeight weight,
    Color colour,
    double y, {
    double letter = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontFamilyFallback: AppTheme.symbolFallback,
          fontSize: size,
          fontWeight: weight,
          color: colour,
          letterSpacing: letter,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 120);
    tp.paint(canvas, Offset((width - tp.width) / 2, y));
  }

  static void paint(Canvas canvas, ResultCardData d) {
    final theme = d.look.board.light ? BoardTheme.midnight : d.look.board;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, height),
          [theme.top, theme.bottom],
        ),
    );
    const white = Color(0xFFF3F5FF);
    const muted = Color(0xFFA6B0DA);
    const gold = Color(0xFFF6C453);
    _text(canvas, 'Sand Burst', 64, FontWeight.w800, white, 60);
    _text(canvas, 'Magic', 64, FontWeight.w800, gold, 130);
    _text(
      canvas,
      d.modeLabel.toUpperCase(),
      34,
      FontWeight.w700,
      muted,
      230,
      letter: 4,
    );
    _text(canvas, d.scoreText, 150, FontWeight.w800, white, 270);
    _text(
      canvas,
      d.scoreLabel.toUpperCase(),
      30,
      FontWeight.w700,
      muted,
      450,
      letter: 4,
    );
    var y = 500.0;
    if (d.stars > 0) {
      _text(canvas, '★' * d.stars + '☆' * (3 - d.stars), 64, FontWeight.w800,
          gold, y);
      y += 80;
    }
    final badge = d.badgeText;
    _text(canvas, badge ?? d.taglineText, 36, FontWeight.w700,
        badge != null ? gold : muted, y);
    // The final board.
    const side = 520.0;
    const top = 650.0;
    canvas.save();
    canvas.translate((width - side) / 2, top);
    final fx = BoardFx(d.board);
    SandBoardPainter(
      fx: fx,
      look: d.look,
      overlay: BoardOverlay.none,
    ).paint(canvas, const Size.square(side));
    canvas.restore();
    fx.dispose();
    // Stats row.
    final n = d.stats.length;
    for (var i = 0; i < n; i++) {
      final (label, value) = d.stats[i];
      final cx = width * (i + 1) / (n + 1);
      for (final (t, size, colour, dy) in [
        (value, 54.0, white, 1200.0),
        (label.toUpperCase(), 24.0, muted, 1262.0),
      ]) {
        final tp = TextPainter(
          text: TextSpan(
            text: t,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: colour,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, dy));
      }
    }
    _text(canvas, d.footerText, 24, FontWeight.w600, muted, 1305);
  }
}
