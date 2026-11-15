import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/core/rng.dart';
import 'package:sand_burst_magic/core/sand.dart';

import '../helpers.dart';

/// The Dart engine must reproduce the Python reference model exactly
/// (tool/reference_model, exported by gen_vectors.py).
void main() {
  final v = loadVectors();

  GameConfig configFrom(Map<String, Object?> c) {
    final layout = c['layout'];
    final schedule = c['schedule'];
    return GameConfig(
      seed: c['seed'] as int,
      layout: layout == null
          ? null
          : [for (final r in layout as List) r as String],
      lockRows: c['lockRows'] as int,
      objectives: [
        for (final o in c['objectives'] as List)
          Objective(
            ObjectiveType.values.byName((o as List)[0] as String),
            o[1] as int,
            o[2] as int,
          ),
      ],
      moveLimit: c['moveLimit'] as int,
      weights: c['weights'] == 'gentle' ? gentleWeights : defaultWeights,
      palette: [for (final p in c['palette'] as List) p as int],
      specials: {
        for (final e in (c['specials'] as Map).entries)
          int.parse(e.key as String): e.value as int,
      },
      schedule: schedule == null
          ? Schedule.none
          : Schedule.values.byName(schedule as String),
    );
  }

  void expectState(GameState s, Map<String, Object?> want, String where) {
    expect(s.board.encode(), want['board'], reason: '$where board');
    expect(
      [for (final p in s.tray) p?.code],
      want['tray'],
      reason: '$where tray',
    );
    expect(s.bonus?.code, want['bonus'], reason: '$where bonus');
    expect(s.rng, want['rng'], reason: '$where rng');
    expect(s.score, want['score'], reason: '$where score');
    expect(s.combo, want['combo'], reason: '$where combo');
    expect(s.bestCombo, want['bestCombo'], reason: '$where bestCombo');
    expect(s.rows, want['rows'], reason: '$where rows');
    expect(s.multi, want['multi'], reason: '$where multi');
    expect(s.bestWave, want['bestWave'], reason: '$where bestWave');
    expect(s.moves, want['moves'], reason: '$where moves');
    expect(s.sets, want['sets'], reason: '$where sets');
    expect(s.sandCleared, want['sand'], reason: '$where sand');
    expect(s.obstacles, want['obstacles'], reason: '$where obstacles');
    expect(s.golden, want['golden'], reason: '$where golden');
    expect(s.perfect, want['perfect'], reason: '$where perfect');
    final kinds = {
      for (final e in (want['kinds'] as Map).entries)
        int.parse(e.key as String): e.value as int,
    };
    expect(s.kinds, kinds, reason: '$where kinds');
    expect(s.status.name, want['status'], reason: '$where status');
    expect(s.reason, want['reason'], reason: '$where reason');
  }

  test('random numbers and string hash match', () {
    final r = v['rng'] as Map<String, Object?>;
    final rng = SeededRng(r['seed'] as int);
    expect([for (var i = 0; i < 8; i++) rng.nextU32()], r['u32']);
    final r7 = SeededRng(7);
    expect([for (var i = 0; i < 20; i++) r7.nextInt(10)], r['int10']);
    final h = v['hash'] as Map<String, Object?>;
    for (final e in h.entries) {
      expect(SeededRng.hashString(e.key), e.value, reason: e.key);
    }
  });

  test('generated layouts match', () {
    for (final l in v['layouts'] as List) {
      final m = l as Map<String, Object?>;
      final pal = m['palette'];
      final b = makeLayout(
        m['seed'] as int,
        m['fill'] as int,
        density: m['density'] as int,
        palette: pal == null ? null : [for (final p in pal as List) p as int],
        obstacles: [
          for (final o in m['obstacles'] as List)
            ((o as List)[0] as int, o[1] as int, o[2] as int, o[3] as int),
        ],
        specials: [
          for (final s in m['specials'] as List)
            ((s as List)[0] as int, s[1] as int),
        ],
        blocked: [for (final i in m['blocked'] as List) i as int],
        lockRows: m['lockRows'] as int,
      );
      expect(b.encode(), m['encoded'], reason: 'layout ${m['seed']}');
      expect(layoutText(b), m['rows'], reason: 'layout ${m['seed']}');
    }
  });

  for (final g in v['games'] as List) {
    final game = g as Map<String, Object?>;
    test('bot game "${game['name']}" matches turn by turn', () {
      final cfg = configFrom(game['config'] as Map<String, Object?>);
      final s = newGame(cfg);
      expectState(s, game['start'] as Map<String, Object?>, 'start');
      var n = 0;
      for (final t in game['turns'] as List) {
        final turn = t as Map<String, Object?>;
        final move = [for (final x in turn['move'] as List) x as int];
        // The Dart bot chooses the same move as the Python bot.
        final mine = bestMove(s, cfg);
        expect([mine!.$1, mine.$2, mine.$3], move, reason: 'turn $n move');
        final result = place(s, cfg, move[0], move[1], move[2]);
        expect(result, isNotNull, reason: 'turn $n legal');
        expect(result!.points, turn['points'], reason: 'turn $n points');
        expect(result.rows, turn['rows'], reason: 'turn $n rows');
        expect(
          [
            for (final p in result.phases)
              switch (p) {
                SettlePhase() => 'settle',
                WavePhase() => 'wave',
                StickyPhase() => 'sticky',
                MoversPhase() => 'movers',
                BlastPhase() => 'blast',
                ShufflePhase() => 'shuffle',
                FillPhase() => 'fill',
              },
          ],
          turn['phases'],
          reason: 'turn $n phases',
        );
        expect(result.revealed, turn['revealed'], reason: 'turn $n reveal');
        expectState(s, turn['state'] as Map<String, Object?>, 'turn $n');
        n++;
      }
    });
  }

  test('power-ups match', () {
    final p = v['powers'] as Map<String, Object?>;
    final cfg = configFrom(p['config'] as Map<String, Object?>);
    final s0 = newGame(cfg);
    for (var i = 0; i < (p['moves'] as int); i++) {
      final m = bestMove(s0, cfg)!;
      place(s0, cfg, m.$1, m.$2, m.$3);
    }
    expectState(s0, p['before'] as Map<String, Object?>, 'before');
    const names = {
      'sweep': PowerUp.sweep,
      'blast': PowerUp.blast,
      'shaker': PowerUp.shaker,
      'rowclear': PowerUp.rowClear,
      'crusher': PowerUp.crusher,
      'gravity': PowerUp.gravity,
      'bomb': PowerUp.bomb,
      'extra': PowerUp.extra,
    };
    for (final r in p['results'] as List) {
      final res = r as Map<String, Object?>;
      final s = s0.copy();
      final kind = names[res['kind']]!;
      final t = power(s, cfg, kind, res['arg'] as int?);
      final where = '${res['kind']}(${res['arg']})';
      expect(t != null, res['ok'], reason: where);
      if (t != null) expect(t.points, res['points'], reason: where);
      expectState(s, res['state'] as Map<String, Object?>, where);
    }
  });
}
