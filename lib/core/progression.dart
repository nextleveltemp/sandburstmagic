/// Progression rules in plain Dart: coins, power-up inventory and prices,
/// cosmetics, daily missions, achievements, records and statistics.
library;

import 'engine.dart';
import 'levels.dart';
import 'rng.dart';

// ===========================================================================
// Dates
// ===========================================================================

abstract final class DateKey {
  static String fromDateTime(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses `YYYY-MM-DD` into a UTC midnight [DateTime]; null if malformed.
  static DateTime? parse(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime.utc(y, m, d);
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  }

  static int dayIndex(String key) {
    final dt = parse(key);
    if (dt == null) throw FormatException('Bad date key $key');
    return dt.difference(DateTime.utc(2025, 1, 1)).inDays;
  }

  static int daysBetween(String a, String b) => dayIndex(b) - dayIndex(a);

  static String addDays(String key, int days) {
    final dt = parse(key);
    if (dt == null) throw FormatException('Bad date key $key');
    return fromDateTime(dt.add(Duration(days: days)));
  }
}

int _nonNeg(Object? v) => v is int && v >= 0 ? v : 0;

Map<String, int> _intMap(Object? v) {
  final out = <String, int>{};
  if (v is Map) {
    for (final e in v.entries) {
      final k = e.key;
      final val = e.value;
      if (k is String && val is int && val >= 0) out[k] = val;
    }
  }
  return out;
}

// ===========================================================================
// Coins
// ===========================================================================

abstract final class Coins {
  static const int starting = 150;

  /// Coins from one finished game: one per cleared row, five per golden
  /// grain.
  static int forGame({required int rows, required int golden}) =>
      rows + 5 * golden;

  /// First win of a campaign level.
  static int forLevelFirst(int stars) => 20 + 10 * stars;

  /// Replay that earned more stars.
  static int forBetterStars(int oldStars, int newStars) =>
      newStars > oldStars ? 10 * (newStars - oldStars) : 0;

  static int forDaily(int streak) => 50 + 10 * (streak < 7 ? streak : 7);

  static const int mission = 30;
  static const int allMissions = 50;
  static const int rewardedBonus = 40;
}

// ===========================================================================
// Power-ups
// ===========================================================================

abstract final class PowerShop {
  static int price(PowerUp p) => switch (p) {
    PowerUp.sweep => 60,
    PowerUp.blast => 90,
    PowerUp.shaker => 40,
    PowerUp.rowClear => 60,
    PowerUp.crusher => 50,
    PowerUp.gravity => 70,
    PowerUp.bomb => 60,
    PowerUp.extra => 80,
  };

  static const Map<PowerUp, int> starting = {
    PowerUp.sweep: 1,
    PowerUp.bomb: 1,
    PowerUp.extra: 1,
  };

  /// Gifts for finishing a world (its last level, first time).
  static Map<PowerUp, int> worldGift(int world) => switch (world) {
    1 => {PowerUp.sweep: 1, PowerUp.shaker: 2},
    2 => {PowerUp.bomb: 1, PowerUp.crusher: 2},
    3 => {PowerUp.rowClear: 2, PowerUp.gravity: 1},
    4 => {PowerUp.blast: 1, PowerUp.bomb: 2},
    5 => {PowerUp.extra: 2, PowerUp.sweep: 2},
    _ => {PowerUp.blast: 2, PowerUp.extra: 2},
  };
}

// ===========================================================================
// Cosmetics
// ===========================================================================

enum CosmeticKind { board, palette, grain, burst, piece }

class Cosmetic {
  const Cosmetic(this.kind, this.id, this.price, {this.world = 0});
  final CosmeticKind kind;
  final String id;
  final int price;

  /// Board themes: also unlocked free by reaching this world (0: none).
  final int world;

  String get key => '${kind.name}.$id';
}

abstract final class Cosmetics {
  static const all = <Cosmetic>[
    Cosmetic(CosmeticKind.board, 'midnight', 0),
    Cosmetic(CosmeticKind.board, 'candy', 400, world: 1),
    Cosmetic(CosmeticKind.board, 'crystal', 400, world: 2),
    Cosmetic(CosmeticKind.board, 'ocean', 400, world: 3),
    Cosmetic(CosmeticKind.board, 'sunset', 400, world: 4),
    Cosmetic(CosmeticKind.board, 'forest', 400, world: 5),
    Cosmetic(CosmeticKind.board, 'cosmic', 400, world: 6),
    Cosmetic(CosmeticKind.board, 'daylight', 0),
    Cosmetic(CosmeticKind.palette, 'classic', 0),
    Cosmetic(CosmeticKind.palette, 'pastel', 250),
    Cosmetic(CosmeticKind.palette, 'neon', 350),
    Cosmetic(CosmeticKind.palette, 'jewel', 450),
    Cosmetic(CosmeticKind.grain, 'round', 0),
    Cosmetic(CosmeticKind.grain, 'pixel', 200),
    Cosmetic(CosmeticKind.grain, 'sparkle', 300),
    Cosmetic(CosmeticKind.grain, 'glass', 400),
    Cosmetic(CosmeticKind.burst, 'sparks', 0),
    Cosmetic(CosmeticKind.burst, 'stars', 250),
    Cosmetic(CosmeticKind.burst, 'confetti', 300),
    Cosmetic(CosmeticKind.burst, 'rings', 400),
    Cosmetic(CosmeticKind.piece, 'glossy', 0),
    Cosmetic(CosmeticKind.piece, 'flat', 150),
    Cosmetic(CosmeticKind.piece, 'outline', 250),
  ];

  static Iterable<Cosmetic> ofKind(CosmeticKind k) =>
      all.where((c) => c.kind == k);

  static Cosmetic? byKey(String key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  static String defaultId(CosmeticKind k) => ofKind(k).first.id;
}

// ===========================================================================
// Records
// ===========================================================================

class LevelRecord {
  const LevelRecord({this.stars = 0, this.bestMoves = 0, this.bestScore = 0});
  final int stars;
  final int bestMoves;
  final int bestScore;

  Map<String, Object?> toJson() => {
    'stars': stars,
    'moves': bestMoves,
    'score': bestScore,
  };

  static LevelRecord fromJson(Object? json) {
    if (json is! Map) return const LevelRecord();
    final s = _nonNeg(json['stars']);
    return LevelRecord(
      stars: s > 3 ? 3 : s,
      bestMoves: _nonNeg(json['moves']),
      bestScore: _nonNeg(json['score']),
    );
  }
}

/// Daily puzzle history and streak. If the device clock moves back, daily
/// rewards pause until the date catches up, and each date is rewarded once.
class DailyRecord {
  DailyRecord({
    List<String>? completedDates,
    this.lastCompleted,
    this.streak = 0,
    this.bestStreak = 0,
    this.latestSeenDate,
  }) : completedDates = completedDates ?? <String>[];

  static const int historyLimit = 400;

  final List<String> completedDates;
  String? lastCompleted;
  int streak;
  int bestStreak;
  String? latestSeenDate;

  bool isCompleted(String date) => completedDates.contains(date);

  bool observeDate(String today) {
    final latest = latestSeenDate;
    if (latest == null || DateKey.daysBetween(latest, today) > 0) {
      latestSeenDate = today;
      return true;
    }
    return DateKey.daysBetween(latest, today) >= 0;
  }

  bool clockRolledBack(String today) {
    final latest = latestSeenDate;
    return latest != null && DateKey.daysBetween(latest, today) < 0;
  }

  int currentStreak(String today) {
    final last = lastCompleted;
    if (last == null) return 0;
    final gap = DateKey.daysBetween(last, today);
    return gap == 0 || gap == 1 ? streak : 0;
  }

  bool recordCompletion(String date, {required bool rewardsAllowed}) {
    if (isCompleted(date) || !rewardsAllowed) return false;
    final last = lastCompleted;
    if (last != null && DateKey.daysBetween(last, date) < 0) return false;
    completedDates.add(date);
    if (completedDates.length > historyLimit) {
      completedDates.removeRange(0, completedDates.length - historyLimit);
    }
    if (last != null && DateKey.daysBetween(last, date) == 1) {
      streak += 1;
    } else {
      streak = 1;
    }
    if (streak > bestStreak) bestStreak = streak;
    lastCompleted = date;
    return true;
  }

  Map<String, Object?> toJson() => {
    'completedDates': List<String>.of(completedDates),
    'lastCompleted': lastCompleted,
    'streak': streak,
    'bestStreak': bestStreak,
    'latestSeenDate': latestSeenDate,
  };

  static DailyRecord fromJson(Object? json) {
    if (json is! Map) return DailyRecord();
    final dates = <String>[];
    final raw = json['completedDates'];
    if (raw is List) {
      for (final d in raw) {
        if (d is String && DateKey.parse(d) != null) dates.add(d);
      }
    }
    String? date(Object? v) =>
        v is String && DateKey.parse(v) != null ? v : null;
    return DailyRecord(
      completedDates: dates,
      lastCompleted: date(json['lastCompleted']),
      streak: _nonNeg(json['streak']),
      bestStreak: _nonNeg(json['bestStreak']),
      latestSeenDate: date(json['latestSeenDate']),
    );
  }
}

/// Lifetime counts of what actually happened.
class LifetimeStats {
  LifetimeStats({
    Map<String, int>? gamesByMode,
    Map<String, int>? bestByMode,
    this.rows = 0,
    this.sand = 0,
    this.pieces = 0,
    this.bestCombo = 0,
    this.bestWave = 0,
    this.multi = 0,
    this.perfect = 0,
    this.golden = 0,
    this.powerUps = 0,
    this.hints = 0,
    this.undos = 0,
    this.playSeconds = 0,
    this.coinsEarned = 0,
    this.movesWins = 0,
  }) : gamesByMode = gamesByMode ?? <String, int>{},
       bestByMode = bestByMode ?? <String, int>{};

  final Map<String, int> gamesByMode;
  final Map<String, int> bestByMode;
  int rows;
  int sand;
  int pieces;
  int bestCombo;
  int bestWave;
  int multi;
  int perfect;
  int golden;
  int powerUps;
  int hints;
  int undos;
  int playSeconds;
  int coinsEarned;

  /// Limited Moves games won (raises its target).
  int movesWins;

  int get gamesPlayed => gamesByMode.values.fold(0, (a, b) => a + b);

  int best(GameMode m) => bestByMode[m.name] ?? 0;

  Map<String, Object?> toJson() => {
    'games': Map<String, int>.of(gamesByMode),
    'best': Map<String, int>.of(bestByMode),
    'rows': rows,
    'sand': sand,
    'pieces': pieces,
    'bestCombo': bestCombo,
    'bestWave': bestWave,
    'multi': multi,
    'perfect': perfect,
    'golden': golden,
    'powerUps': powerUps,
    'hints': hints,
    'undos': undos,
    'seconds': playSeconds,
    'coins': coinsEarned,
    'movesWins': movesWins,
  };

  static LifetimeStats fromJson(Object? json) {
    if (json is! Map) return LifetimeStats();
    return LifetimeStats(
      gamesByMode: _intMap(json['games']),
      bestByMode: _intMap(json['best']),
      rows: _nonNeg(json['rows']),
      sand: _nonNeg(json['sand']),
      pieces: _nonNeg(json['pieces']),
      bestCombo: _nonNeg(json['bestCombo']),
      bestWave: _nonNeg(json['bestWave']),
      multi: _nonNeg(json['multi']),
      perfect: _nonNeg(json['perfect']),
      golden: _nonNeg(json['golden']),
      powerUps: _nonNeg(json['powerUps']),
      hints: _nonNeg(json['hints']),
      undos: _nonNeg(json['undos']),
      playSeconds: _nonNeg(json['seconds']),
      coinsEarned: _nonNeg(json['coins']),
      movesWins: _nonNeg(json['movesWins']),
    );
  }
}

// ===========================================================================
// Daily missions
// ===========================================================================

enum MissionMetric { rows, multi, pieces, games, special, powerUp, level, score }

class MissionDef {
  const MissionDef(this.id, this.metric, this.target);
  final String id;
  final MissionMetric metric;
  final int target;
}

abstract final class Missions {
  static const pool = <MissionDef>[
    MissionDef('rows15', MissionMetric.rows, 15),
    MissionDef('rows30', MissionMetric.rows, 30),
    MissionDef('multi1', MissionMetric.multi, 1),
    MissionDef('multi3', MissionMetric.multi, 3),
    MissionDef('pieces40', MissionMetric.pieces, 40),
    MissionDef('games3', MissionMetric.games, 3),
    MissionDef('special10', MissionMetric.special, 10),
    MissionDef('power1', MissionMetric.powerUp, 1),
    MissionDef('level2', MissionMetric.level, 2),
    MissionDef('score3000', MissionMetric.score, 3000),
  ];

  static MissionDef? byId(String id) {
    for (final m in pool) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Three missions for [date], the same for everyone, never two with the
  /// same metric.
  static List<MissionDef> forDate(String date) {
    final rng = SeededRng(SeededRng.hashString('sbm-missions-$date'));
    final out = <MissionDef>[];
    final left = List<MissionDef>.of(pool);
    while (out.length < 3 && left.isNotEmpty) {
      final m = left.removeAt(rng.nextInt(left.length));
      if (out.any((o) => o.metric == m.metric)) continue;
      out.add(m);
    }
    return out;
  }
}

class MissionsState {
  MissionsState(this.date, Map<String, int>? progress, Set<String>? claimed)
    : progress = progress ?? <String, int>{},
      claimed = claimed ?? <String>{};

  final String date;
  final Map<String, int> progress;
  final Set<String> claimed;

  static const String allId = 'all';

  List<MissionDef> get missions => Missions.forDate(date);

  int valueOf(MissionDef m) {
    final v = progress[m.id] ?? 0;
    return v > m.target ? m.target : v;
  }

  bool isDone(MissionDef m) => valueOf(m) >= m.target;

  /// Adds [amount] to every mission measuring [metric] ([max] metrics such
  /// as a game's score keep the best value). Returns missions just done.
  List<MissionDef> bump(MissionMetric metric, int amount, {bool max = false}) {
    final done = <MissionDef>[];
    for (final m in missions) {
      if (m.metric != metric || isDone(m)) continue;
      final cur = progress[m.id] ?? 0;
      progress[m.id] = max ? (amount > cur ? amount : cur) : cur + amount;
      if (isDone(m)) done.add(m);
    }
    return done;
  }

  Map<String, Object?> toJson() => {
    'date': date,
    'progress': Map<String, int>.of(progress),
    'claimed': claimed.toList()..sort(),
  };

  static MissionsState? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = json['date'];
    if (date is! String || DateKey.parse(date) == null) return null;
    final claimed = json['claimed'];
    return MissionsState(date, _intMap(json['progress']), {
      if (claimed is List)
        for (final c in claimed)
          if (c is String) c,
    });
  }
}

// ===========================================================================
// Achievements
// ===========================================================================

class AchievementContext {
  const AchievementContext({
    required this.stats,
    required this.levelsCompleted,
    required this.stars,
    required this.bestDailyStreak,
    required this.bestClassic,
    required this.worldsDone,
  });

  final LifetimeStats stats;
  final int levelsCompleted;
  final int stars;
  final int bestDailyStreak;
  final int bestClassic;
  final int worldsDone;
}

class AchievementDef {
  const AchievementDef(this.id, this.coins, this.test);
  final String id;
  final int coins;
  final bool Function(AchievementContext c) test;
}

abstract final class Achievements {
  static final List<AchievementDef> all = [
    AchievementDef('firstRow', 25, (c) => c.stats.rows >= 1),
    AchievementDef('rows100', 50, (c) => c.stats.rows >= 100),
    AchievementDef('rows1000', 100, (c) => c.stats.rows >= 1000),
    AchievementDef('double', 25, (c) => c.stats.bestWave >= 2),
    AchievementDef('triple', 50, (c) => c.stats.bestWave >= 3),
    AchievementDef('quad', 100, (c) => c.stats.bestWave >= 4),
    AchievementDef('combo5', 50, (c) => c.stats.bestCombo >= 5),
    AchievementDef('combo10', 100, (c) => c.stats.bestCombo >= 10),
    AchievementDef('score5000', 50, (c) => c.bestClassic >= 5000),
    AchievementDef('score15000', 100, (c) => c.bestClassic >= 15000),
    AchievementDef('perfect', 100, (c) => c.stats.perfect >= 1),
    AchievementDef('sand5000', 50, (c) => c.stats.sand >= 5000),
    AchievementDef('golden50', 50, (c) => c.stats.golden >= 50),
    AchievementDef('powers10', 25, (c) => c.stats.powerUps >= 10),
    AchievementDef('level10', 25, (c) => c.levelsCompleted >= 10),
    AchievementDef('world1', 50, (c) => c.worldsDone >= 1),
    AchievementDef('world3', 100, (c) => c.worldsDone >= 3),
    AchievementDef('allLevels', 200, (c) => c.levelsCompleted >= 100),
    AchievementDef('stars150', 100, (c) => c.stars >= 150),
    AchievementDef('streak3', 25, (c) => c.bestDailyStreak >= 3),
    AchievementDef('streak7', 50, (c) => c.bestDailyStreak >= 7),
    AchievementDef('streak30', 150, (c) => c.bestDailyStreak >= 30),
  ];

  static AchievementDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static List<AchievementDef> newlyUnlocked(
    AchievementContext ctx,
    Set<String> already,
  ) => [
    for (final a in all)
      if (!already.contains(a.id) && a.test(ctx)) a,
  ];
}

// ===========================================================================
// Stars
// ===========================================================================

abstract final class Stars {
  static int total(Map<int, LevelRecord> levels) =>
      levels.values.fold(0, (a, r) => a + r.stars);

  /// A world is done when its last level is won.
  static int worldsDone(Map<int, LevelRecord> levels) => worlds
      .where((w) => (levels[w.last]?.stars ?? 0) > 0)
      .length;
}
