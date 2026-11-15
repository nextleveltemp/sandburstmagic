import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/core/progression.dart';
import 'package:sand_burst_magic/data/doc_store.dart';
import 'package:sand_burst_magic/data/docs.dart';
import 'package:sand_burst_magic/data/kv_store.dart';
import 'package:sand_burst_magic/data/models.dart';

void main() {
  test('progress round-trips through JSON', () {
    final p = PlayerProgress()
      ..coins = 777
      ..inventory[PowerUp.blast] = 4
      ..owned.add('palette.neon')
      ..selected['palette'] = 'neon'
      ..levels[3] = const LevelRecord(stars: 2, bestMoves: 9, bestScore: 900)
      ..achievements['firstRow'] = 5
      ..seenIntros.add('place');
    p.stats
      ..rows = 40
      ..gamesByMode['classic'] = 3
      ..bestByMode['classic'] = 4200;
    final back = PlayerProgress.fromJson(
      jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>,
    );
    expect(back.coins, 777);
    expect(back.count(PowerUp.blast), 4);
    expect(back.owned, contains('palette.neon'));
    expect(back.selected['palette'], 'neon');
    expect(back.levels[3]?.stars, 2);
    expect(back.stats.best(GameMode.classic), 4200);
    expect(back.achievements.keys, contains('firstRow'));
    expect(back.seenIntros, contains('place'));
  });

  test('bad progress data falls back to safe defaults', () {
    final p = PlayerProgress.fromJson({
      'coins': -5,
      'inventory': {'nope': 3, 'sweep': -1},
      'levels': {'0': {}, '999': {}, 'x': 1},
      'achievements': {'unknown': 1},
    });
    expect(p.coins, Coins.starting);
    expect(p.levels, isEmpty);
    expect(p.achievements, isEmpty);
  });

  test('a saved game restores to the same position', () async {
    final store = DocStore(MemoryKvStore());
    final def = LevelCatalog.level(40);
    final cfg = def.config();
    final s = newGame(cfg);
    for (final (slot, r, c) in def.solution.take(3)) {
      place(s, cfg, slot, r, c);
    }
    final saved = SavedGame(
      spec: const GameSpec(GameMode.campaign, level: 40),
      config: cfg,
      state: s,
      savedAtMillis: 1,
      hintsUsed: 1,
    );
    await store.save(Docs.game(GameMode.campaign)!, saved);
    final back = store.load(Docs.game(GameMode.campaign)!).value!;
    expect(back.spec.level, 40);
    expect(back.state.board.encode(), s.board.encode());
    expect(back.hintsUsed, 1);
    // Playing on from the restored game gives the same result.
    final rest = def.solution.skip(3);
    for (final (slot, r, c) in rest) {
      expect(place(back.state, back.config, slot, r, c), isNotNull);
    }
    expect(back.state.status, Status.won);
  });

  test('settings tolerate unknown and broken values', () {
    final s = AppSettings.fromJson({'sfx': 'yes', 'volume': 7, 'theme': 'x'});
    expect(s.sfx, isTrue);
    expect(s.volume, 1.0);
  });
}
