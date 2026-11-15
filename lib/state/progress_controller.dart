import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/engine.dart';
import '../core/levels.dart';
import '../core/progression.dart';
import '../data/doc_store.dart';
import '../data/docs.dart';
import '../data/models.dart';

/// What a finished game earned (shown on the results panel).
class GameReport {
  GameReport({
    required this.mode,
    required this.won,
    required this.score,
    required this.bestBefore,
    this.stars = 0,
    this.oldStars = 0,
    this.coins = 0,
    this.firstWin = false,
    this.dailyRewarded = false,
    this.streak = 0,
    this.achievements = const [],
    this.missions = const [],
    this.allMissions = false,
    this.gift = const {},
    this.unlockedTheme,
  });

  final GameMode mode;
  final bool won;
  final int score;

  /// Best score of the mode before this game (0 if none).
  final int bestBefore;
  final int stars;
  final int oldStars;

  /// Coins added by this game (doubled later if the player watches an ad).
  final int coins;
  final bool firstWin;
  final bool dailyRewarded;
  final int streak;
  final List<AchievementDef> achievements;
  final List<MissionDef> missions;
  final bool allMissions;

  /// Power-ups given for finishing a world.
  final Map<PowerUp, int> gift;

  /// Board theme unlocked by reaching a new world.
  final String? unlockedTheme;

  bool get newBest => score > bestBefore && bestBefore > 0;
}

/// Owns [PlayerProgress]: coins, inventory, cosmetics, levels, daily,
/// missions, achievements and statistics. Saves a moment after changes.
class ProgressController extends ChangeNotifier {
  ProgressController({
    required DocStore store,
    required PlayerProgress initial,
    DateTime Function()? clock,
  }) : _store = store,
       _p = initial,
       _clock = clock ?? DateTime.now {
    observeToday();
  }

  final DocStore _store;
  final DateTime Function() _clock;
  PlayerProgress _p;
  Timer? _saveTimer;

  PlayerProgress get progress => _p;
  LifetimeStats get stats => _p.stats;
  int get coins => _p.coins;
  int get levelsCompleted => _p.levelsCompleted;
  int get totalStars => Stars.total(_p.levels);
  int get unlockedLevel => _p.unlockedLevel;
  int count(PowerUp p) => _p.count(p);

  String get today => DateKey.fromDateTime(_clock());
  bool get rewardsAllowed => !_p.daily.clockRolledBack(today);
  bool get dailyDoneToday => _p.daily.isCompleted(today);
  int get streak => _p.daily.currentStreak(today);

  void observeToday() => _p.daily.observeDate(today);

  /// The app came to the foreground (kept for the app shell; sessions are
  /// not counted separately in this game).
  void markActive() => observeToday();

  /// Today's missions (created when the date changes).
  MissionsState get missions {
    final t = today;
    final m = _p.missions;
    if (m == null || m.date != t) {
      final fresh = MissionsState(t, null, null);
      _p.missions = fresh;
      return fresh;
    }
    return m;
  }

  bool isLevelUnlocked(int n) => n >= 1 && n <= unlockedLevel;
  LevelRecord? record(int n) => _p.levels[n];

  // ------------------------------------------------------------ cosmetics

  /// Free, bought, or (board themes) reached in the campaign.
  bool owns(Cosmetic c) =>
      c.price == 0 ||
      _p.owned.contains(c.key) ||
      (c.world > 0 && unlockedLevel >= worlds[c.world - 1].first);

  String selected(CosmeticKind k) {
    final id = _p.selected[k.name];
    if (id != null) {
      final c = Cosmetics.byKey('${k.name}.$id');
      if (c != null && owns(c)) return id;
    }
    return Cosmetics.defaultId(k);
  }

  /// Buys [c] with coins. Returns false if it costs more than the balance.
  bool buy(Cosmetic c) {
    if (owns(c)) return true;
    if (_p.coins < c.price) return false;
    _p.coins -= c.price;
    _p.owned.add(c.key);
    _changed();
    return true;
  }

  void select(Cosmetic c) {
    if (!owns(c)) return;
    _p.selected[c.kind.name] = c.id;
    _changed();
  }

  // ------------------------------------------------------------ power-ups

  bool buyPowerUp(PowerUp p) {
    final price = PowerShop.price(p);
    if (_p.coins < price) return false;
    _p.coins -= price;
    _p.inventory[p] = count(p) + 1;
    _changed();
    return true;
  }

  void grantPowerUp(PowerUp p, [int n = 1]) {
    _p.inventory[p] = count(p) + n;
    _changed();
  }

  /// Uses one from the inventory. Returns false if there is none.
  bool consumePowerUp(PowerUp p) {
    if (count(p) <= 0) return false;
    _p.inventory[p] = count(p) - 1;
    _p.stats.powerUps++;
    missions.bump(MissionMetric.powerUp, 1);
    _changed();
    return true;
  }

  void addCoins(int n) {
    if (n <= 0) return;
    _p.coins += n;
    _p.stats.coinsEarned += n;
    _changed();
  }

  // ------------------------------------------------------------ in-game

  void recordPiece() {
    _p.stats.pieces++;
    missions.bump(MissionMetric.pieces, 1);
    _changed();
  }

  void recordHint() {
    _p.stats.hints++;
    _changed();
  }

  void recordUndo() {
    _p.stats.undos++;
    _changed();
  }

  /// Counts play time. Not saved on its own (that would write to storage
  /// every second): it goes out with the next real change or flush.
  void addPlaySeconds(int s) {
    if (s <= 0) return;
    _p.stats.playSeconds += s;
  }

  bool introSeen(String id) => _p.seenIntros.contains(id);

  void markIntroSeen(String id) {
    if (_p.seenIntros.add(id)) _changed();
  }

  // ------------------------------------------------------------ results

  /// Records a finished game and pays its rewards.
  GameReport recordGame({
    required GameSpec spec,
    required GameState state,
    int level = 0,
  }) {
    observeToday();
    final st = _p.stats;
    final mode = spec.mode;
    final won = state.status == Status.won;
    final bestBefore = st.best(mode);
    st.gamesByMode[mode.name] = (st.gamesByMode[mode.name] ?? 0) + 1;
    if (state.score > bestBefore) st.bestByMode[mode.name] = state.score;
    st.rows += state.rows;
    st.sand += state.sandCleared;
    st.multi += state.multi;
    st.perfect += state.perfect;
    st.golden += state.golden;
    if (state.bestCombo > st.bestCombo) st.bestCombo = state.bestCombo;
    if (state.bestWave > st.bestWave) st.bestWave = state.bestWave;

    var coins = Coins.forGame(rows: state.rows, golden: state.golden);
    var stars = 0;
    var oldStars = 0;
    var firstWin = false;
    var dailyRewarded = false;
    var gift = const <PowerUp, int>{};
    String? theme;
    if (mode == GameMode.campaign && won) {
      final def = LevelCatalog.level(spec.level);
      final old = _p.levels[spec.level];
      oldStars = old?.stars ?? 0;
      stars = def.starsFor(state.moves);
      firstWin = oldStars == 0;
      final worldBefore = worldOf(unlockedLevel).number;
      _p.levels[spec.level] = LevelRecord(
        stars: stars > oldStars ? stars : oldStars,
        bestMoves:
            old == null || old.bestMoves == 0 || state.moves < old.bestMoves
            ? state.moves
            : old.bestMoves,
        bestScore: old == null || state.score > old.bestScore
            ? state.score
            : old.bestScore,
      );
      coins += firstWin
          ? Coins.forLevelFirst(stars)
          : Coins.forBetterStars(oldStars, stars);
      final w = worldOf(spec.level);
      if (firstWin && spec.level == w.last) {
        gift = PowerShop.worldGift(w.number);
        for (final e in gift.entries) {
          _p.inventory[e.key] = count(e.key) + e.value;
        }
      }
      final worldAfter = worldOf(unlockedLevel).number;
      if (worldAfter > worldBefore) theme = worlds[worldAfter - 1].id;
      missions.bump(MissionMetric.level, 1);
    }
    if (mode == GameMode.moves && won) st.movesWins++;
    if (mode == GameMode.daily && won) {
      dailyRewarded = _p.daily.recordCompletion(
        spec.date,
        rewardsAllowed: rewardsAllowed,
      );
      if (dailyRewarded) coins += Coins.forDaily(_p.daily.streak);
    }
    final ms = missions;
    final done = <MissionDef>[
      ...ms.bump(MissionMetric.rows, state.rows),
      ...ms.bump(MissionMetric.multi, state.multi),
      ...ms.bump(MissionMetric.games, 1),
      ...ms.bump(
        MissionMetric.special,
        state.kinds.entries
            .where((e) => e.key != 0)
            .fold(0, (a, e) => a + e.value),
      ),
      ...ms.bump(MissionMetric.score, state.score, max: true),
    ];
    // Missions finished earlier in the game (pieces, power-ups) are paid
    // here too, once.
    final payable = [
      for (final m in ms.missions)
        if (ms.isDone(m) && !ms.claimed.contains(m.id)) m,
    ];
    for (final m in payable) {
      ms.claimed.add(m.id);
      coins += Coins.mission;
      if (!done.contains(m)) done.add(m);
    }
    var all = false;
    if (ms.missions.every(ms.isDone) &&
        !ms.claimed.contains(MissionsState.allId)) {
      ms.claimed.add(MissionsState.allId);
      coins += Coins.allMissions;
      all = true;
    }
    final unlocked = Achievements.newlyUnlocked(
      AchievementContext(
        stats: st,
        levelsCompleted: _p.levelsCompleted,
        stars: totalStars,
        bestDailyStreak: _p.daily.bestStreak,
        bestClassic: st.best(GameMode.classic),
        worldsDone: Stars.worldsDone(_p.levels),
      ),
      _p.achievements.keys.toSet(),
    );
    final now = _clock().millisecondsSinceEpoch;
    for (final a in unlocked) {
      _p.achievements[a.id] = now;
      coins += a.coins;
    }
    if (!rewardsAllowed) coins = 0;
    _p.coins += coins;
    st.coinsEarned += coins;
    _changed();
    return GameReport(
      mode: mode,
      won: won,
      score: state.score,
      bestBefore: bestBefore,
      stars: stars,
      oldStars: oldStars,
      coins: coins,
      firstWin: firstWin,
      dailyRewarded: dailyRewarded,
      streak: _p.daily.currentStreak(today),
      achievements: unlocked,
      missions: [
        for (final m in done)
          if (payable.contains(m)) m,
      ],
      allMissions: all,
      gift: gift,
      unlockedTheme: theme,
    );
  }

  // ------------------------------------------------------------ storage

  void _changed() {
    _scheduleSave();
    notifyListeners();
  }

  /// Deletes all progress (settings are kept). The latest date seen is
  /// kept so a reset cannot replay daily rewards after moving the clock.
  Future<void> resetAll() async {
    _saveTimer?.cancel();
    final latest = _p.daily.latestSeenDate;
    _p = PlayerProgress(daily: DailyRecord(latestSeenDate: latest));
    await _store.save(Docs.progress, _p);
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_store.save(Docs.progress, _p));
    });
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _store.save(Docs.progress, _p);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
