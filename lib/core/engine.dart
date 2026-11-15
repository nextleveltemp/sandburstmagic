/// Sand Burst Magic rules, part 2: game configuration, pieces, game state,
/// the piece dealer, turns, power-ups and the bot (hints, daily targets).
///
/// Port of `tool/reference_model/core.py`; checked against it by
/// `test/core/reference_test.dart`.
library;

import 'rng.dart';
import 'sand.dart';

enum Status { playing, won, lost }

/// Why a game ended: 'objectives', 'moves' (limit reached), 'space' (no
/// piece fits) or 'time' (Time Challenge clock).
typedef EndReason = String;

enum ObjectiveType { rows, score, multi, special, obstacles }

class Objective {
  const Objective(this.type, this.target, [this.kind = 0]);
  final ObjectiveType type;
  final int target;

  /// Sand kind, for [ObjectiveType.special].
  final int kind;

  static Objective parse(String text) {
    final p = text.split(':');
    final type = ObjectiveType.values.firstWhere((t) => t.name == p[0]);
    return Objective(type, int.parse(p[1]), p.length > 2 ? int.parse(p[2]) : 0);
  }

  @override
  String toString() => type == ObjectiveType.special
      ? 'special:$target:$kind'
      : '${type.name}:$target';
}

enum Schedule { none, classic, endless }

/// Everything that defines one game.
class GameConfig {
  GameConfig({
    required int seed,
    this.layout,
    this.lockRows = 3,
    this.objectives = const [],
    this.moveLimit = 0,
    this.weights = defaultWeights,
    this.palette = const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    this.specials = const {},
    this.schedule = Schedule.none,
    this.allowPowerUps = true,
  }) : seed = seed & SeededRng.mask32;

  final int seed;
  final List<String>? layout;
  final int lockRows;
  final List<Objective> objectives;
  final int moveLimit;
  final List<int> weights;
  final List<int> palette;

  /// Sand kind -> percent of dealt pieces made of it.
  final Map<int, int> specials;
  final Schedule schedule;
  final bool allowPowerUps;

  Map<String, Object?> toJson() => {
    'seed': seed,
    if (layout != null) 'layout': layout,
    'lockRows': lockRows,
    'objectives': [for (final o in objectives) o.toString()],
    'moveLimit': moveLimit,
    'gentle':
        identical(weights, gentleWeights) || _same(weights, gentleWeights),
    'palette': palette,
    'specials': {for (final e in specials.entries) '${e.key}': e.value},
    'schedule': schedule.name,
    'power': allowPowerUps,
  };

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static GameConfig fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid config');
    final layout = json['layout'];
    final pal = json['palette'];
    final spec = json['specials'];
    final objs = json['objectives'];
    final seed = json['seed'];
    if (seed is! int) throw const FormatException('Invalid seed');
    return GameConfig(
      seed: seed,
      layout: layout is List ? [for (final r in layout) r as String] : null,
      lockRows: json['lockRows'] is int ? json['lockRows'] as int : 3,
      objectives: objs is List
          ? [for (final o in objs) Objective.parse(o as String)]
          : const [],
      moveLimit: json['moveLimit'] is int ? json['moveLimit'] as int : 0,
      weights: json['gentle'] == true ? gentleWeights : defaultWeights,
      palette: pal is List && pal.isNotEmpty
          ? [for (final c in pal) c as int]
          : const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      specials: spec is Map
          ? {
              for (final e in spec.entries)
                int.parse(e.key as String): e.value as int,
            }
          : const {},
      schedule: Schedule.values.firstWhere(
        (s) => s.name == json['schedule'],
        orElse: () => Schedule.none,
      ),
      allowPowerUps: json['power'] != false,
    );
  }
}

const _classicSteps = <(int, Map<int, int>)>[
  (0, {}),
  (1000, {SandKind.frozen: 8}),
  (2500, {SandKind.frozen: 14, SandKind.sticky: 4}),
  (5000, {SandKind.frozen: 20, SandKind.sticky: 6}),
];

const _endlessSteps = <(int, Map<int, int>)>[
  (0, {}),
  (500, {SandKind.crystal: 5, SandKind.golden: 3}),
  (
    1500,
    {
      SandKind.crystal: 5,
      SandKind.golden: 3,
      SandKind.explosive: 4,
      SandKind.heavy: 4,
    },
  ),
  (
    3000,
    {
      SandKind.crystal: 5,
      SandKind.golden: 3,
      SandKind.explosive: 4,
      SandKind.heavy: 4,
      SandKind.sticky: 4,
      SandKind.frozen: 10,
      SandKind.volcanic: 3,
    },
  ),
  (
    5000,
    {
      SandKind.crystal: 5,
      SandKind.golden: 3,
      SandKind.explosive: 4,
      SandKind.heavy: 4,
      SandKind.sticky: 4,
      SandKind.frozen: 16,
      SandKind.volcanic: 3,
      SandKind.magnetic: 3,
      SandKind.rainbow: 3,
      SandKind.mystery: 3,
    },
  ),
];

Map<int, int> specialsFor(GameConfig cfg, int score) {
  if (cfg.schedule == Schedule.none) return cfg.specials;
  final steps = cfg.schedule == Schedule.classic
      ? _classicSteps
      : _endlessSteps;
  var out = const <int, int>{};
  for (final (min, table) in steps) {
    if (score >= min) out = table;
  }
  return out;
}

List<int> weightsFor(GameConfig cfg, int score, int empty) {
  var w = List<int>.of(cfg.weights);
  if (cfg.schedule != Schedule.none && score >= 3000) {
    w[28] += 2;
    w[29] += 2;
  }
  if (empty < 30) {
    w = [
      for (var i = 0; i < w.length; i++) shapes[i].size <= 3 ? w[i] * 2 : w[i],
    ];
  }
  return w;
}

class Piece {
  const Piece(this.shape, this.colour, [this.kind = SandKind.normal]);
  final int shape;
  final int colour;
  final int kind;

  String get code => '$shape:$colour:$kind';

  static Piece? decode(Object? v) {
    if (v is! String) return null;
    final p = v.split(':');
    if (p.length != 3) return null;
    final s = int.tryParse(p[0]);
    final c = int.tryParse(p[1]);
    final k = int.tryParse(p[2]);
    if (s == null || c == null || k == null) return null;
    if (s < 0 || s >= shapes.length || k < 0 || k >= SandKind.count) {
      return null;
    }
    return Piece(s, c, k);
  }
}

class GameState {
  GameState(this.board);

  Board board;
  List<Piece?> tray = [null, null, null];

  /// The Extra Move power-up's bonus single block (slot 3).
  Piece? bonus;
  int rng = 0;
  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int rows = 0;

  /// Waves that cleared two or more rows.
  int multi = 0;
  int bestWave = 0;
  int moves = 0;
  int sets = 0;
  int sandCleared = 0;
  int obstacles = 0;
  Map<int, int> kinds = {};
  int golden = 0;
  int perfect = 0;
  int bonusMoves = 0;
  Status status = Status.playing;
  EndReason reason = '';

  bool get isPlaying => status == Status.playing;

  GameState copy() {
    final s = GameState(board.copy())
      ..tray = List<Piece?>.of(tray)
      ..bonus = bonus
      ..rng = rng
      ..score = score
      ..combo = combo
      ..bestCombo = bestCombo
      ..rows = rows
      ..multi = multi
      ..bestWave = bestWave
      ..moves = moves
      ..sets = sets
      ..sandCleared = sandCleared
      ..obstacles = obstacles
      ..kinds = Map<int, int>.of(kinds)
      ..golden = golden
      ..perfect = perfect
      ..bonusMoves = bonusMoves
      ..status = status
      ..reason = reason;
    return s;
  }

  Map<String, Object?> toJson() => {
    'board': board.toJson(),
    'tray': [for (final p in tray) p?.code],
    'bonus': bonus?.code,
    'rng': rng,
    'score': score,
    'combo': combo,
    'bestCombo': bestCombo,
    'rows': rows,
    'multi': multi,
    'bestWave': bestWave,
    'moves': moves,
    'sets': sets,
    'sand': sandCleared,
    'obstacles': obstacles,
    'kinds': {for (final e in kinds.entries) '${e.key}': e.value},
    'golden': golden,
    'perfect': perfect,
    'bonusMoves': bonusMoves,
    'status': status.name,
    'reason': reason,
  };

  static GameState fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid state');
    int n(String k) {
      final v = json[k];
      if (v is! int || v < 0) throw FormatException('Invalid $k');
      return v;
    }

    final s = GameState(Board.fromJson(json['board']));
    final tray = json['tray'];
    if (tray is! List || tray.length != 3) {
      throw const FormatException('Invalid tray');
    }
    s.tray = [for (final p in tray) Piece.decode(p)];
    s.bonus = Piece.decode(json['bonus']);
    final kinds = json['kinds'];
    if (kinds is Map) {
      for (final e in kinds.entries) {
        final k = int.tryParse('${e.key}');
        if (k != null && e.value is int) s.kinds[k] = e.value as int;
      }
    }
    s
      ..rng = n('rng')
      ..score = n('score')
      ..combo = n('combo')
      ..bestCombo = n('bestCombo')
      ..rows = n('rows')
      ..multi = n('multi')
      ..bestWave = n('bestWave')
      ..moves = n('moves')
      ..sets = n('sets')
      ..sandCleared = n('sand')
      ..obstacles = n('obstacles')
      ..golden = n('golden')
      ..perfect = n('perfect')
      ..bonusMoves = n('bonusMoves')
      ..status = Status.values.firstWhere(
        (v) => v.name == json['status'],
        orElse: () => throw const FormatException('Invalid status'),
      )
      ..reason = json['reason'] is String ? json['reason'] as String : '';
    if (s.tray.every((p) => p == null) && s.isPlaying) {
      throw const FormatException('Empty tray');
    }
    return s;
  }
}

int _pick(SeededRng rng, List<int> weights) {
  final total = weights.fold(0, (a, b) => a + b);
  var x = rng.nextInt(total);
  for (var i = 0; i < weights.length; i++) {
    if (x < weights[i]) return i;
    x -= weights[i];
  }
  return weights.length - 1;
}

int _pickKind(SeededRng rng, Map<int, int> table) {
  if (table.isEmpty) return SandKind.normal;
  var x = rng.nextInt(100);
  for (final k in SandKind.order) {
    final p = table[k] ?? 0;
    if (x < p) return k;
    x -= p;
  }
  return SandKind.normal;
}

/// Deals three new pieces (uses and advances [GameState.rng]).
void deal(GameState s, GameConfig cfg) {
  final rng = SeededRng(s.rng);
  final table = specialsFor(cfg, s.score);
  final weights = weightsFor(cfg, s.score, s.board.emptyCount());
  final pieces = <Piece>[];
  for (var n = 0; n < 3; n++) {
    final sid = _pick(rng, weights);
    final colour = cfg.palette[rng.nextInt(cfg.palette.length)];
    final kind = _pickKind(rng, table);
    pieces.add(Piece(sid, colour, kind));
  }
  // Fairness: never deal a set in which nothing fits while something could.
  if (!pieces.any((p) => fitsAnywhere(s.board, p.shape))) {
    final order = List<int>.generate(shapes.length, (i) => i)
      ..sort((a, b) {
        final d = shapes[b].size - shapes[a].size;
        return d != 0 ? d : a - b;
      });
    for (final sid in order) {
      if (weights[sid] > 0 && fitsAnywhere(s.board, sid)) {
        pieces[0] = Piece(sid, pieces[0].colour, pieces[0].kind);
        break;
      }
    }
  }
  s.rng = rng.state;
  s.tray = List<Piece?>.of(pieces);
  s.sets++;
}

GameState newGame(GameConfig cfg) {
  final layout = cfg.layout;
  final s = GameState(
    layout != null ? boardFromLayout(layout, lockRows: cfg.lockRows) : Board(),
  );
  s.rng = cfg.seed;
  deal(s, cfg);
  return s;
}

int objectiveValue(GameState s, Objective o) {
  final v = switch (o.type) {
    ObjectiveType.rows => s.rows,
    ObjectiveType.score => s.score,
    ObjectiveType.multi => s.multi,
    ObjectiveType.special => s.kinds[o.kind] ?? 0,
    ObjectiveType.obstacles => s.obstacles,
  };
  return v < o.target ? v : o.target;
}

bool objectivesMet(GameState s, GameConfig cfg) =>
    cfg.objectives.isNotEmpty &&
    cfg.objectives.every((o) => objectiveValue(s, o) >= o.target);

bool anyFits(GameState s) {
  for (final p in [...s.tray, s.bonus]) {
    if (p != null && fitsAnywhere(s.board, p.shape)) return true;
  }
  return false;
}

// ---------------------------------------------------------------- turns

/// One animated stage of a turn.
sealed class Phase {}

class SettlePhase extends Phase {
  SettlePhase(this.steps);
  final List<SettleStep> steps;
}

class WavePhase extends Phase {
  WavePhase(this.wave);
  final Wave wave;
}

/// Power-up removal (Sweep, Colour Blast, Bomb, Crusher, Continue).
class BlastPhase extends Phase {
  BlastPhase(this.wave);
  final Wave wave;
}

class StickyPhase extends Phase {
  StickyPhase(this.expired);
  final List<int> expired;
}

class MoversPhase extends Phase {
  MoversPhase(this.moved);

  /// (id, from, to)
  final List<(int, int, int)> moved;
}

class ShufflePhase extends Phase {
  ShufflePhase(this.indices, this.cells);
  final List<int> indices;

  /// The cells now at [indices] (same order).
  final List<Cell?> cells;
}

class FillPhase extends Phase {
  FillPhase(this.filled);

  /// (id, index)
  final List<(int, int)> filled;
}

class Turn {
  final List<(int, int)> placed = [];

  /// Colour and (revealed) kind of the placed piece.
  int placedColour = 0;
  int placedKind = SandKind.normal;
  int? revealed;
  final List<Phase> phases = [];
  int points = 0;
  int rows = 0;
  bool dealt = false;

  int get waves => phases.whereType<WavePhase>().length;

  /// Most rows cleared by one wave of this turn.
  int get biggestWave {
    var m = 0;
    for (final p in phases) {
      if (p is WavePhase && p.wave.rows.length > m) m = p.wave.rows.length;
    }
    return m;
  }
}

int _resolve(GameState s, GameConfig cfg, Turn turn, int waveIndex) {
  final b = s.board;
  while (waveIndex < 30) {
    final steps = settle(b);
    if (steps.isNotEmpty) {
      turn.phases.add(SettlePhase(steps));
      for (final st in steps) {
        s.obstacles += st.fills.length;
      }
    }
    final rows = fullRows(b);
    if (rows.isEmpty) break;
    final w = clearWave(b, rows);
    w.points = wavePoints(w, s.combo, waveIndex);
    turn.phases.add(WavePhase(w));
    turn.points += w.points;
    turn.rows += rows.length;
    s.score += w.points;
    s.rows += rows.length;
    if (rows.length > s.bestWave) s.bestWave = rows.length;
    if (rows.length >= 2) s.multi++;
    s.sandCleared += w.sand;
    s.obstacles += w.obstacles;
    for (final e in w.kinds.entries) {
      s.kinds[e.key] = (s.kinds[e.key] ?? 0) + e.value;
    }
    s.golden += w.kinds[SandKind.golden] ?? 0;
    waveIndex++;
  }
  return waveIndex;
}

int _endTurnEffects(GameState s, GameConfig cfg, Turn turn, int waveIndex) {
  final b = s.board;
  final expired = <int>[];
  for (var i = 0; i < boardN; i++) {
    final cell = b.cells[i];
    if (cell != null &&
        cell.isSand &&
        cell.kind == SandKind.sticky &&
        cell.ttl > 0) {
      final ttl = cell.ttl - 1;
      b.cells[i] = cell.copyWith(
        ttl: ttl,
        kind: ttl > 0 ? SandKind.sticky : SandKind.normal,
      );
      if (ttl == 0) expired.add(i);
    }
  }
  if (expired.isNotEmpty) {
    turn.phases.add(StickyPhase(expired));
    waveIndex = _resolve(s, cfg, turn, waveIndex);
  }
  final movers = [
    for (var i = 0; i < boardN; i++)
      if (b.cells[i]?.obstacle == Obstacle.mover) i,
  ];
  final moved = <(int, int, int)>[];
  for (final i in movers) {
    final cell = b.cells[i];
    if (cell == null || cell.obstacle != Obstacle.mover) continue;
    final r = i ~/ boardW;
    final c = i % boardW;
    final d = cell.ttl;
    int? target;
    var dir = 0;
    for (final dd in [d, -d]) {
      final nc = c + dd;
      if (nc >= 0 && nc < boardW && b.cells[r * boardW + nc] == null) {
        target = r * boardW + nc;
        dir = dd;
        break;
      }
    }
    if (target == null) {
      b.cells[i] = cell.copyWith(ttl: -d);
      continue;
    }
    b.cells[i] = null;
    b.cells[target] = cell.copyWith(ttl: dir);
    moved.add((cell.id, i, target));
  }
  if (moved.isNotEmpty) {
    turn.phases.add(MoversPhase(moved));
    waveIndex = _resolve(s, cfg, turn, waveIndex);
  }
  return waveIndex;
}

void _finishTurn(GameState s, Turn turn) {
  if (turn.rows > 0) {
    s.combo++;
    if (s.combo > s.bestCombo) s.bestCombo = s.combo;
    if (s.board.sandCount() == 0) {
      s.score += 1000;
      turn.points += 1000;
      s.perfect++;
    }
  } else {
    s.combo = 0;
  }
}

void updateStatus(GameState s, GameConfig cfg) {
  if (objectivesMet(s, cfg)) {
    s.status = Status.won;
    s.reason = 'objectives';
  } else if (cfg.moveLimit > 0 && s.moves >= cfg.moveLimit + s.bonusMoves) {
    s.status = Status.lost;
    s.reason = 'moves';
  } else if (!anyFits(s)) {
    s.status = Status.lost;
    s.reason = 'space';
  }
}

/// Ends a Time Challenge when its clock runs out.
void endForTime(GameState s) {
  if (!s.isPlaying) return;
  s.status = Status.lost;
  s.reason = 'time';
}

/// Plays one piece (slot 3 = bonus piece). Returns null if illegal.
Turn? place(GameState s, GameConfig cfg, int slot, int r0, int c0) {
  if (!s.isPlaying || slot < 0 || slot > 3) return null;
  final piece = slot == 3 ? s.bonus : s.tray[slot];
  if (piece == null || !canPlace(s.board, piece.shape, r0, c0)) return null;
  final b = s.board;
  final turn = Turn();
  var kind = piece.kind;
  if (kind == SandKind.mystery) {
    final rng = SeededRng(s.rng);
    kind = SandKind.mysteryReveal[rng.nextInt(SandKind.mysteryReveal.length)];
    s.rng = rng.state;
    turn.revealed = kind;
  }
  turn.placedColour = piece.colour;
  turn.placedKind = kind;
  for (final (dr, dc) in shapes[piece.shape].cells) {
    final i = (r0 + dr) * boardW + (c0 + dc);
    final id = b.newId();
    b.cells[i] = Cell(
      id,
      piece.colour,
      kind: kind,
      ttl: kind == SandKind.sticky ? stickyTtl : 0,
    );
    turn.placed.add((id, i));
  }
  final n = turn.placed.length;
  s.score += n;
  turn.points += n;
  if (slot == 3) {
    s.bonus = null;
  } else {
    s.tray[slot] = null;
  }
  final wi = _resolve(s, cfg, turn, 0);
  _endTurnEffects(s, cfg, turn, wi);
  _finishTurn(s, turn);
  s.moves++;
  if (s.tray.every((p) => p == null)) {
    deal(s, cfg);
    turn.dealt = true;
  }
  updateStatus(s, cfg);
  return turn;
}

// ---------------------------------------------------------------- power-ups

enum PowerUp {
  sweep,
  blast,
  shaker,
  rowClear,
  crusher,
  gravity,
  bomb,
  extra;

  /// How the player chooses where it applies.
  PowerTarget get target => switch (this) {
    sweep || rowClear => PowerTarget.row,
    blast => PowerTarget.colour,
    shaker || crusher || bomb => PowerTarget.cell,
    gravity => PowerTarget.side,
    extra => PowerTarget.none,
  };
}

enum PowerTarget { row, colour, cell, side, none }

Wave _removeCells(
  GameState s,
  List<int> indices,
  Turn turn, {
  bool scored = true,
}) {
  final b = s.board;
  final w = Wave(const []);
  for (final i in indices) {
    final cell = b.cells[i];
    if (cell == null) continue;
    if (!cell.isSand &&
        (cell.obstacle == Obstacle.unbreakable ||
            cell.obstacle == Obstacle.locked ||
            cell.obstacle == Obstacle.trap)) {
      continue;
    }
    b.cells[i] = null;
    w.removed.add(Removed(cell.id, i, cell.colour, cell.kind, cell.obstacle));
    if (cell.isSand) {
      w.sand++;
      w.kinds[cell.kind] = (w.kinds[cell.kind] ?? 0) + 1;
    } else {
      w.obstacles++;
    }
  }
  w.points = scored ? 10 * (w.sand + w.obstacles) : 0;
  s.score += w.points;
  turn.points += w.points;
  s.sandCleared += w.sand;
  s.obstacles += w.obstacles;
  for (final e in w.kinds.entries) {
    s.kinds[e.key] = (s.kinds[e.key] ?? 0) + e.value;
  }
  s.golden += w.kinds[SandKind.golden] ?? 0;
  turn.phases.add(BlastPhase(w));
  return w;
}

List<int> _area(int index) {
  final r = index ~/ boardW;
  final c = index % boardW;
  return [
    for (final dr in const [-1, 0, 1])
      for (final dc in const [-1, 0, 1])
        if (r + dr >= 0 && r + dr < boardH && c + dc >= 0 && c + dc < boardW)
          (r + dr) * boardW + (c + dc),
  ];
}

/// Whether [p] would do anything with [arg] (for highlighting targets).
bool powerApplies(GameState s, GameConfig cfg, PowerUp p, int? arg) =>
    power(s.copy(), cfg, p, arg) != null;

/// Applies a power-up (see core.py `power`). Returns null if it cannot be
/// used there; the state is then unchanged.
Turn? power(GameState s, GameConfig cfg, PowerUp p, int? arg) {
  if (!s.isPlaying) return null;
  final b = s.board;
  final turn = Turn();
  switch (p) {
    case PowerUp.sweep:
      if (arg == null || arg < 0 || arg >= boardH) return null;
      final idx = [for (var c = 0; c < boardW; c++) arg * boardW + c];
      if (idx.every((i) => b.cells[i] == null)) return null;
      _removeCells(s, idx, turn);
    case PowerUp.blast:
      if (arg == null) return null;
      final idx = [
        for (var i = 0; i < boardN; i++)
          if (b.cells[i] != null &&
              b.cells[i]!.isSand &&
              (b.cells[i]!.colour == arg ||
                  b.cells[i]!.kind == SandKind.rainbow))
            i,
      ];
      if (idx.isEmpty) return null;
      _removeCells(s, idx, turn);
    case PowerUp.bomb:
      if (arg == null || arg < 0 || arg >= boardN) return null;
      final idx = _area(arg);
      if (idx.every((i) => b.cells[i] == null)) return null;
      _removeCells(s, idx, turn);
    case PowerUp.crusher:
      if (arg == null || arg < 0 || arg >= boardN) return null;
      final cell = b.cells[arg];
      if (cell == null || !cell.isSand) return null;
      final group = <int>[];
      final seen = {arg};
      final q = <int>[arg];
      var head = 0;
      while (head < q.length && group.length < 12) {
        final i = q[head++];
        group.add(i);
        final r = i ~/ boardW;
        final c = i % boardW;
        for (final (nr, nc) in [
          (r - 1, c),
          (r + 1, c),
          (r, c - 1),
          (r, c + 1),
        ]) {
          final j = nr * boardW + nc;
          if (nr >= 0 &&
              nr < boardH &&
              nc >= 0 &&
              nc < boardW &&
              !seen.contains(j)) {
            final t = b.cells[j];
            if (t != null && t.isSand && t.colour == cell.colour) {
              seen.add(j);
              q.add(j);
            }
          }
        }
      }
      _removeCells(s, group, turn);
    case PowerUp.shaker:
      if (arg == null || arg < 0 || arg >= boardN) return null;
      final loose = [
        for (final i in _area(arg))
          if (movable(b, i)) i,
      ];
      if (loose.length < 2) return null;
      final cells = [for (final i in loose) b.cells[i]];
      final rng = SeededRng(s.rng);
      for (var k = cells.length - 1; k > 0; k--) {
        final j = rng.nextInt(k + 1);
        final t = cells[k];
        cells[k] = cells[j];
        cells[j] = t;
      }
      s.rng = rng.state;
      for (var n = 0; n < loose.length; n++) {
        b.cells[loose[n]] = cells[n];
      }
      turn.phases.add(ShufflePhase(loose, cells));
    case PowerUp.rowClear:
      if (arg == null || arg < 0 || arg >= boardH) return null;
      final idx = [for (var c = 0; c < boardW; c++) arg * boardW + c];
      final gaps = [
        for (final i in idx)
          if (b.cells[i] == null) i,
      ];
      if (gaps.isEmpty || gaps.length > 3) return null;
      if (idx.any((i) => b.cells[i]?.obstacle == Obstacle.trap)) return null;
      final filled = <(int, int)>[];
      for (final i in gaps) {
        final id = b.newId();
        b.cells[i] = Cell(id, greyColour, kind: SandKind.frozen);
        filled.add((id, i));
      }
      turn.phases.add(FillPhase(filled));
    case PowerUp.gravity:
      if (arg != -1 && arg != 1) return null;
      final steps = shiftSideways(b, arg!);
      if (steps.isEmpty) return null;
      turn.phases.add(SettlePhase(steps));
      for (final st in steps) {
        s.obstacles += st.fills.length;
      }
    case PowerUp.extra:
      if (s.bonus != null) return null;
      s.bonus = Piece(0, cfg.palette[0]);
      if (cfg.moveLimit > 0) s.bonusMoves++;
      updateStatus(s, cfg);
      return turn;
  }
  _resolve(s, cfg, turn, 0);
  _finishTurn(s, turn);
  updateStatus(s, cfg);
  return turn;
}

/// Rewarded "Keep playing?": after a game ended for lack of space, the
/// bottom three rows are removed and a fresh set of pieces is dealt.
Turn? continueGame(GameState s, GameConfig cfg) {
  if (s.status != Status.lost || s.reason != 'space') return null;
  s.status = Status.playing;
  s.reason = '';
  final turn = Turn();
  _removeCells(
    s,
    [for (var i = (boardH - 3) * boardW; i < boardN; i++) i],
    turn,
    scored: false,
  );
  deal(s, cfg);
  turn.dealt = true;
  _resolve(s, cfg, turn, 0);
  _finishTurn(s, turn);
  updateStatus(s, cfg);
  return turn;
}

// ---------------------------------------------------------------- bot

typedef Move = (int slot, int row, int col);

List<Move> _placements(GameState s) {
  final out = <Move>[];
  final slots = <(int, Piece)>[
    for (var i = 0; i < 3; i++)
      if (s.tray[i] != null) (i, s.tray[i]!),
    if (s.bonus != null) (3, s.bonus!),
  ];
  for (final (slot, p) in slots) {
    for (var c0 = 0; c0 < boardW; c0++) {
      int? first;
      int? last;
      for (var r0 = 0; r0 < boardH; r0++) {
        if (canPlace(s.board, p.shape, r0, c0)) {
          first ??= r0;
          last = r0;
        }
      }
      if (first == null) continue;
      out.add((slot, first, c0));
      if (last != first) out.add((slot, last!, c0));
    }
  }
  return out;
}

int evaluate(GameState s, GameConfig cfg) {
  if (s.status == Status.won) return 10000000 - s.moves * 1000;
  if (s.status == Status.lost) return -10000000;
  var v = 0;
  for (final o in cfg.objectives) {
    v += objectiveValue(s, o) * 1000 ~/ o.target * 20;
  }
  final hs = s.board.heights();
  final maxH = hs.fold(0, (a, b) => a > b ? a : b);
  final sumH = hs.fold(0, (a, b) => a + b);
  v -= maxH * 40 + sumH * 4 + s.board.holes() * 60;
  v += s.score ~/ 4;
  if (cfg.objectives.any((o) => o.type == ObjectiveType.multi)) {
    for (var r = 0; r < boardH; r++) {
      var f = 0;
      for (var c = 0; c < boardW; c++) {
        final cell = s.board.cells[r * boardW + c];
        if (cell != null && cell.obstacle != Obstacle.trap) f++;
      }
      v += f * f * 2;
    }
  }
  return v;
}

/// The bot's move (the hint), or null if nothing can be placed.
Move? bestMove(GameState s, GameConfig cfg) {
  Move? best;
  int? bestV;
  for (final m in _placements(s)) {
    final s2 = s.copy();
    place(s2, cfg, m.$1, m.$2, m.$3);
    final v = evaluate(s2, cfg);
    if (bestV == null || v > bestV) {
      best = m;
      bestV = v;
    }
  }
  return best;
}

/// Plays a whole game with the bot. Returns the final state and its moves.
(GameState, List<Move>) playBot(GameConfig cfg, {int maxMoves = 200}) {
  final s = newGame(cfg);
  final log = <Move>[];
  while (s.isPlaying && s.moves < maxMoves) {
    final m = bestMove(s, cfg);
    if (m == null) break;
    place(s, cfg, m.$1, m.$2, m.$3);
    log.add(m);
  }
  return (s, log);
}
