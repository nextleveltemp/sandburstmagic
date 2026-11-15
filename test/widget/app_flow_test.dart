import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/app.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/state/app_services.dart';
import 'package:sand_burst_magic/ui/screens/game_screen.dart';
import 'package:sand_burst_magic/ui/screens/home_screen.dart';
import 'package:sand_burst_magic/ui/screens/shop_screen.dart';
import 'package:sand_burst_magic/ui/screens/tutorial_screen.dart';
import 'package:sand_burst_magic/ui/screens/welcome_screen.dart';

import '../helpers.dart';

void usePhoneSize(
  WidgetTester tester, {
  Size size = const Size(1080, 2340),
  double ratio = 3,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> startApp(WidgetTester tester, AppServices s) async {
  await tester.pumpWidget(SandBurstMagicApp(services: s, startAds: false));
  await settle(tester, 600);
}

/// Leaves the game and lets timers (saves, toasts) finish.
Future<void> leaveGame(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('pause-button')));
  await settle(tester, 600);
  await tester.tap(find.byKey(const ValueKey('pause-home')));
  await settle(tester, 3000);
}

void main() {
  testWidgets('first launch shows the welcome card', (tester) async {
    usePhoneSize(tester);
    final s = await testServices(termsAccepted: false, tutorialSeen: false);
    await startApp(tester, s);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await settle(tester, 3000);
  });

  testWidgets('the tutorial plays a live demo and leads home', (tester) async {
    usePhoneSize(tester);
    final s = await testServices(tutorialSeen: false);
    await startApp(tester, s);
    expect(find.byType(TutorialScreen), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('tutorial-next')));
      await settle(tester, 1500);
    }
    await tester.tap(find.byKey(const ValueKey('tutorial-next')));
    await settle(tester, 1000);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(s.settings.value.tutorialSeen, isTrue);
    await settle(tester, 3000);
  });

  testWidgets('play Classic: tap a piece, preview, confirm, pause, home', (
    tester,
  ) async {
    usePhoneSize(tester);
    final s = await testServices();
    await startApp(tester, s);
    expect(find.byKey(const ValueKey('play-classic')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-classic')));
    await settle(tester, 800);
    expect(find.byType(GameScreen), findsOneWidget);
    final board = find.byKey(const ValueKey('sand-board'));
    expect(board, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tray-0')));
    await settle(tester, 300);
    // First tap shows where the piece would go, the second places it.
    await tester.tap(board);
    await settle(tester, 300);
    expect(s.saves.get(GameMode.classic)?.state.moves ?? 0, 0);
    await tester.tap(board);
    await settle(tester, 2500);
    expect(s.saves.get(GameMode.classic)!.state.moves, 1);
    expect(s.progress.stats.pieces, 1);
    await leaveGame(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('drag a piece onto the board', (tester) async {
    usePhoneSize(tester);
    final s = await testServices();
    await startApp(tester, s);
    await tester.tap(find.byKey(const ValueKey('play-classic')));
    await settle(tester, 800);
    final from = tester.getCenter(find.byKey(const ValueKey('tray-1')));
    final board = tester.getRect(find.byKey(const ValueKey('sand-board')));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    // Move in steps (drag start needs a little travel), ending well inside
    // the board; the piece floats above the finger.
    final target = Offset(board.center.dx, board.top + board.height * 0.7);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, target, i / 10)!);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await settle(tester, 2500);
    expect(s.saves.get(GameMode.classic)!.state.moves, 1);
    await leaveGame(tester);
  });

  testWidgets('campaign level 1 shows its introduction card', (tester) async {
    usePhoneSize(tester);
    final s = await testServices();
    await startApp(tester, s);
    await tester.tap(find.byKey(const ValueKey('home-levels')));
    await settle(tester, 800);
    await tester.tap(find.byKey(const ValueKey('level-1')));
    await settle(tester, 800);
    expect(find.text('Place a piece'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await settle(tester, 400);
    expect(s.progress.introSeen('place'), isTrue);
    await leaveGame(tester);
    expect(LevelCatalog.count, 100);
  });

  testWidgets('home is laid out like Block Burst Magic', (tester) async {
    usePhoneSize(tester);
    final s = await testServices();
    await startApp(tester, s);
    // Top row: player card (Statistics), Themes, Settings.
    expect(find.byKey(const ValueKey('home-stats')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-themes')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-settings')), findsOneWidget);
    // Play, with Levels right under it.
    final play = tester.getRect(find.byKey(const ValueKey('play-classic')));
    final levels = tester.getRect(find.byKey(const ValueKey('home-levels')));
    expect(levels.top > play.bottom, isTrue);
    expect(find.text("Today's goals"), findsOneWidget);
    expect(find.text('More ways to play'), findsOneWidget);
    // No banner anywhere on the home screen.
    expect(find.byKey(const ValueKey('game-banner-slot')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-stats')));
    await settle(tester, 800);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    await settle(tester, 3000);
  });

  testWidgets('shop sells power-ups and looks', (tester) async {
    usePhoneSize(tester);
    final s = await testServices();
    await startApp(tester, s);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-shop')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, 300);
    await tester.tap(find.byKey(const ValueKey('home-shop')));
    await settle(tester, 800);
    expect(find.byType(ShopScreen), findsOneWidget);
    final coins = s.progress.coins;
    await tester.tap(find.byKey(const ValueKey('buy-shaker')));
    await settle(tester, 300);
    expect(s.progress.coins, lessThan(coins));
    await settle(tester, 3000);
  });
}
