// Renders the raw Play Store screens on the CI host, without an emulator,
// with the app's own fonts at a Pixel 6's 1080 x 2400 (2.625 px per dp).
// The CI job "store-shots" runs it, then tool/store_screenshots.py adds the
// captions:
//
//   flutter test store_shots/store_shots_test.dart
//   python3 tool/store_screenshots.py build/store_raw store/screenshots
//
// It is outside test/ so the normal test run does not write these files.
// The status and navigation bar areas are reserved (as on the phone) and
// cropped by the caption tool.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/app.dart';
import 'package:sand_burst_magic/core/levels.dart';
import 'package:sand_burst_magic/core/progression.dart';
import 'package:sand_burst_magic/data/kv_store.dart';
import 'package:sand_burst_magic/l10n/strings.dart';
import 'package:sand_burst_magic/state/app_services.dart';
import 'package:sand_burst_magic/state/game_controller.dart';
import 'package:sand_burst_magic/ui/screens/game_screen.dart';
import 'package:sand_burst_magic/ui/share/result_card.dart';
import 'package:sand_burst_magic/ui/share/share_actions.dart';
import 'package:sand_burst_magic/ui/theme/app_theme.dart';

import '../test/helpers.dart';

const _out = 'build/store_raw';
const _ratio = 2.625;
const _shotKey = ValueKey('store-shot');

/// A fixed morning, so the daily puzzle and goals are always the same.
DateTime _clock() => DateTime(2026, 10, 24, 9, 41);

Future<void> _loadFonts() async {
  final outfit = FontLoader('Outfit');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    outfit.addFont(rootBundle.load('assets/fonts/Outfit-$w.ttf'));
  }
  await outfit.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (root == null || !icons.existsSync()) {
    fail('Material icons font not found (set FLUTTER_ROOT)');
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
  // Symbols Outfit lacks (★, ≤) come from the system fonts on a phone;
  // here from DejaVu Sans (preinstalled on the CI machines).
  final symbols = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  if (!symbols.existsSync()) fail('DejaVu Sans not found');
  final fallback = FontLoader(AppTheme.symbolFallback.first)
    ..addFont(Future.value(ByteData.sublistView(symbols.readAsBytesSync())));
  await fallback.load();
}

/// A believable player a few days in: 44 levels won, coins, a streak,
/// some achievements, missions under way.
Future<AppServices> _player() async {
  final s = await testServices(store: MemoryKvStore(), clock: _clock);
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
  final now = _clock().millisecondsSinceEpoch;
  for (final id in ['firstRow', 'rows100', 'double', 'triple', 'combo5',
      'level10', 'world1', 'streak3']) {
    p.achievements[id] = now;
  }
  p.stats
    ..rows = 612
    ..sand = 6120
    ..pieces = 1980
    ..bestCombo = 7
    ..bestWave = 3
    ..multi = 48
    ..playSeconds = 4 * 3600 + 12 * 60
    ..gamesByMode['classic'] = 23
    ..gamesByMode['campaign'] = 52
    ..bestByMode['classic'] = 8640
    ..bestByMode['time'] = 3120;
  final m = s.progress.missions;
  final first = m.missions.first;
  m.progress[first.id] = first.target;
  m.progress[m.missions[1].id] = m.missions[1].target ~/ 2;
  p.selected['board'] = 'crystal';
  await s.progress.flush();
  return s;
}

Future<void> _open(WidgetTester t, AppServices s) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = _ratio;
  // Pixel 6: status bar 126 px, gesture bar 62 px.
  const bars = FakeViewPadding(top: 126, bottom: 62);
  t.view.padding = bars;
  t.view.viewPadding = bars;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: SandBurstMagicApp(services: s, startAds: false),
    ),
  );
  await _settle(t, 1500);
}

Future<void> _settle(WidgetTester t, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  await _settle(t, 400);
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  final png = await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  File('$_out/store-$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!);
}

Future<void> _tapKey(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f);
  await _settle(t, 300);
  await t.tap(f);
  await _settle(t);
}

GameController _game(WidgetTester t) =>
    t.state<GameScreenState>(find.byType(GameScreen)).controller;

/// Opens campaign level [n] and plays the first [moves] moves of its proof.
Future<GameController> _playLevel(WidgetTester t, int n, int moves) async {
  await _tapKey(t, 'home-campaign');
  await t.scrollUntilVisible(
    find.byKey(ValueKey('level-$n')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await _settle(t, 300);
  await t.tap(find.byKey(ValueKey('level-$n')));
  await _settle(t, 800);
  final c = _game(t);
  final sol = LevelCatalog.level(n).solution;
  for (final (slot, r, col) in sol.take(moves)) {
    c.placePiece(slot, r, col);
    await _settle(t, 1500);
  }
  return c;
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('S1 home', (t) async {
    await _open(t, await _player());
    await _shot(t, 'S1-home');
    await _settle(t, 3000);
  });

  testWidgets('S2 gameplay, S7 results, S8 share card', (t) async {
    await _open(t, await _player());
    final c = await _playLevel(t, 45, 6);
    // A piece lifted from the tray, with its preview on the board.
    await t.tap(find.byKey(const ValueKey('tray-0')), warnIfMissed: false);
    await _settle(t, 300);
    await _shot(t, 'S2-gameplay');
    final sol = LevelCatalog.level(45).solution;
    for (final (slot, r, col) in sol.skip(6)) {
      c.placePiece(slot, r, col);
      await _settle(t, 1500);
    }
    await _settle(t, 2500);
    expect(find.byKey(const ValueKey('results-panel')), findsOneWidget);
    await _shot(t, 'S7-results');
    const s = Strings();
    final card = await t.runAsync(() => ResultCard.renderPng(cardData(s, c)));
    File('$_out/store-S8-share-card.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(card!);
    await _settle(t, 3000);
  });

  testWidgets('S3 daily sheet', (t) async {
    await _open(t, await _player());
    await _tapKey(t, 'home-daily');
    await _settle(t, 1500);
    await _shot(t, 'S3-daily-sheet');
    await _settle(t, 3000);
  });

  testWidgets('S4 campaign', (t) async {
    await _open(t, await _player());
    await _tapKey(t, 'home-campaign');
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('level-45')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(t, 600);
    await _shot(t, 'S4-campaign');
    await _settle(t, 3000);
  });

  testWidgets('S5 modes', (t) async {
    await _open(t, await _player());
    await _tapKey(t, 'home-modes');
    await _shot(t, 'S5-modes');
    await _settle(t, 3000);
  });

  testWidgets('S6 shop', (t) async {
    await _open(t, await _player());
    await _tapKey(t, 'home-themes');
    await _settle(t, 800);
    await _shot(t, 'S6-shop');
    await _settle(t, 3000);
  });

  testWidgets('S9 statistics', (t) async {
    await _open(t, await _player());
    await _tapKey(t, 'home-stats');
    await _shot(t, 'S9-stats');
    await _settle(t, 3000);
  });

  // Not store images: every board theme on the game screen, for checking
  // that each one looks clearly different and stays readable.
  for (final c in Cosmetics.ofKind(CosmeticKind.board)) {
    testWidgets('board ${c.id}', (t) async {
      final s = await _player();
      s.progress.progress.owned.add(c.key);
      s.progress.progress.selected['board'] = c.id;
      await _open(t, s);
      await _playLevel(t, 45, 4);
      await _shot(t, 'board-${c.id}');
      await _settle(t, 3000);
    });
  }
}
