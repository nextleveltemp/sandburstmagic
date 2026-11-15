// A full play session like a real player, on a device: welcome card,
// tutorial, Classic, campaign levels, the daily puzzle, a mode, the shop,
// with ads at natural breaks (closed by device_watch.sh).
//
//   flutter test integration_test/playthrough_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sand_burst_magic/app.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/ui/screens/game_screen.dart';
import 'package:sand_burst_magic/ui/screens/home_screen.dart';

import 'device_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a player session', (t) async {
    final s = await freshServices();
    s.settings.update((v) => v.copyWith(termsAccepted: 0, tutorialSeen: false));
    await t.pumpWidget(SandBurstMagicApp(services: s));
    await wait(t, 3000);

    step('welcome card: accept the terms');
    expect(find.text('Accept'), findsOneWidget);
    await shot(t, 'welcome');
    await t.tap(find.text('Accept'));
    await wait(t, 2000);

    step('tutorial: read every page');
    for (var i = 0; i < 4; i++) {
      await shot(t, 'tutorial-$i');
      await t.tap(find.byKey(const ValueKey('tutorial-next')));
      await wait(t, 2500);
    }
    expect(find.byType(HomeScreen), findsOneWidget);

    step('Classic: 25 moves with real taps');
    await tapKey(t, 'play-classic', settle: 1500);
    var c = controllerOf(t);
    for (var i = 0; i < 25 && c.state.isPlaying; i++) {
      final m = bestMove(c.state, c.config)!;
      expect(await tapPlace(t, m.$1, m.$2, m.$3), isTrue, reason: 'move $i');
      if (i == 12) await shot(t, 'classic-mid');
    }
    expect(c.state.rows, greaterThan(0), reason: 'rows burst');
    await backToHome(t);

    step('campaign levels 1-3');
    for (var n = 1; n <= 3; n++) {
      await tapKey(t, 'home-campaign');
      await tapKey(t, 'level-$n', settle: 1500);
      if (find.text('Got it').evaluate().isNotEmpty) {
        await t.tap(find.text('Got it'));
        await wait(t, 600);
      }
      c = controllerOf(t);
      debugPrint('SBMAD begin level-$n');
      for (final (slot, r, col) in LevelCatalog.level(n).solution) {
        expect(await tapPlace(t, slot, r, col), isTrue);
      }
      await waitFor(t, () => c.finished, seconds: 10);
      await wait(t, 10000);
      debugPrint('SBMAD end');
      await shot(t, 'level-$n-done');
      expect(c.report!.won, isTrue);
      await backToHome(t);
    }
    expect(s.progress.unlockedLevel, 4);

    step('Time Challenge for a few moves');
    await tapKey(t, 'home-modes');
    await tapKey(t, 'mode-time', settle: 1500);
    c = controllerOf(t);
    for (var i = 0; i < 6 && c.state.isPlaying; i++) {
      final m = bestMove(c.state, c.config)!;
      await tapPlace(t, m.$1, m.$2, m.$3);
    }
    expect(c.timeLeftMs, lessThan(Modes.timeSeconds * 1000));
    await shot(t, 'time');
    await backToHome(t);

    step('shop: buy a power-up');
    final coins = s.progress.coins;
    await tapKey(t, 'home-shop');
    await tapKey(t, 'buy-shaker');
    expect(s.progress.coins, lessThan(coins));
    await shot(t, 'shop');
    await t.pageBack();
    await wait(t, 1000);
    expect(find.byType(GameScreen), findsNothing);
    await stopApp(t, s);
  });
}
