// Minimal on-device smoke test: launch, open Classic, place a piece.
//
//   flutter test integration_test/app_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sand_burst_magic/app.dart';
import 'package:sand_burst_magic/bootstrap.dart';
import 'package:sand_burst_magic/core/engine.dart';
import 'package:sand_burst_magic/services/ads/ad_service.dart';
import 'package:sand_burst_magic/ui/screens/game_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch, open Classic, place a piece', (tester) async {
    final services = await bootstrap(adsOverride: NoAdService());
    await services.resetProgress();
    services.settings.update(
      (s) => s.copyWith(tutorialSeen: true, termsAccepted: 1),
    );
    await tester.pumpWidget(
      SandBurstMagicApp(services: services, startAds: false),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('play-classic')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GameScreen), findsOneWidget);
    final c = tester.state<GameScreenState>(find.byType(GameScreen)).controller;
    final m = bestMove(c.state, c.config)!;
    expect(c.placePiece(m.$1, m.$2, m.$3), isTrue);
    expect(c.state.moves, 1);
  });
}
