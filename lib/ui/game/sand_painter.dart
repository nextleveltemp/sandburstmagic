import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/engine.dart';
import '../../core/sand.dart';
import '../theme/sand_theme.dart';
import 'board_fx.dart';

/// What to outline on top of the board.
class BoardOverlay {
  const BoardOverlay({
    this.preview = const [],
    this.previewValid = true,
    this.previewColour = 0,
    this.hint = const [],
    this.targetRows = const [],
    this.targetCells = const [],
  });

  /// Cells the dragged / selected piece would cover.
  final List<int> preview;
  final bool previewValid;
  final int previewColour;

  /// Cells of the suggested move.
  final List<int> hint;

  /// Power-up targeting: rows or cells that can be chosen.
  final List<int> targetRows;
  final List<int> targetCells;

  static const none = BoardOverlay();
}

/// Grain positions inside a cell: 5 x 5 overlapping grains with a small jitter that
/// depends on the cell's id, so a cluster keeps its look while it falls.
abstract final class Grains {
  static const int perSide = 5;
  static const int perCell = perSide * perSide;

  /// Offsets in cell units (0..1) for [id], flattened x,y pairs.
  static Float32List offsets(int id) {
    final out = Float32List(perCell * 2);
    var h = (id * 2654435761) & 0xFFFFFFFF;
    for (var k = 0; k < perCell; k++) {
      h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
      final jx = ((h & 0xFF) / 255 - 0.5) * 0.14;
      final jy = (((h >> 8) & 0xFF) / 255 - 0.5) * 0.14;
      out[k * 2] = ((k % perSide) + 0.5) / perSide + jx;
      out[k * 2 + 1] = ((k ~/ perSide) + 0.5) / perSide + jy;
    }
    return out;
  }

  /// Shade of grain k of cell [id]: 0 base, 1 light, 2 dark.
  static int shade(int id, int k) => ((id * 31 + k * 17) ^ (k * 7)) % 5 == 0
      ? 1
      : ((id * 13 + k * 29) % 6 == 0 ? 2 : 0);

  static final Map<int, Float32List> _cache = {};

  static Float32List cached(int id) {
    final hit = _cache[id];
    if (hit != null) return hit;
    if (_cache.length > 4000) _cache.clear();
    return _cache[id] = offsets(id);
  }
}

/// Batches grain points by colour and shade, then draws each batch with
/// one drawRawPoints call (fast enough for low-end phones).
class GrainBatch {
  final Map<int, List<double>> _points = {};

  void add(int colourKey, double x, double y) =>
      (_points[colourKey] ??= <double>[])
        ..add(x)
        ..add(y);

  void draw(
    Canvas canvas,
    double size,
    String style,
    Color Function(int key) colourOf,
  ) {
    final cap = style == 'pixel' ? StrokeCap.square : StrokeCap.round;
    for (final e in _points.entries) {
      final pts = Float32List.fromList(e.value);
      final c = colourOf(e.key);
      canvas.drawRawPoints(
        ui.PointMode.points,
        pts,
        Paint()
          ..color = c
          ..strokeWidth = size
          ..strokeCap = cap,
      );
      if (style == 'glass') {
        // A small highlight on each bead.
        final hi = Float32List(pts.length);
        for (var i = 0; i < pts.length; i += 2) {
          hi[i] = pts[i] - size * 0.18;
          hi[i + 1] = pts[i + 1] - size * 0.18;
        }
        canvas.drawRawPoints(
          ui.PointMode.points,
          hi,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = size * 0.32
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    _points.clear();
  }
}

class SandBoardPainter extends CustomPainter {
  SandBoardPainter({
    required this.fx,
    required this.look,
    required this.overlay,
  }) : super(repaint: fx);

  final BoardFx fx;
  final Look look;
  final BoardOverlay overlay;

  final GrainBatch _batch = GrainBatch();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cell = s / boardW;
    final theme = look.board;
    if (fx.shake > 0) {
      final a = fx.shake * cell * 0.12;
      canvas.save();
      canvas.translate(
        math.sin(fx.time * 90) * a,
        math.cos(fx.time * 70) * a * 0.6,
      );
    }
    // Board and cells.
    final boardR = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cell * 0.35),
    );
    canvas.drawRRect(boardR, Paint()..color = theme.board);
    final cellPaint = Paint()..color = theme.cell;
    final b = fx.shown;
    for (var i = 0; i < boardN; i++) {
      final r = i ~/ boardW;
      final c = i % boardW;
      final rect = Rect.fromLTWH(
        c * cell + cell * 0.05,
        r * cell + cell * 0.05,
        cell * 0.9,
        cell * 0.9,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
        cellPaint,
      );
      if (b.noPlace[i]) _blocked(canvas, rect, theme);
    }
    canvas.drawRRect(
      boardR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06
        ..color = theme.line,
    );

    // Hint / power targets under the sand.
    _targets(canvas, cell, theme);

    // Row glow.
    if (fx.glowRows.isNotEmpty) {
      for (final r in fx.glowRows) {
        final rect = Rect.fromLTWH(0, r * cell, s, cell);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(cell * 0.08),
            Radius.circular(cell * 0.3),
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35 * fx.glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }

    // Sand and obstacles.
    // Slightly larger than their spacing, so neighbouring cells' grains
    // touch and the sand reads as one granular mass.
    final grain = cell / Grains.perSide * 1.22;
    final specials = <(int, Cell, Offset)>[];
    for (var i = 0; i < boardN; i++) {
      final c = b.cells[i];
      if (c == null) continue;
      var pos = Offset((i % boardW) * cell, (i ~/ boardW) * cell);
      final dest = fx.moving[i];
      if (dest != null) {
        final to = Offset((dest % boardW) * cell, (dest ~/ boardW) * cell);
        pos = Offset.lerp(pos, to, fx.t)!;
      }
      if (!c.isSand) {
        _obstacle(canvas, c, pos, cell);
        continue;
      }
      if (fx.absorbing.contains(i) && fx.t > 0.6) continue;
      final age = fx.fresh[i];
      if (age != null && age < 120) {
        // A freshly placed block, dissolving into grains.
        final a = 1 - age / 120;
        _block(canvas, pos, cell, c.colour, a);
      }
      final offs = Grains.cached(c.id);
      final rainbow = c.kind == SandKind.rainbow;
      for (var k = 0; k < Grains.perCell; k++) {
        final col = rainbow
            ? ((c.id + k + (fx.time * 4).floor()) % 10)
            : c.colour;
        final sh = Grains.shade(c.id, k);
        _batch.add(
          col * 3 + sh,
          pos.dx + offs[k * 2] * cell,
          pos.dy + offs[k * 2 + 1] * cell,
        );
      }
      if (c.kind != SandKind.normal) specials.add((i, c, pos));
    }
    final pal = look.palette;
    _batch.draw(canvas, grain, look.grain, (key) {
      final col = key ~/ 3;
      return switch (key % 3) {
        1 => pal.light(col),
        2 => pal.dark(col),
        _ => pal.of(col),
      };
    });
    if (look.grain == 'sparkle') _twinkles(canvas, cell);
    for (final (_, c, pos) in specials) {
      _special(canvas, c, pos, cell);
    }

    // Piece preview on top.
    _preview(canvas, cell);

    // Particles and pop-ups.
    _particles(canvas, cell);
    _popups(canvas, size);
    if (fx.shake > 0) canvas.restore();
  }

  void _blocked(Canvas canvas, Rect rect, BoardTheme theme) {
    final p = Paint()..color = theme.line;
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        canvas.drawCircle(
          Offset(
            rect.left + rect.width * (x + 0.5) / 3,
            rect.top + rect.height * (y + 0.5) / 3,
          ),
          rect.width * 0.05,
          p,
        );
      }
    }
  }

  void _block(Canvas canvas, Offset pos, double cell, int colour, double a) {
    final rect = Rect.fromLTWH(
      pos.dx + cell * 0.06,
      pos.dy + cell * 0.06,
      cell * 0.88,
      cell * 0.88,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2)),
      Paint()..color = look.palette.of(colour).withValues(alpha: a),
    );
  }

  void _twinkles(Canvas canvas, double cell) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.8);
    final b = fx.shown;
    for (var i = 0; i < boardN; i++) {
      final c = b.cells[i];
      if (c == null || !c.isSand) continue;
      final phase = (fx.time * 1.7 + c.id * 0.37) % 3.0;
      if (phase > 0.25) continue;
      final r = math.sin(phase / 0.25 * math.pi) * cell * 0.07;
      final center = Offset(
        (i % boardW + 0.3 + (c.id % 5) * 0.1) * cell,
        (i ~/ boardW + 0.3 + (c.id % 3) * 0.15) * cell,
      );
      canvas.drawCircle(center, r, p);
    }
  }

  void _special(Canvas canvas, Cell c, Offset pos, double cell) {
    final center = pos + Offset(cell / 2, cell / 2);
    final t = fx.time;
    switch (c.kind) {
      case SandKind.heavy:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(pos.dx + 2, pos.dy + 2, cell - 4, cell - 4),
            Radius.circular(cell * 0.15),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..color = Colors.black.withValues(alpha: 0.35),
        );
      case SandKind.sticky:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(pos.dx + 3, pos.dy + 3, cell - 6, cell - 6),
            Radius.circular(cell * 0.3),
          ),
          Paint()..color = const Color(0x55FFFFFF),
        );
        _label(canvas, center, '${c.ttl}', cell * 0.4, Colors.white);
      case SandKind.explosive:
        final pulse = 0.5 + 0.5 * math.sin(t * 8);
        canvas.drawCircle(
          center,
          cell * (0.16 + 0.05 * pulse),
          Paint()..color = const Color(0xFFFF3B1F).withValues(alpha: 0.9),
        );
        canvas.drawCircle(center, cell * 0.07, Paint()..color = Colors.yellow);
      case SandKind.frozen:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(pos.dx + 1, pos.dy + 1, cell - 2, cell - 2),
            Radius.circular(cell * 0.12),
          ),
          Paint()..color = const Color(0x8899E6FF),
        );
        _snowflake(canvas, center, cell * 0.22);
      case SandKind.crystal:
        final a = 0.5 + 0.5 * math.sin(t * 3 + c.id);
        _diamond(canvas, center, cell * 0.2, Colors.white.withValues(alpha: a));
      case SandKind.golden:
        final shine = (t * 0.8 + c.id * 0.13) % 1.0;
        canvas.drawCircle(
          center,
          cell * 0.18,
          Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          center.translate(-cell * 0.05, -cell * 0.05),
          cell * 0.06 * (1 - shine),
          Paint()..color = Colors.white,
        );
      case SandKind.magnetic:
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.08
          ..color = const Color(0xFFE6E9F5);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: cell * 0.2),
          math.pi,
          math.pi,
          false,
          p,
        );
        canvas.drawLine(
          center.translate(-cell * 0.2, 0),
          center.translate(-cell * 0.2, cell * 0.15),
          p,
        );
        canvas.drawLine(
          center.translate(cell * 0.2, 0),
          center.translate(cell * 0.2, cell * 0.15),
          p,
        );
      case SandKind.volcanic:
        final glow = 0.5 + 0.5 * math.sin(t * 5 + c.id);
        canvas.drawCircle(
          center,
          cell * 0.3,
          Paint()
            ..color = const Color(
              0xFFFF5500,
            ).withValues(alpha: 0.35 + 0.3 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        final tri = Path()
          ..moveTo(center.dx, center.dy - cell * 0.18)
          ..lineTo(center.dx + cell * 0.18, center.dy + cell * 0.14)
          ..lineTo(center.dx - cell * 0.18, center.dy + cell * 0.14)
          ..close();
        canvas.drawPath(tri, Paint()..color = const Color(0xFF5A1E0A));
      case SandKind.mystery:
        _label(canvas, center, '?', cell * 0.55, Colors.white);
      default:
        break;
    }
  }

  void _obstacle(Canvas canvas, Cell c, Offset pos, double cell) {
    final rect = Rect.fromLTWH(
      pos.dx + cell * 0.05,
      pos.dy + cell * 0.05,
      cell * 0.9,
      cell * 0.9,
    );
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.16));
    final center = rect.center;
    switch (c.obstacle) {
      case Obstacle.stone:
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF8D8F9E));
        canvas.drawRRect(
          rr.deflate(cell * 0.1),
          Paint()..color = const Color(0xFFA9ABB8),
        );
        if (c.hp <= 1) {
          final crack = Paint()
            ..color = const Color(0xFF4A4C58)
            ..strokeWidth = cell * 0.05
            ..style = PaintingStyle.stroke;
          canvas.drawPath(
            Path()
              ..moveTo(rect.left + cell * 0.3, rect.top + cell * 0.1)
              ..lineTo(center.dx, center.dy)
              ..lineTo(rect.left + cell * 0.35, rect.bottom - cell * 0.1)
              ..moveTo(center.dx, center.dy)
              ..lineTo(rect.right - cell * 0.12, center.dy + cell * 0.1),
            crack,
          );
        }
      case Obstacle.wood:
        canvas.drawRRect(rr, Paint()..color = const Color(0xFFA0642D));
        final line = Paint()
          ..color = const Color(0xFF6E4019)
          ..strokeWidth = cell * 0.05;
        for (final f in const [0.33, 0.66]) {
          canvas.drawLine(
            Offset(rect.left + 3, rect.top + rect.height * f),
            Offset(rect.right - 3, rect.top + rect.height * f),
            line,
          );
        }
      case Obstacle.ice:
        canvas.drawRRect(rr, Paint()..color = const Color(0xAA8EE3FF));
        _snowflake(canvas, center, cell * 0.25);
      case Obstacle.locked:
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF4B3A7A));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center.translate(0, cell * 0.08),
              width: cell * 0.42,
              height: cell * 0.32,
            ),
            Radius.circular(cell * 0.06),
          ),
          Paint()..color = const Color(0xFFF6C453),
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: center.translate(0, -cell * 0.08),
            width: cell * 0.28,
            height: cell * 0.3,
          ),
          math.pi,
          math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.06
            ..color = const Color(0xFFF6C453),
        );
        _label(
          canvas,
          center.translate(0, cell * 0.09),
          '${c.hp}',
          cell * 0.24,
          const Color(0xFF4B3A7A),
        );
      case Obstacle.unbreakable:
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF2B2E3A));
        final bolt = Paint()..color = const Color(0xFF6B6F80);
        for (final (dx, dy) in const [
          (0.2, 0.2),
          (0.8, 0.2),
          (0.2, 0.8),
          (0.8, 0.8),
        ]) {
          canvas.drawCircle(
            Offset(rect.left + rect.width * dx, rect.top + rect.height * dy),
            cell * 0.06,
            bolt,
          );
        }
      case Obstacle.trap:
        canvas.drawOval(
          rect.deflate(cell * 0.08),
          Paint()..color = const Color(0xFF07060F),
        );
        canvas.drawOval(
          rect.deflate(cell * 0.08),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.05
            ..color = const Color(0xFFC9A27A),
        );
        _label(canvas, center, '${c.hp}', cell * 0.32, const Color(0xFFC9A27A));
      case Obstacle.crystalWall:
        canvas.drawRRect(rr, Paint()..color = const Color(0xCC5FD3F3));
        _diamond(
          canvas,
          center,
          cell * 0.28,
          Colors.white.withValues(alpha: 0.7),
        );
        _label(canvas, center, '${c.hp}', cell * 0.26, const Color(0xFF0B3550));
      case Obstacle.mover:
        canvas.drawRRect(rr, Paint()..color = const Color(0xFFE05A9C));
        final dir = c.ttl >= 0 ? 1.0 : -1.0;
        final arrow = Path()
          ..moveTo(center.dx + dir * cell * 0.22, center.dy)
          ..lineTo(center.dx - dir * cell * 0.08, center.dy - cell * 0.18)
          ..lineTo(center.dx - dir * cell * 0.08, center.dy + cell * 0.18)
          ..close();
        canvas.drawPath(arrow, Paint()..color = Colors.white);
    }
  }

  void _snowflake(Canvas canvas, Offset c, double r) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final a = k * math.pi / 3;
      final d = Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawLine(c - d, c + d, p);
    }
  }

  void _diamond(Canvas canvas, Offset c, double r, Color colour) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.7, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.7, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  static void _label(
    Canvas canvas,
    Offset center,
    String text,
    double size,
    Color colour,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: colour,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _targets(Canvas canvas, double cell, BoardTheme theme) {
    final accent = theme.accent;
    final pulse = 0.25 + 0.2 * math.sin(fx.time * 6);
    for (final r in overlay.targetRows) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, r * cell, cell * boardW, cell).deflate(1),
          Radius.circular(cell * 0.2),
        ),
        Paint()..color = accent.withValues(alpha: pulse),
      );
    }
    for (final i in overlay.targetCells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (i % boardW) * cell,
            (i ~/ boardW) * cell,
            cell,
            cell,
          ).deflate(2),
          Radius.circular(cell * 0.2),
        ),
        Paint()..color = accent.withValues(alpha: pulse),
      );
    }
    for (final i in overlay.hint) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (i % boardW) * cell,
            (i ~/ boardW) * cell,
            cell,
            cell,
          ).deflate(2),
          Radius.circular(cell * 0.2),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.08
          ..color = const Color(0xFFF6C453).withValues(alpha: 0.5 + pulse),
      );
    }
  }

  void _preview(Canvas canvas, double cell) {
    if (overlay.preview.isEmpty) return;
    final colour = overlay.previewValid
        ? look.palette.of(overlay.previewColour).withValues(alpha: 0.45)
        : const Color(0x66FF4060);
    for (final i in overlay.preview) {
      if (i < 0 || i >= boardN) continue;
      final rect = Rect.fromLTWH(
        (i % boardW) * cell,
        (i ~/ boardW) * cell,
        cell,
        cell,
      ).deflate(cell * 0.06);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2));
      canvas.drawRRect(rr, Paint()..color = colour);
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05
          ..color = overlay.previewValid
              ? Colors.white.withValues(alpha: 0.8)
              : const Color(0xFFFF4060),
      );
    }
  }

  void _particles(Canvas canvas, double cell) {
    final ps = fx.particles;
    if (ps.active == 0) return;
    final paint = Paint();
    final style = look.burst;
    for (var i = 0; i < ps.active; i++) {
      final a = (ps.life[i] / ps.maxLife[i]).clamp(0.0, 1.0);
      final colId = ps.colour[i];
      final base = colId >= 0
          ? look.palette.of(colId)
          : const Color(0xFFD7DAE6);
      paint.color = base.withValues(alpha: a);
      final p = Offset(ps.x[i] * cell, ps.y[i] * cell);
      final r = cell * 0.09 * (0.5 + a);
      switch (style) {
        case 'stars':
          _star(canvas, p, r * 1.4, ps.spin[i], paint);
        case 'confetti':
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(ps.spin[i]);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: r * 2, height: r),
            paint,
          );
          canvas.restore();
        case 'rings':
          canvas.drawCircle(
            p,
            r * (2 - a) * 1.2,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.4
              ..color = paint.color,
          );
        default:
          canvas.drawCircle(p, r, paint);
      }
    }
  }

  static void _star(Canvas canvas, Offset c, double r, double rot, Paint p) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rr = k.isEven ? r : r * 0.45;
      final a = rot + k * math.pi / 5;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (k == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path..close(), p);
  }

  void _popups(Canvas canvas, Size size) {
    for (final p in fx.popups) {
      final k = (p.age / p.life).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: size.width * (p.big ? 0.09 : 0.065),
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 1 - k * k),
            shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = Offset(
        p.x * size.width - tp.width / 2,
        p.y * size.height - tp.height / 2 - k * size.height * 0.08,
      );
      tp.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(SandBoardPainter old) =>
      old.look != look || old.overlay != overlay || old.fx != fx;
}

/// Draws one tray piece as glossy / flat / outlined blocks.
class PiecePainter extends CustomPainter {
  PiecePainter(this.piece, this.look, {this.dim = false});

  final Piece piece;
  final Look look;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = shapes[piece.shape];
    final cell = size.width / 5;
    final w = shape.cols * cell;
    final h = shape.rows * cell;
    final origin = Offset((size.width - w) / 2, (size.height - h) / 2);
    paintBlocks(canvas, origin, cell, piece, look, dim: dim);
  }

  static void paintBlocks(
    Canvas canvas,
    Offset origin,
    double cell,
    Piece piece,
    Look look, {
    bool dim = false,
  }) {
    final base = look.palette.of(piece.colour);
    final colour = dim ? base.withValues(alpha: 0.35) : base;
    for (final (r, c) in shapes[piece.shape].cells) {
      final rect = Rect.fromLTWH(
        origin.dx + c * cell + cell * 0.05,
        origin.dy + r * cell + cell * 0.05,
        cell * 0.9,
        cell * 0.9,
      );
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2));
      switch (look.piece) {
        case 'outline':
          canvas.drawRRect(rr, Paint()..color = colour.withValues(alpha: 0.25));
          canvas.drawRRect(
            rr.deflate(cell * 0.04),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.1
              ..color = colour,
          );
        case 'flat':
          canvas.drawRRect(rr, Paint()..color = colour);
        default:
          canvas.drawRRect(
            rr,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(colour, Colors.white, 0.3)!,
                  colour,
                  Color.lerp(colour, Colors.black, 0.25)!,
                ],
              ).createShader(rect),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                rect.left + cell * 0.12,
                rect.top + cell * 0.1,
                cell * 0.45,
                cell * 0.16,
              ),
              Radius.circular(cell * 0.08),
            ),
            Paint()..color = Colors.white.withValues(alpha: dim ? 0.15 : 0.45),
          );
      }
      if (piece.kind != SandKind.normal) {
        final ch = switch (piece.kind) {
          SandKind.heavy => 'H',
          SandKind.sticky => 'S',
          SandKind.explosive => '✸',
          SandKind.rainbow => '◈',
          SandKind.frozen => '❄',
          SandKind.crystal => '◆',
          SandKind.golden => '●',
          SandKind.magnetic => 'U',
          SandKind.volcanic => '▲',
          _ => '?',
        };
        SandBoardPainter._label(
          canvas,
          rect.center,
          ch,
          cell * 0.45,
          Colors.white.withValues(alpha: dim ? 0.4 : 0.95),
        );
      }
    }
  }

  @override
  bool shouldRepaint(PiecePainter old) =>
      old.piece.code != piece.code || old.dim != dim || old.look != look;
}
