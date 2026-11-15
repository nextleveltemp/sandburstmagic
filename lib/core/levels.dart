/// Campaign levels (generated and bot-proven by
/// tool/reference_model/gen_levels.py), worlds and the other game modes.
library;

import 'engine.dart';
import 'rng.dart';
import 'sand.dart';

part 'level_data.dart';

enum GameMode { classic, campaign, time, moves, daily, endless }

class World {
  const World(this.id, this.number, this.first, this.last, this.palette);
  final String id;
  final int number;
  final int first;
  final int last;
  final List<int> palette;

  bool contains(int level) => level >= first && level <= last;
  int get count => last - first + 1;
}

const List<World> worlds = [
  World('candy', 1, 1, 17, [6, 9, 2, 7, 0, 1]),
  World('crystal', 2, 18, 34, [7, 9, 4, 2, 5, 6]),
  World('ocean', 3, 35, 51, [4, 7, 3, 9, 5, 2]),
  World('sunset', 4, 52, 68, [1, 8, 0, 2, 6, 5]),
  World('forest', 5, 69, 84, [3, 5, 9, 7, 2, 6]),
  World('cosmic', 6, 85, 100, [5, 6, 7, 4, 2, 0, 3, 1]),
];

World worldOf(int level) =>
    worlds.firstWhere((w) => w.contains(level), orElse: () => worlds.last);

const List<int> classicPalette = [0, 1, 2, 3, 4, 5, 6, 7];

class LevelDef {
  const LevelDef({
    required this.number,
    required this.world,
    required this.objectives,
    required this.moveLimit,
    required this.gentle,
    required this.powerUps,
    required this.specials,
    required this.seed,
    required this.lockRows,
    required this.layout,
    required this.par,
    required this.twoStars,
    required this.threeStars,
    required this.intro,
    required this.solution,
  });

  final int number;
  final int world;
  final List<Objective> objectives;
  final int moveLimit;
  final bool gentle;
  final bool powerUps;
  final Map<int, int> specials;
  final int seed;
  final int lockRows;
  final List<String>? layout;

  /// Moves the bot needed.
  final int par;
  final int twoStars;
  final int threeStars;

  /// The mechanic this level introduces (tutorial card), or ''.
  final String intro;

  /// The bot's winning moves (proof that the level is winnable).
  final List<Move> solution;

  GameConfig config() => GameConfig(
    seed: seed,
    layout: layout,
    lockRows: lockRows,
    objectives: objectives,
    moveLimit: moveLimit,
    weights: gentle ? gentleWeights : defaultWeights,
    palette: worlds[world - 1].palette,
    specials: specials,
    allowPowerUps: powerUps,
  );

  /// Stars for a win that used [moves] pieces.
  int starsFor(int moves) {
    if (moves <= threeStars) return 3;
    if (moves <= twoStars) return 2;
    return 1;
  }

  static LevelDef parse(int number, String line) {
    final f = line.split(';');
    if (f.length != 14) throw FormatException('Level $number: ${f.length}');
    final sol = f[13];
    return LevelDef(
      number: number,
      world: int.parse(f[0]),
      objectives: [for (final o in f[1].split('|')) Objective.parse(o)],
      moveLimit: int.parse(f[2]),
      gentle: f[3] == 'gentle',
      powerUps: f[4] == '1',
      specials: {
        if (f[5].isNotEmpty)
          for (final p in f[5].split('|'))
            int.parse(p.split(':')[0]): int.parse(p.split(':')[1]),
      },
      seed: int.parse(f[6]),
      lockRows: int.parse(f[7]),
      layout: f[8].isEmpty ? null : f[8].split('/'),
      par: int.parse(f[9]),
      twoStars: int.parse(f[10]),
      threeStars: int.parse(f[11]),
      intro: f[12],
      solution: [
        for (var i = 0; i + 2 < sol.length; i += 3)
          (int.parse(sol[i]), int.parse(sol[i + 1]), int.parse(sol[i + 2])),
      ],
    );
  }
}

abstract final class LevelCatalog {
  static final List<LevelDef> all = [
    for (var i = 0; i < _levelLines.length; i++)
      LevelDef.parse(i + 1, _levelLines[i]),
  ];

  static int get count => all.length;

  static LevelDef level(int number) => all[number - 1];
}

/// Rules of the modes that are not campaign levels.
abstract final class Modes {
  static const int timeSeconds = 120;

  /// Seconds added to the Time Challenge clock per cleared row.
  static const int timePerRow = 4;
  static const int limitedMoves = 30;

  static GameConfig classic(int seed) => GameConfig(
    seed: seed,
    palette: classicPalette,
    schedule: Schedule.classic,
  );

  static GameConfig endless(int seed) => GameConfig(
    seed: seed,
    palette: classicPalette,
    schedule: Schedule.endless,
  );

  static GameConfig time(int seed) =>
      GameConfig(seed: seed, palette: classicPalette);

  /// Limited Moves: 30 pieces to reach a target score.
  static GameConfig moves(int seed, int target) => GameConfig(
    seed: seed,
    palette: classicPalette,
    moveLimit: limitedMoves,
    objectives: [Objective(ObjectiveType.score, target)],
  );

  /// Target of Limited Moves, rising slowly with games won (2000..4000).
  static int movesTarget(int wins) {
    final t = 2000 + 100 * wins;
    return t > 4000 ? 4000 : t;
  }
}

/// The Daily Puzzle: the same for everyone on the same date (seeded by the
/// date), with a target the bot proved reachable (60% of the bot's result
/// in the same number of moves).
class DailyPuzzle {
  const DailyPuzzle(this.dateKey, this.config);
  final String dateKey;
  final GameConfig config;

  static const int moves = 25;

  static int seedFor(String dateKey) =>
      SeededRng.hashString('sbm-daily-$dateKey');

  static DailyPuzzle generate(String dateKey) {
    final seed = seedFor(dateKey);
    final rng = SeededRng(seed);
    final world = worlds[rng.nextInt(worlds.length)];
    const kinds = [
      SandKind.crystal,
      SandKind.golden,
      SandKind.explosive,
      SandKind.heavy,
      SandKind.rainbow,
    ];
    final kind = kinds[rng.nextInt(kinds.length)];
    final style = rng.nextInt(3); // 0 rows, 1 score, 2 special
    final board = makeLayout(
      seed ^ 0x5EED5,
      3 + rng.nextInt(3),
      density: 75,
      palette: world.palette,
      obstacles: [(Obstacle.stone, rng.nextInt(3), 5, 9)],
    );
    final layout = layoutText(board);
    GameConfig cfg(List<Objective> objectives) => GameConfig(
      seed: seed,
      layout: layout,
      objectives: objectives,
      moveLimit: moves,
      palette: world.palette,
      specials: {kind: 15},
    );
    // Measure: the bot plays the puzzle with an unreachable goal.
    final probe = switch (style) {
      0 => const Objective(ObjectiveType.rows, 999),
      1 => const Objective(ObjectiveType.score, 999999),
      _ => Objective(ObjectiveType.special, 999, kind),
    };
    final (s, _) = playBot(cfg([probe]), maxMoves: moves);
    final reached = objectiveValue(s, probe);
    var target = reached * 6 ~/ 10;
    if (style == 1) target = target ~/ 50 * 50;
    final minimum = switch (style) {
      0 => 3,
      1 => 400,
      _ => 2,
    };
    if (target < minimum) target = minimum;
    if (target > reached) target = reached;
    // Prove it: the bot must win the real puzzle; lower the goal if not.
    for (var tries = 0; tries < 4 && target > 0; tries++) {
      final real = cfg([Objective(probe.type, target, kind)]);
      final (won, _) = playBot(real, maxMoves: moves);
      if (won.status == Status.won) return DailyPuzzle(dateKey, real);
      final got = objectiveValue(won, real.objectives.first);
      target = got < target ? got : target - 1;
    }
    // Fallback (not expected): a goal the bot met in the probe game.
    return DailyPuzzle(
      dateKey,
      cfg([const Objective(ObjectiveType.score, 100)]),
    );
  }
}
