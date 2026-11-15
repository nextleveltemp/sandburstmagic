import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/engine.dart';
import '../../core/sand.dart';

/// Animation state of the board: which board is *shown*, which grains are
/// moving, which rows glow, burst particles and score pop-ups.
///
/// The logical board (GameState.board) is always authoritative. A turn is
/// replayed here phase by phase from the engine's own record (moves, waves,
/// fills), and at the end the shown board is replaced by the real one, so
/// the picture can never drift from the rules.
class BoardFx extends ChangeNotifier {
  BoardFx(Board board) : shown = board.copy();

  Board shown;

  /// index -> destination index of grains moving in the current stage.
  final Map<int, int> moving = {};

  /// Indices that fall into a trap in the current stage (fade out).
  final Set<int> absorbing = {};

  /// Progress of the current stage, 0..1.
  double t = 0;

  /// Rows glowing before they burst, with strength 0..1.
  List<int> glowRows = const [];
  double glow = 0;

  /// Cells that just appeared (placed blocks dissolving into sand):
  /// index -> age in ms.
  final Map<int, double> fresh = {};

  /// Screen shake strength (0: none).
  double shake = 0;

  final Particles particles = Particles();
  final List<Popup> popups = [];

  final List<_Stage> _queue = [];
  Board? _target;
  _Stage? _current;
  double _elapsed = 0;

  /// Speed factor (reduce motion: faster, fewer particles).
  bool reduceMotion = false;

  /// Total time the clock has run (for shimmer effects), in seconds.
  double time = 0;

  bool get busy => _current != null || _queue.isNotEmpty;

  /// Repaints without other changes (shimmering special sand, targets).
  void repaint() => notifyListeners();

  /// Shows [board] at once (new game, undo, resume).
  void snap(Board board) {
    _queue.clear();
    _current = null;
    moving.clear();
    absorbing.clear();
    glowRows = const [];
    fresh.clear();
    shown = board.copy();
    _target = null;
    notifyListeners();
  }

  /// Plays [turn], which led from the shown board to [after].
  void play(Turn turn, Board after, {int combo = 0}) {
    if (busy) snap(shown); // finish instantly if a new turn arrives early
    _target = after.copy();
    final sp = reduceMotion ? 0.45 : 1.0;
    if (turn.placed.isNotEmpty) {
      _queue.add(
        _PlaceStage(turn.placed, 90 * sp, turn.placedColour, turn.placedKind),
      );
    }
    var waveNo = 0;
    for (final ph in turn.phases) {
      switch (ph) {
        case SettlePhase(:final steps):
          for (final st in steps) {
            _queue.add(_MoveStage(st.moves, st.fills, 24 * sp));
          }
        case WavePhase(:final wave):
          _queue.add(_WaveStage(wave, 170 * sp, waveNo++, combo, false));
        case BlastPhase(:final wave):
          _queue.add(_WaveStage(wave, 120 * sp, 0, 0, true));
        case StickyPhase(:final expired):
          _queue.add(_ApplyStage(60 * sp, (b) {
            for (final i in expired) {
              final c = b.cells[i];
              if (c != null) {
                b.cells[i] = c.copyWith(kind: SandKind.normal, ttl: 0);
              }
            }
          }));
        case MoversPhase(:final moved):
          _queue.add(
            _MoveStage([
              for (final (id, from, to) in moved) GrainMove(id, from, to, false),
            ], const [], 140 * sp),
          );
        case ShufflePhase(:final indices, :final cells):
          _queue.add(_ApplyStage(160 * sp, (b) {
            for (var n = 0; n < indices.length; n++) {
              b.cells[indices[n]] = cells[n];
            }
          }));
        case FillPhase(:final filled):
          _queue.add(_ApplyStage(140 * sp, (b) {
            for (final (id, i) in filled) {
              b.cells[i] = Cell(id, greyColour, kind: SandKind.frozen);
              fresh[i] = 0;
            }
          }));
      }
    }
    _queue.add(_ApplyStage(0, (_) {}));
    _next();
    notifyListeners();
  }

  void _next() {
    final cur = _current;
    if (cur != null) cur.finish(this);
    moving.clear();
    absorbing.clear();
    _elapsed = 0;
    t = 0;
    if (_queue.isEmpty) {
      _current = null;
      glowRows = const [];
      final target = _target;
      if (target != null) shown = target;
      _target = null;
      return;
    }
    _current = _queue.removeAt(0);
    _current!.start(this);
  }

  /// Advances animations by [dtMs].
  void tick(double dtMs) {
    time += dtMs / 1000;
    var changed = false;
    if (_current != null) {
      _elapsed += dtMs;
      var guard = 0;
      while (_current != null && _elapsed >= _current!.duration && guard < 64) {
        _elapsed -= _current!.duration;
        _next();
        guard++;
      }
      final cur = _current;
      if (cur != null) {
        t = cur.duration <= 0 ? 1 : (_elapsed / cur.duration).clamp(0, 1);
        cur.update(this);
      }
      changed = true;
    }
    if (fresh.isNotEmpty) {
      final done = <int>[];
      fresh.updateAll((k, v) => v + dtMs);
      fresh.forEach((k, v) {
        if (v > 260) done.add(k);
      });
      for (final k in done) {
        fresh.remove(k);
      }
      changed = true;
    }
    if (shake > 0) {
      shake = math.max(0, shake - dtMs / 260);
      changed = true;
    }
    if (particles.active > 0) {
      particles.step(dtMs / 1000);
      changed = true;
    }
    if (popups.isNotEmpty) {
      for (final p in popups) {
        p.age += dtMs / 1000;
      }
      popups.removeWhere((p) => p.age > p.life);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Whether anything still moves (the board then repaints every frame).
  bool get animating =>
      busy ||
      fresh.isNotEmpty ||
      shake > 0 ||
      particles.active > 0 ||
      popups.isNotEmpty;
}

abstract class _Stage {
  _Stage(this.duration);
  final double duration;
  void start(BoardFx fx) {}
  void update(BoardFx fx) {}
  void finish(BoardFx fx) {}
}

class _PlaceStage extends _Stage {
  _PlaceStage(this.placed, super.duration, this.colour, this.kind);
  final List<(int, int)> placed;
  final int colour;
  final int kind;

  @override
  void start(BoardFx fx) {
    for (final (id, i) in placed) {
      fx.shown.cells[i] = Cell(
        id,
        colour,
        kind: kind,
        ttl: kind == SandKind.sticky ? stickyTtl : 0,
      );
      fx.fresh[i] = 0;
    }
  }
}

class _MoveStage extends _Stage {
  _MoveStage(this.moves, this.fills, super.duration);
  final List<GrainMove> moves;
  final List<(int, int)> fills;

  @override
  void start(BoardFx fx) {
    for (final m in moves) {
      fx.moving[m.from] = m.to;
      if (m.absorbed) fx.absorbing.add(m.from);
    }
  }

  @override
  void finish(BoardFx fx) {
    final b = fx.shown;
    final filled = {for (final (i, id) in fills) i: id};
    for (final m in moves) {
      final cell = b.cells[m.from];
      b.cells[m.from] = null;
      if (m.absorbed) {
        final trap = b.cells[m.to];
        final fillId = filled[m.to];
        if (fillId != null) {
          b.cells[m.to] = Cell(fillId, greyColour);
        } else if (trap != null) {
          b.cells[m.to] = trap.copyWith(hp: trap.hp - 1);
        }
      } else {
        b.cells[m.to] = cell;
      }
      // A placed block keeps dissolving while it falls.
      final age = fx.fresh.remove(m.from);
      if (age != null) fx.fresh[m.to] = age;
    }
  }
}

class _WaveStage extends _Stage {
  _WaveStage(this.wave, super.duration, this.index, this.combo, this.blast);
  final Wave wave;
  final int index;
  final int combo;
  final bool blast;

  @override
  void start(BoardFx fx) {
    fx.glowRows = blast ? const [] : wave.rows;
  }

  @override
  void update(BoardFx fx) {
    fx.glow = math.sin(fx.t * math.pi);
  }

  @override
  void finish(BoardFx fx) {
    final b = fx.shown;
    final many = fx.reduceMotion ? 2 : (wave.rows.length >= 2 ? 7 : 5);
    for (final r in wave.removed) {
      final cell = b.cells[r.index];
      b.cells[r.index] = null;
      fx.particles.burst(
        r.index,
        cell?.colour ?? r.colour,
        r.obstacle,
        many,
        strong: wave.rows.length >= 2 || r.kind == SandKind.explosive,
      );
    }
    for (final (i, hp) in wave.damaged) {
      final c = b.cells[i];
      if (c != null) b.cells[i] = c.copyWith(hp: hp);
    }
    for (final i in wave.thawed) {
      final c = b.cells[i];
      if (c != null) b.cells[i] = c.copyWith(kind: SandKind.normal);
    }
    fx.glowRows = const [];
    if (!blast && wave.rows.isNotEmpty && wave.points > 0) {
      final row = wave.rows.reduce((a, c) => a + c) / wave.rows.length;
      fx.popups.add(Popup('+${wave.points}', 0.5, (row + 0.5) / boardH));
      if (wave.rows.length >= 2 && !fx.reduceMotion) fx.shake = 1;
    }
  }
}

class _ApplyStage extends _Stage {
  _ApplyStage(super.duration, this.apply);
  final void Function(Board b) apply;

  @override
  void start(BoardFx fx) => apply(fx.shown);
}

/// A floating text (relative board position 0..1).
class Popup {
  Popup(this.text, this.x, this.y, {this.life = 0.9, this.big = false});
  final String text;
  final double x;
  final double y;
  final double life;
  final bool big;
  double age = 0;
}

/// A fixed pool of burst particles (no allocation per frame).
class Particles {
  static const int capacity = 700;

  final Float32List x = Float32List(capacity);
  final Float32List y = Float32List(capacity);
  final Float32List vx = Float32List(capacity);
  final Float32List vy = Float32List(capacity);
  final Float32List life = Float32List(capacity);
  final Float32List maxLife = Float32List(capacity);
  final Float32List spin = Float32List(capacity);
  final Int32List colour = Int32List(capacity);
  int active = 0;
  int _seed = 12345;

  double _rand() {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed / 0x7FFFFFFF;
  }

  /// Spawns [n] particles at cell [index] (cell units: x, y in 0..10).
  void burst(int index, int col, int obstacle, int n, {bool strong = false}) {
    final cx = (index % boardW) + 0.5;
    final cy = (index ~/ boardW) + 0.5;
    final colourId = obstacle >= 0 ? -1 - obstacle : col;
    for (var k = 0; k < n; k++) {
      if (active >= capacity) return;
      final i = active++;
      final a = _rand() * math.pi * 2;
      final speed = (strong ? 5.0 : 3.2) * (0.4 + _rand());
      x[i] = cx + (_rand() - 0.5) * 0.8;
      y[i] = cy + (_rand() - 0.5) * 0.8;
      vx[i] = math.cos(a) * speed;
      vy[i] = math.sin(a) * speed - 2.5;
      maxLife[i] = 0.55 + _rand() * 0.45;
      life[i] = maxLife[i];
      spin[i] = _rand() * math.pi * 2;
      colour[i] = colourId;
    }
  }

  void step(double dt) {
    var i = 0;
    while (i < active) {
      life[i] -= dt;
      if (life[i] <= 0) {
        // Move the last live particle into this slot.
        final last = --active;
        x[i] = x[last];
        y[i] = y[last];
        vx[i] = vx[last];
        vy[i] = vy[last];
        life[i] = life[last];
        maxLife[i] = maxLife[last];
        spin[i] = spin[last];
        colour[i] = colour[last];
        continue;
      }
      vy[i] += 14 * dt;
      vx[i] *= 0.985;
      x[i] += vx[i] * dt;
      y[i] += vy[i] * dt;
      spin[i] += dt * 6;
      i++;
    }
  }
}
