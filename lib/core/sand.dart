/// Sand Burst Magic rules, part 1: board, cells, piece shapes, sand
/// settling and row clears.
///
/// A line-by-line port of `tool/reference_model/core.py` (the written
/// specification). `test/core/reference_test.dart` replays the Python
/// model's recorded games and requires identical results.
///
/// The logical grid is authoritative: the UI only animates what these
/// functions decide, so grains on screen can never create or remove rows.
library;

import 'dart:collection';

import 'rng.dart';

const int boardW = 10;
const int boardH = 10;
const int boardN = boardW * boardH;

/// Colour of the packed sand left by a filled trap / Row Clear.
const int greyColour = 10;

/// Sand kinds.
abstract final class SandKind {
  static const normal = 0;
  static const heavy = 1;
  static const sticky = 2;
  static const explosive = 3;
  static const rainbow = 4;
  static const frozen = 5;
  static const crystal = 6;
  static const golden = 7;
  static const magnetic = 8;
  static const volcanic = 9;
  static const mystery = 10;
  static const count = 11;

  static const names = [
    'normal', 'heavy', 'sticky', 'explosive', 'rainbow', 'frozen', //
    'crystal', 'golden', 'magnetic', 'volcanic', 'mystery',
  ];

  /// What a mystery piece can turn into.
  static const mysteryReveal = [heavy, explosive, crystal, golden, rainbow];

  /// Order in which a special-sand table is read.
  static const order = [
    heavy, sticky, explosive, rainbow, frozen, crystal, golden, magnetic, //
    volcanic, mystery,
  ];
}

const int stickyTtl = 3;

/// Obstacles. [none] marks a sand cell.
abstract final class Obstacle {
  static const none = -1;
  static const stone = 0;
  static const wood = 1;
  static const ice = 2;
  static const locked = 3;
  static const unbreakable = 4;
  static const trap = 5;
  static const crystalWall = 6;
  static const mover = 7;
  static const count = 8;

  static const names = [
    'stone', 'wood', 'ice', 'locked', 'unbreakable', 'trap', //
    'crystalWall', 'mover',
  ];

  static int hp(int o) => const [2, 1, 1, 3, 0, 3, 3, 1][o];
}

/// One occupied cell. Immutable: changes make a copy.
class Cell {
  const Cell(
    this.id,
    this.colour, {
    this.kind = SandKind.normal,
    this.obstacle = Obstacle.none,
    this.hp = 0,
    this.ttl = 0,
  });

  /// Stable identity, so the UI can follow a grain as it falls.
  final int id;
  final int colour;
  final int kind;
  final int obstacle;
  final int hp;

  /// Sticky sand: turns left. Mover: direction (-1 / +1).
  final int ttl;

  bool get isSand => obstacle == Obstacle.none;

  Cell copyWith({int? colour, int? kind, int? hp, int? ttl}) => Cell(
    id,
    colour ?? this.colour,
    kind: kind ?? this.kind,
    obstacle: obstacle,
    hp: hp ?? this.hp,
    ttl: ttl ?? this.ttl,
  );

  /// Compact text used by the reference vectors and saves (no id).
  String get code =>
      isSand ? 's${colour}k${kind}t$ttl' : 'o${obstacle}h${hp}t$ttl';

  Map<String, Object?> toJson() => {
    'i': id,
    'c': colour,
    if (kind != 0) 'k': kind,
    if (obstacle != Obstacle.none) 'o': obstacle,
    if (hp != 0) 'h': hp,
    if (ttl != 0) 't': ttl,
  };

  static Cell fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid cell');
    int n(String k, int def) {
      final v = json[k];
      return v is int ? v : def;
    }

    final o = n('o', Obstacle.none);
    final kind = n('k', 0);
    final colour = n('c', 0);
    if (o < Obstacle.none || o >= Obstacle.count) {
      throw const FormatException('Invalid obstacle');
    }
    if (kind < 0 || kind >= SandKind.count || colour < 0 || colour > 10) {
      throw const FormatException('Invalid sand');
    }
    return Cell(
      n('i', 0),
      colour,
      kind: kind,
      obstacle: o,
      hp: n('h', 0),
      ttl: n('t', 0),
    );
  }
}

class Board {
  Board()
    : cells = List<Cell?>.filled(boardN, null),
      noPlace = _noBlocks,
      nextId = 1;

  Board._(this.cells, this.noPlace, this.nextId);

  static final List<bool> _noBlocks = List<bool>.filled(boardN, false);

  final List<Cell?> cells;

  /// Cells pieces cannot be placed on (sand can still flow into them).
  /// Never changes during a game, so copies share it.
  List<bool> noPlace;
  int nextId;

  Board copy() => Board._(List<Cell?>.of(cells), noPlace, nextId);

  int newId() => nextId++;

  Cell? operator [](int i) => cells[i];

  String encode() => cells.map((c) => c?.code ?? '').join(',');

  List<int> heights() {
    final hs = <int>[];
    for (var c = 0; c < boardW; c++) {
      var h = 0;
      for (var r = 0; r < boardH; r++) {
        if (cells[r * boardW + c] != null) {
          h = boardH - r;
          break;
        }
      }
      hs.add(h);
    }
    return hs;
  }

  int holes() {
    var n = 0;
    for (var c = 0; c < boardW; c++) {
      var seen = false;
      for (var r = 0; r < boardH; r++) {
        if (cells[r * boardW + c] != null) {
          seen = true;
        } else if (seen) {
          n++;
        }
      }
    }
    return n;
  }

  int emptyCount() {
    var n = 0;
    for (var i = 0; i < boardN; i++) {
      if (cells[i] == null && !noPlace[i]) n++;
    }
    return n;
  }

  int sandCount() {
    var n = 0;
    for (final c in cells) {
      if (c != null && c.isSand) n++;
    }
    return n;
  }

  Map<String, Object?> toJson() => {
    'cells': [for (final c in cells) c?.toJson()],
    'blocked': [
      for (var i = 0; i < boardN; i++)
        if (noPlace[i]) i,
    ],
    'next': nextId,
  };

  static Board fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid board');
    final raw = json['cells'];
    if (raw is! List || raw.length != boardN) {
      throw const FormatException('Invalid board cells');
    }
    final b = Board();
    final ids = <int>{};
    for (var i = 0; i < boardN; i++) {
      final v = raw[i];
      if (v == null) continue;
      final cell = Cell.fromJson(v);
      if (!ids.add(cell.id)) throw const FormatException('Duplicate cell id');
      b.cells[i] = cell;
    }
    final blocked = json['blocked'];
    if (blocked is List && blocked.isNotEmpty) {
      final np = List<bool>.filled(boardN, false);
      for (final i in blocked) {
        if (i is int && i >= 0 && i < boardN) np[i] = true;
      }
      b.noPlace = np;
    }
    final next = json['next'];
    b.nextId = next is int ? next : 1;
    for (final id in ids) {
      if (id >= b.nextId) b.nextId = id + 1;
    }
    return b;
  }
}

// ---------------------------------------------------------------- layouts

const Map<String, int> sandSpecialChars = {
  'h': SandKind.heavy,
  'k': SandKind.sticky,
  'e': SandKind.explosive,
  'r': SandKind.rainbow,
  'f': SandKind.frozen,
  'c': SandKind.crystal,
  'g': SandKind.golden,
  'm': SandKind.magnetic,
  'v': SandKind.volcanic,
};

const Map<String, int> obstacleChars = {
  'S': Obstacle.stone,
  'W': Obstacle.wood,
  'I': Obstacle.ice,
  'L': Obstacle.locked,
  'U': Obstacle.unbreakable,
  'T': Obstacle.trap,
  'C': Obstacle.crystalWall,
  'M': Obstacle.mover,
  'N': Obstacle.mover,
};

/// Colour of a pre-placed special grain at (r, c) in a layout.
int layoutColour(int r, int c) => (r + 2 * c) % 10;

Board boardFromLayout(List<String> rows, {int lockRows = 3}) {
  if (rows.length != boardH) throw const FormatException('Layout height');
  final b = Board();
  List<bool>? np;
  for (var r = 0; r < boardH; r++) {
    final line = rows[r];
    if (line.length != boardW) throw const FormatException('Layout width');
    for (var c = 0; c < boardW; c++) {
      final i = r * boardW + c;
      final ch = line[c];
      if (ch == '.') continue;
      if (ch == 'x') {
        np ??= List<bool>.filled(boardN, false);
        np[i] = true;
        continue;
      }
      final digit = ch.codeUnitAt(0) - 48;
      if (digit >= 0 && digit <= 9) {
        b.cells[i] = Cell(b.newId(), digit);
        continue;
      }
      final k = sandSpecialChars[ch];
      if (k != null) {
        b.cells[i] = Cell(
          b.newId(),
          layoutColour(r, c),
          kind: k,
          ttl: k == SandKind.sticky ? stickyTtl : 0,
        );
        continue;
      }
      final o = obstacleChars[ch];
      if (o == null) throw FormatException('Bad layout char $ch');
      final hp = o == Obstacle.locked ? lockRows : Obstacle.hp(o);
      final ttl = o == Obstacle.mover ? (ch == 'N' ? -1 : 1) : 0;
      b.cells[i] = Cell(b.newId(), 0, obstacle: o, hp: hp, ttl: ttl);
    }
  }
  if (np != null) b.noPlace = np;
  return b;
}

// ---------------------------------------------------------------- shapes

class Shape {
  const Shape(this.name, this.cells);
  final String name;

  /// (row, col) offsets.
  final List<(int, int)> cells;

  int get size => cells.length;

  int get rows => cells.fold(0, (m, c) => c.$1 + 1 > m ? c.$1 + 1 : m);
  int get cols => cells.fold(0, (m, c) => c.$2 + 1 > m ? c.$2 + 1 : m);
}

const List<Shape> shapes = [
  Shape('single', [(0, 0)]),
  Shape('line2', [(0, 0), (0, 1)]),
  Shape('line2', [(0, 0), (1, 0)]),
  Shape('line3', [(0, 0), (0, 1), (0, 2)]),
  Shape('line3', [(0, 0), (1, 0), (2, 0)]),
  Shape('line4', [(0, 0), (0, 1), (0, 2), (0, 3)]),
  Shape('line4', [(0, 0), (1, 0), (2, 0), (3, 0)]),
  Shape('square', [(0, 0), (0, 1), (1, 0), (1, 1)]),
  Shape('lshape', [(0, 0), (1, 0), (2, 0), (2, 1)]),
  Shape('lshape', [(0, 0), (0, 1), (0, 2), (1, 0)]),
  Shape('lshape', [(0, 0), (0, 1), (1, 1), (2, 1)]),
  Shape('lshape', [(0, 2), (1, 0), (1, 1), (1, 2)]),
  Shape('jshape', [(0, 1), (1, 1), (2, 0), (2, 1)]),
  Shape('jshape', [(0, 0), (1, 0), (1, 1), (1, 2)]),
  Shape('jshape', [(0, 0), (0, 1), (1, 0), (2, 0)]),
  Shape('jshape', [(0, 0), (0, 1), (0, 2), (1, 2)]),
  Shape('tshape', [(0, 0), (0, 1), (0, 2), (1, 1)]),
  Shape('tshape', [(0, 0), (1, 0), (1, 1), (2, 0)]),
  Shape('tshape', [(0, 1), (1, 0), (1, 1), (1, 2)]),
  Shape('tshape', [(0, 1), (1, 0), (1, 1), (2, 1)]),
  Shape('corner', [(0, 0), (0, 1), (1, 0)]),
  Shape('corner', [(0, 0), (0, 1), (1, 1)]),
  Shape('corner', [(0, 1), (1, 0), (1, 1)]),
  Shape('corner', [(0, 0), (1, 0), (1, 1)]),
  Shape('zigzag', [(0, 0), (0, 1), (1, 1), (1, 2)]),
  Shape('zigzag', [(0, 1), (1, 0), (1, 1), (2, 0)]),
  Shape('rzigzag', [(0, 1), (0, 2), (1, 0), (1, 1)]),
  Shape('rzigzag', [(0, 0), (1, 0), (1, 1), (2, 1)]),
  Shape('line5', [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)]),
  Shape('line5', [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]),
];

const List<int> defaultWeights = [
  4, 6, 6, 6, 6, 4, 4, 6, //
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, //
  3, 3, 3, 3, 3, 3, 3, 3, 2, 2,
];

/// Small, simple pieces: the tutorial and the first levels.
const List<int> gentleWeights = [
  6, 8, 8, 8, 8, 4, 4, 6, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  3, 3, 3, 3, 1, 1, 1, 1, 0, 0,
];

bool canPlace(Board board, int sid, int r0, int c0) {
  for (final (dr, dc) in shapes[sid].cells) {
    final r = r0 + dr;
    final c = c0 + dc;
    if (r < 0 || r >= boardH || c < 0 || c >= boardW) return false;
    final i = r * boardW + c;
    if (board.cells[i] != null || board.noPlace[i]) return false;
  }
  return true;
}

bool fitsAnywhere(Board board, int sid) {
  for (var r = 0; r < boardH; r++) {
    for (var c = 0; c < boardW; c++) {
      if (canPlace(board, sid, r, c)) return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------- sand

/// One grain moving one cell. [absorbed]: it fell into a sand trap.
class GrainMove {
  const GrainMove(this.id, this.from, this.to, this.absorbed);
  final int id;
  final int from;
  final int to;
  final bool absorbed;
}

/// One synchronous settling step: grain moves and traps that filled up
/// (index, id of the new packed sand).
class SettleStep {
  SettleStep(this.moves, this.fills);
  final List<GrainMove> moves;
  final List<(int, int)> fills;
}

bool _enterable(Board b, int i) {
  final c = b.cells[i];
  return c == null || c.obstacle == Obstacle.trap;
}

bool _held(Board b, int i) {
  final r = i ~/ boardW;
  final c = i % boardW;
  for (final (nr, nc) in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
    if (nr >= 0 && nr < boardH && nc >= 0 && nc < boardW) {
      final n = b.cells[nr * boardW + nc];
      if (n != null && n.isSand && n.kind == SandKind.sticky && n.ttl > 0) {
        return true;
      }
    }
  }
  return false;
}

bool movable(Board b, int i) {
  final c = b.cells[i];
  if (c == null || !c.isSand) return false;
  if (c.kind == SandKind.frozen) return false;
  if (c.kind == SandKind.sticky && c.ttl > 0) return false;
  return !_held(b, i);
}

void _move(
  Board b,
  int from,
  int to,
  List<GrainMove> moves,
  List<(int, int)> fills,
) {
  final cell = b.cells[from]!;
  final target = b.cells[to];
  b.cells[from] = null;
  if (target != null && target.obstacle == Obstacle.trap) {
    final hp = target.hp - 1;
    moves.add(GrainMove(cell.id, from, to, true));
    if (hp <= 0) {
      final nid = b.newId();
      b.cells[to] = Cell(nid, greyColour);
      fills.add((to, nid));
    } else {
      b.cells[to] = target.copyWith(hp: hp);
    }
  } else {
    b.cells[to] = cell;
    moves.add(GrainMove(cell.id, from, to, false));
  }
}

SettleStep settleStep(Board b, int step) {
  final moves = <GrainMove>[];
  final fills = <(int, int)>[];
  final even = step % 2 == 0;
  for (var r = boardH - 2; r >= 0; r--) {
    for (var k = 0; k < boardW; k++) {
      final c = even ? k : boardW - 1 - k;
      final i = r * boardW + c;
      if (!movable(b, i)) continue;
      final below = i + boardW;
      if (_enterable(b, below)) {
        _move(b, i, below, moves, fills);
        continue;
      }
      final kind = b.cells[i]!.kind;
      if (kind == SandKind.heavy || kind == SandKind.sticky) continue;
      final first = (step + r + c) % 2 == 0 ? -1 : 1;
      for (final d in [first, -first]) {
        final nc = c + d;
        if (nc < 0 || nc >= boardW) continue;
        if (b.cells[r * boardW + nc] == null &&
            _enterable(b, (r + 1) * boardW + nc)) {
          _move(b, i, (r + 1) * boardW + nc, moves, fills);
          break;
        }
      }
    }
  }
  return SettleStep(moves, fills);
}

/// Settles in place; returns the steps (for the animation).
List<SettleStep> settle(Board b, {int maxSteps = 400}) {
  final steps = <SettleStep>[];
  for (var s = 0; s < maxSteps; s++) {
    final step = settleStep(b, s);
    if (step.moves.isEmpty) break;
    steps.add(step);
  }
  return steps;
}

/// Gravity Shift: loose grains slide to the left (-1) or right (+1) wall.
List<SettleStep> shiftSideways(Board b, int d, {int maxSteps = 400}) {
  final steps = <SettleStep>[];
  for (var s = 0; s < maxSteps; s++) {
    final moves = <GrainMove>[];
    final fills = <(int, int)>[];
    for (var r = 0; r < boardH; r++) {
      for (var k = 0; k < boardW; k++) {
        final c = d < 0 ? k : boardW - 1 - k;
        final i = r * boardW + c;
        final nc = c + d;
        if (nc < 0 || nc >= boardW || !movable(b, i)) continue;
        if (_enterable(b, r * boardW + nc)) {
          _move(b, i, r * boardW + nc, moves, fills);
        }
      }
    }
    if (moves.isEmpty) break;
    steps.add(SettleStep(moves, fills));
  }
  return steps;
}

// ---------------------------------------------------------------- clears

List<int> fullRows(Board b) {
  final out = <int>[];
  for (var r = 0; r < boardH; r++) {
    var ok = true;
    for (var c = 0; c < boardW; c++) {
      final cell = b.cells[r * boardW + c];
      if (cell == null || cell.obstacle == Obstacle.trap) {
        ok = false;
        break;
      }
    }
    if (ok) out.add(r);
  }
  return out;
}

/// A removed cell (for the burst animation).
class Removed {
  const Removed(this.id, this.index, this.colour, this.kind, this.obstacle);
  final int id;
  final int index;
  final int colour;
  final int kind;
  final int obstacle;
}

/// Result of clearing the complete rows once (or of a power-up blast).
class Wave {
  Wave(this.rows);
  final List<int> rows;
  final List<Removed> removed = [];
  final List<(int, int)> damaged = [];
  final List<int> thawed = [];
  int sand = 0;
  int obstacles = 0;
  int crystalWalls = 0;
  final Map<int, int> kinds = {};

  /// Triggered specials (index, kind).
  final List<(int, int)> blasts = [];
  int points = 0;

  void _count(int kind) => kinds[kind] = (kinds[kind] ?? 0) + 1;
}

void _hit(Board b, int i, Wave w, Queue<(int, int, int)> queue) {
  final cell = b.cells[i];
  if (cell == null) return;
  if (cell.isSand) {
    b.cells[i] = null;
    w.removed.add(Removed(cell.id, i, cell.colour, cell.kind, Obstacle.none));
    w.sand++;
    w._count(cell.kind);
    if (cell.kind == SandKind.explosive ||
        cell.kind == SandKind.volcanic ||
        cell.kind == SandKind.magnetic) {
      queue.add((i, cell.kind, cell.colour));
    }
    return;
  }
  final o = cell.obstacle;
  if (o == Obstacle.stone || o == Obstacle.crystalWall) {
    final hp = cell.hp - 1;
    if (hp > 0) {
      b.cells[i] = cell.copyWith(hp: hp);
      w.damaged.add((i, hp));
      return;
    }
  } else if (o != Obstacle.wood && o != Obstacle.ice && o != Obstacle.mover) {
    return; // locked, unbreakable, trap
  }
  b.cells[i] = null;
  w.removed.add(Removed(cell.id, i, cell.colour, cell.kind, o));
  w.obstacles++;
  if (o == Obstacle.crystalWall) w.crystalWalls++;
}

Wave clearWave(Board b, List<int> rows) {
  final w = Wave(rows);
  final queue = Queue<(int, int, int)>();
  for (final r in rows) {
    for (var c = 0; c < boardW; c++) {
      _hit(b, r * boardW + c, w, queue);
    }
  }
  while (queue.isNotEmpty) {
    final (i, kind, colour) = queue.removeFirst();
    w.blasts.add((i, kind));
    final r = i ~/ boardW;
    final c = i % boardW;
    final targets = <(int, int)>[];
    if (kind == SandKind.explosive) {
      for (final dr in const [-1, 0, 1]) {
        for (final dc in const [-1, 0, 1]) {
          if (dr != 0 || dc != 0) targets.add((r + dr, c + dc));
        }
      }
    } else if (kind == SandKind.volcanic) {
      for (final dr in const [-2, -1, 1, 2]) {
        targets.add((r + dr, c));
      }
    } else {
      for (var dr = -2; dr <= 2; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          if (dr == 0 && dc == 0) continue;
          final rr = r + dr;
          final cc = c + dc;
          if (rr >= 0 && rr < boardH && cc >= 0 && cc < boardW) {
            final t = b.cells[rr * boardW + cc];
            if (t != null && t.isSand && t.colour == colour) {
              targets.add((rr, cc));
            }
          }
        }
      }
    }
    for (final (rr, cc) in targets) {
      if (rr >= 0 && rr < boardH && cc >= 0 && cc < boardW) {
        _hit(b, rr * boardW + cc, w, queue);
      }
    }
  }
  // Next to a cleared row: ice breaks, frozen sand thaws.
  final cleared = rows.toSet();
  for (final r in rows) {
    for (final rr in [r - 1, r + 1]) {
      if (rr < 0 || rr >= boardH || cleared.contains(rr)) continue;
      for (var c = 0; c < boardW; c++) {
        final i = rr * boardW + c;
        final cell = b.cells[i];
        if (cell == null) continue;
        if (cell.obstacle == Obstacle.ice) {
          b.cells[i] = null;
          w.removed.add(
            Removed(cell.id, i, cell.colour, cell.kind, Obstacle.ice),
          );
          w.obstacles++;
        } else if (cell.isSand && cell.kind == SandKind.frozen) {
          b.cells[i] = cell.copyWith(kind: SandKind.normal);
          w.thawed.add(i);
          w._count(SandKind.frozen);
        }
      }
    }
  }
  // Locks open after enough cleared rows.
  for (var i = 0; i < boardN; i++) {
    final cell = b.cells[i];
    if (cell != null && cell.obstacle == Obstacle.locked) {
      final hp = cell.hp - rows.length;
      if (hp <= 0) {
        b.cells[i] = null;
        w.removed.add(
          Removed(cell.id, i, cell.colour, cell.kind, Obstacle.locked),
        );
        w.obstacles++;
      } else {
        b.cells[i] = cell.copyWith(hp: hp);
        w.damaged.add((i, hp));
      }
    }
  }
  return w;
}

int rowBase(int k) {
  const base = [0, 100, 250, 450, 700];
  return k <= 4 ? base[k] : 700 + 300 * (k - 4);
}

int wavePoints(Wave w, int combo, int index) {
  final base = rowBase(w.rows.length);
  var pts =
      base * (4 + (combo < 8 ? combo : 8)) * (2 + (index < 6 ? index : 6)) ~/
      8;
  pts += 10 * w.sand + 10 * w.obstacles;
  pts +=
      40 * (w.kinds[SandKind.crystal] ?? 0) +
      15 * (w.kinds[SandKind.rainbow] ?? 0);
  pts += 100 * w.crystalWalls;
  return pts;
}

// ---------------------------------------------------------------- layout gen

const Map<int, String> _obstacleLetter = {
  Obstacle.stone: 'S',
  Obstacle.wood: 'W',
  Obstacle.ice: 'I',
  Obstacle.locked: 'L',
  Obstacle.unbreakable: 'U',
  Obstacle.trap: 'T',
  Obstacle.crystalWall: 'C',
};

/// The board as 10 layout strings.
List<String> layoutText(Board b) {
  final special = {for (final e in sandSpecialChars.entries) e.value: e.key};
  final rows = <String>[];
  for (var r = 0; r < boardH; r++) {
    final sb = StringBuffer();
    for (var c = 0; c < boardW; c++) {
      final i = r * boardW + c;
      final cell = b.cells[i];
      if (b.noPlace[i]) {
        sb.write('x');
      } else if (cell == null) {
        sb.write('.');
      } else if (cell.isSand) {
        sb.write(
          cell.kind == SandKind.normal
              ? '${cell.colour % 10}'
              : special[cell.kind]!,
        );
      } else if (cell.obstacle == Obstacle.mover) {
        sb.write(cell.ttl > 0 ? 'M' : 'N');
      } else {
        sb.write(_obstacleLetter[cell.obstacle]!);
      }
    }
    rows.add(sb.toString());
  }
  return rows;
}

/// A random settled starting board (port of core.make_layout). Used by the
/// Daily Puzzle; campaign levels ship their layouts as text.
Board makeLayout(
  int seed,
  int fill, {
  int density = 78,
  List<int>? palette,
  List<(int, int, int, int)> obstacles = const [],
  List<(int, int)> specials = const [],
  List<int> blocked = const [],
  int lockRows = 3,
}) {
  final pal = palette ?? List<int>.generate(10, (i) => i);
  final rng = SeededRng(seed);
  final b = Board();
  if (blocked.isNotEmpty) {
    final np = List<bool>.filled(boardN, false);
    for (final i in blocked) {
      np[i] = true;
    }
    b.noPlace = np;
  }
  for (final (o, count, top, bottom) in obstacles) {
    for (var n = 0; n < count; n++) {
      for (var t = 0; t < 40; t++) {
        final r = top + rng.nextInt(bottom - top + 1);
        final c = rng.nextInt(boardW);
        final i = r * boardW + c;
        if (b.cells[i] == null && !b.noPlace[i]) {
          final hp = o == Obstacle.locked ? lockRows : Obstacle.hp(o);
          final ttl = o == Obstacle.mover
              ? (rng.nextInt(2) == 0 ? 1 : -1)
              : 0;
          b.cells[i] = Cell(b.newId(), 0, obstacle: o, hp: hp, ttl: ttl);
          break;
        }
      }
    }
  }
  for (var r = boardH - 1; r > boardH - 1 - fill; r--) {
    for (var c = 0; c < boardW; c++) {
      final i = r * boardW + c;
      if (b.cells[i] == null &&
          !b.noPlace[i] &&
          rng.nextInt(100) < density) {
        b.cells[i] = Cell(b.newId(), pal[rng.nextInt(pal.length)]);
      }
    }
  }
  settle(b);
  for (var n = 0; n < boardN; n++) {
    final rows = fullRows(b);
    if (rows.isEmpty) break;
    for (final r in rows) {
      final sand = [
        for (var c = 0; c < boardW; c++)
          if (b.cells[r * boardW + c]?.isSand ?? false) r * boardW + c,
      ];
      if (sand.isNotEmpty) b.cells[sand[rng.nextInt(sand.length)]] = null;
    }
    settle(b);
  }
  if (fullRows(b).isNotEmpty) {
    for (final r in fullRows(b)) {
      b.cells[r * boardW + rng.nextInt(boardW)] = null;
    }
    settle(b);
  }
  for (final (k, count) in specials) {
    for (var n = 0; n < count; n++) {
      final plain = [
        for (var i = 0; i < boardN; i++)
          if (b.cells[i] != null &&
              b.cells[i]!.isSand &&
              b.cells[i]!.kind == SandKind.normal)
            i,
      ];
      if (plain.isEmpty) break;
      final i = plain[rng.nextInt(plain.length)];
      b.cells[i] = b.cells[i]!.copyWith(
        kind: k,
        colour: layoutColour(i ~/ boardW, i % boardW),
        ttl: k == SandKind.sticky ? stickyTtl : 0,
      );
    }
  }
  return b;
}
