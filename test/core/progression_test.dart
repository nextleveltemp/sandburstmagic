import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/core/progression.dart';

void main() {
  test('coin rules', () {
    expect(Coins.forGame(rows: 12, golden: 2), 22);
    expect(Coins.forLevelFirst(3), 50);
    expect(Coins.forBetterStars(1, 3), 20);
    expect(Coins.forBetterStars(3, 1), 0);
    expect(Coins.forDaily(1), 60);
    expect(Coins.forDaily(30), 120);
  });

  test('every power-up has a price; cosmetics have unique keys', () {
    for (final p in PowerUp.values) {
      expect(PowerShop.price(p), greaterThan(0));
    }
    final keys = Cosmetics.all.map((c) => c.key).toSet();
    expect(keys.length, Cosmetics.all.length);
    for (final k in CosmeticKind.values) {
      expect(Cosmetics.ofKind(k).first.price, 0, reason: 'a free default');
    }
  });

  test('missions: three a day, deterministic, different metrics', () {
    final a = Missions.forDate('2026-11-15');
    expect(a, hasLength(3));
    expect(a.map((m) => m.metric).toSet(), hasLength(3));
    expect(Missions.forDate('2026-11-15').map((m) => m.id), a.map((m) => m.id));
    final st = MissionsState('2026-11-15', null, null);
    for (final m in st.missions) {
      st.bump(m.metric, m.target, max: m.metric == MissionMetric.score);
    }
    expect(st.missions.every(st.isDone), isTrue);
    final restored = MissionsState.fromJson(st.toJson())!;
    expect(restored.missions.every(restored.isDone), isTrue);
  });

  test('daily streak and clock protection', () {
    final d = DailyRecord();
    expect(d.recordCompletion('2026-11-14', rewardsAllowed: true), isTrue);
    expect(d.recordCompletion('2026-11-15', rewardsAllowed: true), isTrue);
    expect(d.streak, 2);
    expect(d.recordCompletion('2026-11-15', rewardsAllowed: true), isFalse);
    expect(d.currentStreak('2026-11-16'), 2);
    expect(d.currentStreak('2026-11-18'), 0);
    d.observeDate('2026-11-20');
    expect(d.clockRolledBack('2026-11-19'), isTrue);
  });

  test('achievements unlock from statistics', () {
    final ctx = AchievementContext(
      stats: LifetimeStats(rows: 150, bestWave: 3, bestCombo: 5),
      levelsCompleted: 17,
      stars: 40,
      bestDailyStreak: 3,
      bestClassic: 6000,
      worldsDone: 1,
    );
    final ids = Achievements.newlyUnlocked(ctx, {}).map((a) => a.id).toSet();
    expect(
      ids,
      containsAll([
        'firstRow', 'rows100', 'double', 'triple', 'combo5', 'score5000', //
        'level10', 'world1', 'streak3',
      ]),
    );
    expect(ids.contains('quad'), isFalse);
    expect(Achievements.newlyUnlocked(ctx, ids), isEmpty);
  });

  test('stars per level', () {
    final def = LevelCatalog.level(10);
    expect(def.starsFor(def.par), 3);
    expect(def.starsFor(def.twoStars), def.twoStars <= def.threeStars ? 3 : 2);
    expect(def.starsFor(def.twoStars + 1), 1);
  });
}
