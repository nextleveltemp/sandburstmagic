import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/core/progression.dart';
import 'package:sand_burst_magic/data/models.dart';
import 'package:sand_burst_magic/state/game_controller.dart';
import 'package:sand_burst_magic/state/launcher.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('winning level 1 pays coins, records stars and unlocks level 2', () async {
    final s = await testServices();
    final c = Launcher.level(s, 1)!;
    final def = LevelCatalog.level(1);
    final coins = s.progress.coins;
    for (final (slot, r, col) in def.solution) {
      expect(c.placePiece(slot, r, col), isTrue);
    }
    expect(c.finished, isTrue);
    expect(c.report!.won, isTrue);
    expect(c.report!.stars, 3);
    expect(s.progress.coins, greaterThan(coins));
    expect(s.progress.isLevelUnlocked(2), isTrue);
    expect(Launcher.level(s, 3), isNull, reason: 'level 3 still locked');
    expect(s.saves.has(GameMode.campaign), isFalse);
  });

  test('moves are saved and resumed', () async {
    final s = await testServices();
    final c = Launcher.mode(s, GameMode.classic);
    final m = bestMove(c.state, c.config)!;
    c.placePiece(m.$1, m.$2, m.$3);
    await Future<void>.delayed(Duration.zero);
    final saved = s.saves.get(GameMode.classic)!;
    expect(saved.state.board.encode(), c.state.board.encode());
    final again = Launcher.mode(s, GameMode.classic);
    expect(again.state.score, c.state.score);
    expect(Launcher.mode(s, GameMode.classic, fresh: true).state.moves, 0);
  });

  test('one free undo and one free hint, then rewarded ads', () async {
    final ads = FakeAdService();
    final s = await testServices(ads: ads);
    final c = Launcher.mode(s, GameMode.classic);
    expect(c.canUndo, isFalse);
    expect(await c.showHint(), isTrue);
    expect(c.hint, isNotNull);
    expect(c.hintIsFree, isFalse);
    expect(await c.showHint(), isFalse, reason: 'needs an ad now');
    expect(await c.showHint(paid: true), isTrue);
    final m = c.hint!;
    final before = c.state.board.encode();
    c.placePiece(m.$1, m.$2, m.$3);
    expect(c.undo(), isTrue);
    expect(c.state.board.encode(), before);
    final m2 = bestMove(c.state, c.config)!;
    c.placePiece(m2.$1, m2.$2, m2.$3);
    expect(c.undo(), isFalse, reason: 'free undo used');
    expect(c.undo(paid: true), isTrue);
  });

  test('power-ups come from the inventory', () async {
    final s = await testServices();
    final c = Launcher.mode(s, GameMode.classic);
    expect(s.progress.count(PowerUp.extra), 1);
    expect(c.usePowerUp(PowerUp.extra, null), isTrue);
    expect(s.progress.count(PowerUp.extra), 0);
    expect(c.state.bonus, isNotNull);
    expect(c.usePowerUp(PowerUp.blast, 0), isFalse, reason: 'none left');
    expect(s.progress.buyPowerUp(PowerUp.shaker), isTrue);
    expect(s.progress.count(PowerUp.shaker), 1);
  });

  test('Time Challenge ends when the clock runs out', () async {
    final s = await testServices();
    final c = Launcher.mode(s, GameMode.time);
    expect(c.timeLeftMs, Modes.timeSeconds * 1000);
    c.tick(Modes.timeSeconds * 1000 + 10);
    expect(c.finished, isTrue);
    expect(c.state.reason, 'time');
    expect(s.progress.stats.gamesByMode['time'], 1);
  });

  test('keep playing is offered once after running out of room', () async {
    final ads = FakeAdService();
    final s = await testServices(ads: ads);
    final c = Launcher.mode(s, GameMode.classic);
    c.state
      ..status = Status.lost
      ..reason = 'space';
    expect(c.offerContinue, isTrue);
    expect(c.keepPlaying(), isTrue);
    expect(c.state.isPlaying, isTrue);
    endForTime(c.state);
    c.state.reason = 'space';
    expect(c.offerContinue, isFalse, reason: 'only once');
  });

  test('double reward adds the game coins once', () async {
    final s = await testServices();
    final c = Launcher.level(s, 1)!;
    for (final (slot, r, col) in LevelCatalog.level(1).solution) {
      c.placePiece(slot, r, col);
    }
    final coins = s.progress.coins;
    expect(c.doubleReward(), isTrue);
    expect(s.progress.coins, coins + c.report!.coins);
    expect(c.doubleReward(), isFalse);
  });

  test('cosmetics: buy, select, and world themes unlock by playing', () async {
    final s = await testServices();
    final p = s.progress;
    final neon = Cosmetics.byKey('palette.neon')!;
    p.addCoins(1000);
    expect(p.buy(neon), isTrue);
    p.select(neon);
    expect(p.selected(CosmeticKind.palette), 'neon');
    expect(p.owns(Cosmetics.byKey('board.candy')!), isTrue);
    expect(p.owns(Cosmetics.byKey('board.cosmic')!), isFalse);
  });

  test('daily puzzle win records the streak', () async {
    final s = await testServices();
    final c = await Launcher.daily(s);
    expect(c.spec.date, s.progress.today);
    final (bot, moves) = playBot(c.config, maxMoves: DailyPuzzle.moves);
    expect(bot.status, Status.won);
    for (final (slot, r, col) in moves) {
      c.placePiece(slot, r, col);
    }
    expect(c.report!.dailyRewarded, isTrue);
    expect(s.progress.dailyDoneToday, isTrue);
    expect(s.progress.streak, 1);
    expect(c.spec, isA<GameSpec>());
  });
}
