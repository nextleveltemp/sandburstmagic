// Full on-device check of Sand Burst Magic with REAL storage, REAL audio and
// REAL Google test ads. Run on an emulator or phone:
//
//   flutter test integration_test/device_check_test.dart
//
// CI runs it next to .github/scripts/device_watch.sh (screenshots on
// "SBMSHOT <name>", closes full-screen ads between "SBMAD begin/end").

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/data/models.dart';
import 'package:sand_burst_magic/services/audio_service.dart';
import 'package:sand_burst_magic/ui/screens/game_screen.dart';

import 'device_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home, music, every menu screen, no overflow', (t) async {
    final s = await freshServices();
    await startApp(t, s);
    step('audio loads; menu music plays');
    final audio = audioOf(s);
    expect(await waitFor(t, () => audio.isReady || audio.isDisabled), isTrue);
    expect(audio.isDisabled, isFalse, reason: 'audio failed to initialise');
    expect(
      await waitFor(
        t,
        () =>
            audio.loadedTrack == MusicTrack.main &&
            audio.musicState == PlayerState.playing,
      ),
      isTrue,
    );
    await shot(t, 'home');
    expect(find.byType(AdWidget), findsNothing, reason: 'no banner on home');

    for (final key in [
      'home-campaign',
      'home-modes',
      'home-shop',
      'home-themes',
      'home-stats',
      'home-settings',
    ]) {
      step('open $key');
      await tapKey(t, key);
      await shot(t, key);
      // Scroll to the end of long screens: nothing may overflow.
      final scroll = find.byType(Scrollable);
      if (scroll.evaluate().isNotEmpty) {
        await t.drag(scroll.first, const Offset(0, -3000));
        await wait(t, 800);
        await shot(t, '$key-end');
      }
      await t.pageBack();
      await wait(t, 900);
    }
    step('daily sheet');
    await tapKey(t, 'home-daily');
    await shot(t, 'daily-sheet');
    await t.tapAt(const Offset(20, 60));
    await wait(t, 900);
    await stopApp(t, s);
  });

  testWidgets('gameplay: real taps, drag, power-up, hint, undo, banner', (
    t,
  ) async {
    final s = await freshServices();
    await startApp(t, s);
    final audio = audioOf(s);
    expect(await waitFor(t, () => audio.isReady), isTrue);

    step('open Classic; banner at the very bottom with a gap');
    await tapKey(t, 'play-classic', settle: 1500);
    expect(find.byType(GameScreen), findsOneWidget);
    final ads = adsOf(s);
    if (ads != null) {
      expect(
        await waitFor(
          t,
          () => find
              .byKey(const ValueKey('game-banner-slot'))
              .evaluate()
              .isNotEmpty,
          seconds: 40,
        ),
        isTrue,
        reason: 'a test banner should load at the bottom of the game',
      );
      final slot = t.getRect(find.byKey(const ValueKey('game-banner-slot')));
      final tray = t.getRect(find.byKey(const ValueKey('hint-button')));
      expect(tray.bottom < slot.top, isTrue, reason: 'controls above banner');
    }
    await shot(t, 'game-start');

    step('place three pieces with real taps');
    final c = controllerOf(t);
    final effects0 = audio.effectsStarted;
    for (var i = 0; i < 3; i++) {
      final m = bestMove(c.state, c.config)!;
      expect(await tapPlace(t, m.$1, m.$2, m.$3), isTrue, reason: 'move $i');
    }
    expect(audio.effectsStarted, greaterThan(effects0), reason: 'sounds play');
    await shot(t, 'game-three-moves');

    step('drag a piece onto the board');
    final before = c.state.moves;
    final slot = [0, 1, 2].firstWhere((i) => c.state.tray[i] != null);
    final from = t.getCenter(find.byKey(ValueKey('tray-$slot')));
    final board = t.getRect(find.byKey(const ValueKey('sand-board')));
    final g = await t.startGesture(from);
    final to = Offset(board.center.dx, board.top + board.height * 0.45);
    for (var i = 1; i <= 12; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 12)!);
      await wait(t, 40);
    }
    await shot(t, 'game-dragging');
    await g.up();
    await wait(t, 1800);
    expect(c.state.moves, before + 1, reason: 'the drag placed the piece');

    step('hint (free), undo (free)');
    await tapKey(t, 'hint-button', settle: 1500);
    expect(c.hint, isNotNull);
    await shot(t, 'game-hint');
    final h = c.hint!;
    expect(await tapPlace(t, h.$1, h.$2, h.$3), isTrue);
    final undoMoves = c.state.moves;
    await tapKey(t, 'undo-button', settle: 1200);
    expect(c.state.moves, undoMoves - 1);

    step('power-up: Extra Move from the starting inventory');
    await tapKey(t, 'power-extra', settle: 1200);
    expect(c.state.bonus, isNotNull);
    await shot(t, 'game-power');

    step('pause menu');
    await t.tap(find.byKey(const ValueKey('pause-button')));
    await wait(t, 900);
    await shot(t, 'pause');
    await t.tap(find.byKey(const ValueKey('pause-resume')));
    await wait(t, 700);
    await backToHome(t);
    expect(s.saves.has(GameMode.classic), isTrue, reason: 'game saved');
    await stopApp(t, s);
  });

  testWidgets('win level 1, interstitial, rewarded double coins', (t) async {
    final s = await freshServices();
    await startApp(t, s);
    final ads = adsOf(s);
    // Two finished games are needed before the first interstitial.
    s.ads.onGameFinished();
    step('campaign level 1 with its intro card');
    await tapKey(t, 'home-campaign');
    await tapKey(t, 'level-1', settle: 1500);
    expect(find.text('Got it'), findsOneWidget);
    await shot(t, 'level1-intro');
    await t.tap(find.text('Got it'));
    await wait(t, 600);
    final def = LevelCatalog.level(1);
    debugPrint('SBMAD begin interstitial');
    for (final (slot, r, col) in def.solution) {
      expect(await tapPlace(t, slot, r, col), isTrue);
    }
    expect(
      await waitFor(
        t,
        () => find.byKey(const ValueKey('results-panel')).evaluate().isNotEmpty,
        seconds: 20,
      ),
      isTrue,
    );
    await wait(t, 12000);
    debugPrint('SBMAD end');
    await shot(t, 'level1-results');
    final c = controllerOf(t);
    expect(c.report!.stars, 3);
    if (ads != null) {
      step('rewarded: double coins');
      expect(await waitFor(t, () => ads.rewardedReady, seconds: 60), isTrue);
      final coins = s.progress.coins;
      debugPrint('SBMAD begin rewarded');
      await tapKey(t, 'double-coins', settle: 500);
      await waitFor(t, () => s.progress.coins > coins, seconds: 60);
      debugPrint('SBMAD end');
      await wait(t, 2000);
      expect(s.progress.coins, coins + c.report!.coins);
    }
    await tapKey(t, 'next-level', settle: 1500);
    expect(controllerOf(t).spec.level, 2);
    await backToHome(t);
    await stopApp(t, s);
  });

  testWidgets('progress survives a restart', (t) async {
    final s = await freshServices();
    s.progress.addCoins(321);
    final coins = s.progress.coins;
    await startApp(t, s);
    await tapKey(t, 'play-classic', settle: 1500);
    final c = controllerOf(t);
    final m = bestMove(c.state, c.config)!;
    await tapPlace(t, m.$1, m.$2, m.$3);
    final board = c.state.board.encode();
    await backToHome(t);
    await stopApp(t, s);

    step('restart with the same storage');
    final again = await freshServices(reset: false);
    expect(again.progress.coins, coins);
    final saved = again.saves.get(GameMode.classic);
    expect(saved, isNotNull);
    expect(saved!.state.board.encode(), board);
    expect(again.settings.value.termsAccepted, greaterThan(0));
    await startApp(t, again);
    expect(find.text('Continue'), findsOneWidget);
    await stopApp(t, again);
  });

  testWidgets('daily puzzle and the other modes open and play', (t) async {
    final s = await freshServices();
    await startApp(t, s);
    step('daily');
    await tapKey(t, 'home-daily');
    await tapKey(t, 'daily-play', settle: 4000);
    expect(
      await waitFor(t, () => find.byType(GameScreen).evaluate().isNotEmpty),
      isTrue,
    );
    var c = controllerOf(t);
    expect(c.mode, GameMode.daily);
    final (bot, moves) = playBot(c.config, maxMoves: DailyPuzzle.moves);
    expect(bot.status, Status.won);
    for (final (slot, r, col) in moves) {
      c.placePiece(slot, r, col);
      await wait(t, 500);
    }
    expect(
      await waitFor(t, () => c.report?.dailyRewarded == true, seconds: 10),
      isTrue,
    );
    await shot(t, 'daily-won');
    await backToHome(t);
    for (final m in ['time', 'moves', 'endless']) {
      step('mode $m');
      await tapKey(t, 'home-modes');
      await tapKey(t, 'mode-$m', settle: 1500);
      c = controllerOf(t);
      for (var i = 0; i < 4 && c.state.isPlaying; i++) {
        final mv = bestMove(c.state, c.config)!;
        await tapPlace(t, mv.$1, mv.$2, mv.$3);
      }
      await shot(t, 'mode-$m');
      await backToHome(t);
    }
    expect(s.settings.value.themePreference, ThemePreference.dark);
    await stopApp(t, s);
  });
}
