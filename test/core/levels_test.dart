import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/core/sand.dart';

/// Every campaign level is validated: well formed, fair at the start, and
/// proven winnable by replaying the stored solution with the Dart engine.
void main() {
  test('100 levels in six worlds, in order', () {
    expect(LevelCatalog.count, 100);
    var expected = 1;
    for (final w in worlds) {
      expect(w.first, expected);
      expected = w.last + 1;
      for (var n = w.first; n <= w.last; n++) {
        expect(LevelCatalog.level(n).world, w.number, reason: 'level $n');
      }
    }
    expect(expected, 101);
  });

  test('every starting board is settled and has no complete row', () {
    for (final def in LevelCatalog.all) {
      final layout = def.layout;
      if (layout == null) continue;
      final b = boardFromLayout(layout, lockRows: def.lockRows);
      expect(fullRows(b), isEmpty, reason: 'level ${def.number}');
      expect(settle(b), isEmpty, reason: 'level ${def.number} not settled');
    }
  });

  test('every level has goals, sane stars and a fair first deal', () {
    for (final def in LevelCatalog.all) {
      final n = def.number;
      expect(def.objectives, isNotEmpty, reason: 'level $n');
      expect(def.threeStars <= def.twoStars, isTrue, reason: 'level $n');
      if (def.moveLimit > 0) {
        expect(def.twoStars <= def.moveLimit, isTrue, reason: 'level $n');
      }
      final s = newGame(def.config());
      expect(s.isPlaying, isTrue, reason: 'level $n');
      expect(anyFits(s), isTrue, reason: 'level $n');
    }
  });

  test('every level is winnable: its stored solution wins', () {
    for (final def in LevelCatalog.all) {
      final cfg = def.config();
      final s = newGame(cfg);
      for (final (slot, r, c) in def.solution) {
        expect(
          place(s, cfg, slot, r, c),
          isNotNull,
          reason: 'level ${def.number}: illegal move',
        );
      }
      expect(s.status, Status.won, reason: 'level ${def.number}');
      expect(s.moves, def.par, reason: 'level ${def.number}');
      if (def.moveLimit > 0) {
        expect(s.moves <= def.moveLimit, isTrue);
      }
    }
  });

  test('mechanics are introduced gradually', () {
    final intros = [
      for (final d in LevelCatalog.all)
        if (d.intro.isNotEmpty) d.intro,
    ];
    expect(intros.toSet().length, intros.length, reason: 'no repeats');
    expect(intros.first, 'place');
    // No special sand in world 1.
    for (var n = 1; n <= 17; n++) {
      expect(LevelCatalog.level(n).specials, isEmpty);
    }
  });

  test('daily puzzles are the same for a date and the bot can win them', () {
    for (final date in ['2026-11-15', '2026-12-25', '2027-02-28']) {
      final a = DailyPuzzle.generate(date);
      final b = DailyPuzzle.generate(date);
      expect(a.config.layout, b.config.layout);
      expect(
        a.config.objectives.first.toString(),
        b.config.objectives.first.toString(),
      );
      final (s, _) = playBot(a.config, maxMoves: DailyPuzzle.moves);
      expect(s.status, Status.won, reason: date);
    }
    expect(
      DailyPuzzle.generate('2026-11-15').config.seed,
      isNot(DailyPuzzle.generate('2026-11-16').config.seed),
    );
  });
}
