// Raw screens for the Play Store listing, on a real device with Android's
// demo status bar (set once by device_run.sh) and no ads.
// tool/store_screenshots.py adds the captions.
//
//   flutter test integration_test/store_screens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sand_burst_magic/app.dart';
import 'package:sand_burst_magic/bootstrap.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/core/progression.dart';
import 'package:sand_burst_magic/services/ads/ad_service.dart';
import 'package:sand_burst_magic/state/app_services.dart';

import 'device_helpers.dart';

Future<AppServices> player() async {
  final s = await bootstrap(adsOverride: NoAdService());
  await s.resetProgress();
  s.settings.update((v) => v.copyWith(tutorialSeen: true, termsAccepted: 1));
  final p = s.progress.progress;
  for (var n = 1; n <= 44; n++) {
    final def = LevelCatalog.level(n);
    final moves = def.par + (n % 4 == 1 ? def.par ~/ 2 : 0);
    p.levels[n] = LevelRecord(
      stars: def.starsFor(moves),
      bestMoves: moves,
      bestScore: 900 + n * 37,
    );
  }
  p.coins = 1240;
  final today = s.progress.today;
  for (var d = 4; d >= 1; d--) {
    p.daily.recordCompletion(DateKey.addDays(today, -d), rewardsAllowed: true);
  }
  p.stats
    ..rows = 612
    ..sand = 6120
    ..bestCombo = 7
    ..bestWave = 3
    ..bestByMode['classic'] = 8640;
  p.selected['board'] = 'crystal';
  await s.progress.flush();
  return s;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screens', (t) async {
    final s = await player();
    await t.pumpWidget(SandBurstMagicApp(services: s, startAds: false));
    await wait(t, 3000);
    await shot(t, 'S1-home');

    await tapKey(t, 'home-campaign');
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('level-45')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await wait(t, 800);
    await shot(t, 'S4-campaign');
    await tapKey(t, 'level-45', settle: 1500);
    final c = controllerOf(t);
    final sol = LevelCatalog.level(45).solution;
    for (final (slot, r, col) in sol.take(6)) {
      await tapPlace(t, slot, r, col);
    }
    await t.tap(find.byKey(const ValueKey('tray-0')), warnIfMissed: false);
    await wait(t, 400);
    await shot(t, 'S2-gameplay');
    for (final (slot, r, col) in sol.skip(6)) {
      c.placePiece(slot, r, col);
      await wait(t, 1300);
    }
    await waitFor(t, () => c.finished, seconds: 10);
    await wait(t, 2500);
    await shot(t, 'S7-results');
    await backToHome(t);

    await tapKey(t, 'home-daily');
    await shot(t, 'S3-daily-sheet');
    await t.tapAt(const Offset(20, 80));
    await wait(t, 900);
    await tapKey(t, 'home-modes');
    await shot(t, 'S5-modes');
    await t.pageBack();
    await wait(t, 900);
    await tapKey(t, 'home-themes');
    await shot(t, 'S6-shop');
    await t.pageBack();
    await wait(t, 900);
    await tapKey(t, 'home-stats');
    await shot(t, 'S9-stats');
    await t.pageBack();
    await wait(t, 900);
    await stopApp(t, s);
  });
}
