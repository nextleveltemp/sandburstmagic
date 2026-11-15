import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/core/sand.dart';

/// Rule tests. Expected values were computed with the Python reference
/// model (tool/reference_model/core.py).
void main() {
  const e = '..........';

  GameConfig cfg(List<String> layout, {int lockRows = 3, int limit = 0}) =>
      GameConfig(seed: 1, layout: layout, lockRows: lockRows, moveLimit: limit);

  GameState game(GameConfig c, List<Piece?> tray) =>
      newGame(c)..tray = List<Piece?>.of(tray);

  List<String> rows(GameState s, int from) => layoutText(s.board).sublist(from);

  group('placement', () {
    test('a placed block becomes sand and falls to the floor', () {
      final c = cfg(List.filled(10, e));
      final s = game(c, const [Piece(0, 3), null, null]);
      final t = place(s, c, 0, 0, 0)!;
      expect(t.placed, hasLength(1));
      expect(s.board.cells[90]?.colour, 3);
      expect(s.board.cells[0], isNull);
      expect(s.score, 1);
      expect(s.moves, 1);
    });

    test('invalid placements are rejected and change nothing', () {
      final c = cfg([...List.filled(9, e), '0.........']);
      final s = game(c, const [Piece(1, 3), Piece(0, 3), null]);
      final before = s.board.encode();
      expect(place(s, c, 0, 9, 0), isNull, reason: 'overlaps sand');
      expect(place(s, c, 0, 0, 9), isNull, reason: 'outside the board');
      expect(place(s, c, 2, 0, 0), isNull, reason: 'empty slot');
      expect(s.board.encode(), before);
      expect(s.moves, 0);
    });

    test('pieces cannot be placed on restricted cells', () {
      final c = cfg(['x.........', ...List.filled(9, e)]);
      final s = game(c, const [Piece(0, 3), null, null]);
      expect(place(s, c, 0, 0, 0), isNull);
      expect(place(s, c, 0, 0, 1), isNotNull);
    });

    test('a new set is dealt only after all three pieces are used', () {
      final c = cfg(List.filled(10, e));
      final s = game(c, const [Piece(0, 1), Piece(0, 2), Piece(0, 3)]);
      place(s, c, 0, 0, 0);
      expect(s.tray.whereType<Piece>(), hasLength(2));
      place(s, c, 1, 0, 2);
      final t = place(s, c, 2, 0, 4)!;
      expect(t.dealt, isTrue);
      expect(s.tray.whereType<Piece>(), hasLength(3));
    });
  });

  group('sand', () {
    test('grains fall, then slide diagonally', () {
      final b = boardFromLayout([
        ...List.filled(8, e),
        '1.........',
        '2.........',
      ]);
      settle(b);
      expect(layoutText(b).sublist(8), [e, '21........']);
    });

    test('heavy sand never slides', () {
      final b = boardFromLayout([
        ...List.filled(8, e),
        'h.........',
        '2.........',
      ]);
      expect(settle(b), isEmpty);
    });

    test('frozen sand does not move', () {
      final b = boardFromLayout([
        ...List.filled(5, e),
        'f.........',
        e,
        e,
        e,
        e,
      ]);
      expect(settle(b), isEmpty);
      expect(layoutText(b)[5], 'f.........');
    });

    test('sticky sand holds its neighbours', () {
      final b = boardFromLayout([
        ...List.filled(7, e),
        '1.........',
        'k.........',
        '2.........',
      ]);
      expect(settle(b), isEmpty);
    });

    test('a sand trap swallows three grains, then fills', () {
      final b = boardFromLayout([...List.filled(9, e), 'T.........']);
      for (final i in [0, 10, 20, 30]) {
        b.cells[i] = Cell(b.newId(), 1);
      }
      final steps = settle(b);
      expect(steps.fold(0, (n, s) => n + s.fills.length), 1);
      expect(b.cells[90]?.colour, greyColour);
      expect(b.cells[91], isNotNull);
    });

    test('sand never leaves the board and is never lost', () {
      final b = makeLayout(99, 7, density: 90);
      final count = b.sandCount();
      settle(b);
      expect(b.sandCount(), count);
    });
  });

  group('rows', () {
    test('row detection needs every cell, and an open trap blocks it', () {
      final b = boardFromLayout([...List.filled(9, e), '0123456789']);
      expect(fullRows(b), [9]);
      final t = boardFromLayout([...List.filled(9, e), '012345678T']);
      expect(fullRows(t), isEmpty);
      final g = boardFromLayout([...List.filled(9, e), '01234567.9']);
      expect(fullRows(g), isEmpty);
    });

    test('a single row clears and scores', () {
      final c = cfg([...List.filled(9, e), '012345678.']);
      final s = game(c, const [Piece(0, 3), null, null]);
      final t = place(s, c, 0, 0, 9)!;
      expect(t.rows, 1);
      // 1 placement + 100 row + 10 x 10 grains + 1000 perfect clear.
      expect(t.points, 1201);
      expect(s.perfect, 1);
      expect(s.combo, 1);
    });

    test('two rows at once clear together for more points', () {
      final c = cfg([...List.filled(8, e), '012345678.', '012345678.']);
      final s = game(c, const [Piece(2, 3), null, null]);
      final t = place(s, c, 0, 0, 9)!;
      expect(t.rows, 2);
      expect(t.points, 1452);
      expect(s.multi, 1);
      expect(s.bestWave, 2);
    });

    test('remaining sand settles after a clear; combo resets on a miss', () {
      final c = cfg([...List.filled(8, e), '1.........', '012345678.']);
      final s = game(c, const [Piece(0, 3), Piece(0, 4), null]);
      final t = place(s, c, 0, 0, 9)!;
      expect(t.points, 201);
      expect(rows(s, 9), ['1.........']);
      expect(s.combo, 1);
      final t2 = place(s, c, 1, 0, 5)!;
      expect(t2.points, 1);
      expect(s.combo, 0);
    });

    test('an incomplete row never clears', () {
      final c = cfg([...List.filled(9, e), '01234567..']);
      final s = game(c, const [Piece(0, 3), null, null]);
      final t = place(s, c, 0, 0, 0)!;
      expect(t.rows, 0);
      expect(s.rows, 0);
    });

    test('combo bonus grows with consecutive clears', () {
      expect(wavePoints(Wave([9]), 0, 0), 100);
      expect(wavePoints(Wave([9]), 2, 0), 150);
      expect(wavePoints(Wave([8, 9]), 0, 0), 250);
      expect(wavePoints(Wave([7, 8, 9]), 0, 0), 450);
      expect(wavePoints(Wave([6, 7, 8, 9]), 0, 0), 700);
      // A chain wave (second wave of one turn) scores more.
      expect(wavePoints(Wave([9]), 0, 1), 150);
    });
  });

  group('special sand and obstacles', () {
    test('explosive sand clears its neighbours', () {
      final c = cfg([...List.filled(7, e), e, '.12.......', '0e23456.89']);
      final s = game(c, const [Piece(0, 3), null, null]);
      final t = place(s, c, 0, 0, 7)!;
      expect(t.points, 1221);
      expect(s.sandCleared, 12);
      expect(s.kinds[SandKind.explosive], 1);
    });

    test('stone takes two bursts', () {
      final c = cfg([...List.filled(9, e), '0123S567.9']);
      final s = game(c, const [Piece(0, 3), null, null]);
      place(s, c, 0, 0, 8);
      expect(s.board.cells[94]?.obstacle, Obstacle.stone);
      expect(s.board.cells[94]?.hp, 1);
      expect(s.obstacles, 0);
    });

    test('ice breaks next to a burst row', () {
      final c = cfg([...List.filled(8, e), '..I.......', '01234567.9']);
      final s = game(c, const [Piece(0, 3), null, null]);
      place(s, c, 0, 0, 8);
      expect(s.obstacles, 1);
      expect(s.board.sandCount(), 0);
    });

    test('a lock counts down cleared rows', () {
      final c = cfg([
        ...List.filled(8, e),
        'L.........',
        '01234567.9',
      ], lockRows: 2);
      final s = game(c, const [Piece(0, 3), null, null]);
      place(s, c, 0, 0, 8);
      expect(s.board.cells[80]?.obstacle, Obstacle.locked);
      expect(s.board.cells[80]?.hp, 1);
    });
  });

  group('game end', () {
    test('no room for any piece ends the game', () {
      final b = Board();
      for (var r = 0; r < boardH; r++) {
        for (var c = 0; c < boardW; c++) {
          if (c != (r * 3) % boardW) {
            b.cells[r * boardW + c] = Cell(b.newId(), 1);
          }
        }
      }
      final s = GameState(b)
        ..tray = const [Piece(1, 2), Piece(7, 3), Piece(3, 4)];
      updateStatus(s, GameConfig(seed: 1));
      expect(s.status, Status.lost);
      expect(s.reason, 'space');
      s
        ..status = Status.playing
        ..reason = ''
        ..tray = const [Piece(0, 2), null, null];
      updateStatus(s, GameConfig(seed: 1));
      expect(s.isPlaying, isTrue, reason: 'a single block still fits');
    });

    test('a move limit ends the game', () {
      final c = cfg(List.filled(10, e), limit: 1);
      final s = game(c, const [Piece(0, 3), Piece(0, 3), null]);
      place(s, c, 0, 0, 0);
      expect(s.status, Status.lost);
      expect(s.reason, 'moves');
      expect(place(s, c, 1, 0, 0), isNull);
    });

    test('meeting the objectives wins', () {
      final c = GameConfig(
        seed: 1,
        layout: [...List.filled(9, e), '012345678.'],
        objectives: const [Objective(ObjectiveType.rows, 1)],
      );
      final s = game(c, const [Piece(0, 3), null, null]);
      place(s, c, 0, 0, 9);
      expect(s.status, Status.won);
    });

    test('the Time Challenge clock ends a game', () {
      final s = newGame(GameConfig(seed: 3));
      endForTime(s);
      expect(s.reason, 'time');
      expect(s.isPlaying, isFalse);
    });

    test('keep playing clears the bottom three rows', () {
      final c = cfg([
        ...List.filled(6, e),
        '0.........',
        '01........',
        '012.......',
        '0123......',
      ]);
      final s = newGame(c)
        ..status = Status.lost
        ..reason = 'space';
      expect(continueGame(s, c), isNotNull);
      expect(s.isPlaying, isTrue);
      expect(rows(s, 9), ['0.........']);
      expect(s.score, 0);
      expect(continueGame(s, c), isNull, reason: 'only after a loss');
    });
  });

  group('power-ups', () {
    final c = cfg([
      ...List.filled(7, e),
      '0.........',
      '01........',
      '0123......',
    ]);

    test('Sand Sweep, Colour Blast, Bomb, Crusher and Gravity', () {
      var s = newGame(c);
      expect(power(s, c, PowerUp.sweep, 9)!.points, 40);
      expect(rows(s, 8), ['0.........', '01........']);
      s = newGame(c);
      expect(power(s, c, PowerUp.blast, 0)!.points, 30);
      expect(rows(s, 9), ['1123......']);
      s = newGame(c);
      expect(power(s, c, PowerUp.bomb, 81)!.points, 60);
      expect(rows(s, 9), ['...3......']);
      s = newGame(c);
      expect(power(s, c, PowerUp.crusher, 90)!.points, 30);
      s = newGame(c);
      expect(power(s, c, PowerUp.gravity, 1), isNotNull);
      expect(rows(s, 7), ['.........0', '........01', '......0123']);
    });

    test('Row Clear fills a nearly full row so it bursts', () {
      final rc = cfg([...List.filled(9, e), '0123456...']);
      final s = newGame(rc);
      final t = power(s, rc, PowerUp.rowClear, 9)!;
      expect(t.rows, 1);
      expect(t.points, 1200);
      expect(power(newGame(c), c, PowerUp.rowClear, 0), isNull);
    });

    test('Extra Move gives a bonus block and one more move', () {
      final lim = cfg(List.filled(10, e), limit: 5);
      final s = newGame(lim);
      power(s, lim, PowerUp.extra, null);
      expect(s.bonus, isNotNull);
      expect(s.bonusMoves, 1);
      expect(place(s, lim, 3, 0, 0), isNotNull);
      expect(s.bonus, isNull);
    });

    test('a power-up with nothing to do changes nothing', () {
      final s = newGame(c);
      final before = s.board.encode();
      expect(power(s, c, PowerUp.sweep, 0), isNull);
      expect(power(s, c, PowerUp.blast, 9), isNull);
      expect(power(s, c, PowerUp.bomb, 0), isNull);
      expect(power(s, c, PowerUp.crusher, 0), isNull);
      expect(s.board.encode(), before);
    });
  });

  group('dealing', () {
    test('a set always contains a piece that fits when one could', () {
      final b = Board();
      for (var i = 0; i < boardN; i++) {
        if (i != 0) b.cells[i] = Cell(b.newId(), 1);
      }
      for (var seed = 0; seed < 30; seed++) {
        final s = GameState(b.copy())..rng = seed;
        deal(s, GameConfig(seed: seed));
        expect(anyFits(s), isTrue, reason: 'seed $seed');
      }
    });

    test('the same seed deals the same pieces', () {
      final a = newGame(GameConfig(seed: 42));
      final b = newGame(GameConfig(seed: 42));
      expect(
        [for (final p in a.tray) p!.code],
        [for (final p in b.tray) p!.code],
      );
    });
  });

  test('game state survives a save and restore', () {
    final c = cfg([...List.filled(8, e), 'L.f.k.S.T.', '0123456.e9']);
    final s = newGame(c);
    final m = bestMove(s, c)!;
    place(s, c, m.$1, m.$2, m.$3);
    final back = GameState.fromJson(s.toJson());
    expect(back.board.encode(), s.board.encode());
    expect(back.score, s.score);
    expect(back.rng, s.rng);
    expect(
      [for (final p in back.tray) p?.code],
      [for (final p in s.tray) p?.code],
    );
    final c2 = GameConfig.fromJson(c.toJson());
    expect(c2.layout, c.layout);
    expect(c2.seed, c.seed);
  });
}
