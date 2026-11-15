// Shared helpers for the on-device tests (REAL storage, REAL audio and
// REAL Google test ads). CI runs them next to .github/scripts/device_watch.sh,
// which takes a screenshot whenever the log shows "SBMSHOT <name>" and closes
// full-screen ads (like a player would) between "SBMAD begin" and
// "SBMAD end".

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sand_burst_magic/app.dart';
import 'package:sand_burst_magic/bootstrap.dart';
import 'package:sand_burst_magic/core/sand.dart';
import 'package:sand_burst_magic/data/docs.dart';
import 'package:sand_burst_magic/data/models.dart';
import 'package:sand_burst_magic/services/ads/admob_ad_service.dart';
import 'package:sand_burst_magic/services/audio_service.dart';
import 'package:sand_burst_magic/state/app_services.dart';
import 'package:sand_burst_magic/state/game_controller.dart';
import 'package:sand_burst_magic/ui/screens/game_screen.dart';

/// Pumps frames for [ms] milliseconds of real time.
Future<void> wait(WidgetTester t, [int ms = 600]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// After a tap that opens a web page: lets the browser show it (and the
/// watcher take screenshot [shotName]), then comes back to the game. The
/// browser covers the game, which then draws no frames, so this waits in
/// real time (pumping would wait for a frame that never comes).
Future<void> visitBrowserAndBack(WidgetTester t, String shotName) async {
  await Future<void>.delayed(const Duration(seconds: 7));
  debugPrint('SBMSHOT $shotName');
  await Future<void>.delayed(const Duration(seconds: 3));
  // The watcher presses BACK if another app (the browser) is on top.
  debugPrint('SBMBACK $shotName');
  for (var i = 0; i < 40; i++) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  expect(
    WidgetsBinding.instance.lifecycleState,
    AppLifecycleState.resumed,
    reason: 'the game comes back after the web page',
  );
  await wait(t, 2000);
}

/// Pumps until [cond] holds; returns whether it did within [seconds].
Future<bool> waitFor(
  WidgetTester t,
  bool Function() cond, {
  int seconds = 30,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    if (cond()) return true;
    await wait(t, 250);
  }
  return cond();
}

/// Asks the watcher script for a screenshot and gives it time to take it.
Future<void> shot(WidgetTester t, String name) async {
  await wait(t, 900);
  debugPrint('SBMSHOT $name');
  await wait(t, 2500);
}

void step(String what) => debugPrint('SBMSTEP $what');

ConsentDebugSettings? _umpDebug;
bool _umpProbed = false;

/// Google's consent SDK only simulates a region on registered test devices.
/// It prints this device's test ID to the log on first use, so read it from
/// our own log and ask for a region with no consent regulation. (The App ID
/// used for testing is Google's sample, which has no consent messages set
/// up; in a regulated region it would therefore never allow ads.)
Future<ConsentDebugSettings?> umpDebugSettings() async {
  if (_umpProbed) return _umpDebug;
  _umpProbed = true;
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () {
      if (!done.isCompleted) done.complete();
    },
    (FormError e) {
      if (!done.isCompleted) done.complete();
    },
  );
  await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  final log = await Process.run('logcat', ['-d']);
  final m = RegExp(
    r'addTestDeviceHashedId\("([0-9A-Fa-f]+)"\)',
  ).firstMatch('${log.stdout}');
  await ConsentInformation.instance.reset();
  if (m == null) {
    debugPrint('SBMINFO consent SDK test-device ID not found in the log');
    return null;
  }
  debugPrint('SBMINFO consent SDK test device ${m.group(1)}');
  return _umpDebug = ConsentDebugSettings(
    debugGeography: DebugGeography.debugGeographyOther,
    testIdentifiers: [m.group(1)!],
  );
}

final List<AppServices> _live = [];

Future<AppServices> freshServices({bool reset = true}) async {
  // Silence any players left by an earlier test that failed half-way.
  for (final old in _live) {
    old.audio.stopMusic();
    await old.audio.dispose();
  }
  _live.clear();
  final s = await bootstrap(consentDebugSettings: await umpDebugSettings());
  _live.add(s);
  if (reset) {
    await s.resetProgress();
    // Fresh ad frequency state too (earlier tests solved puzzles).
    await s.store.delete(Docs.ads);
    s.settings.update(
      (v) => v.copyWith(
        tutorialSeen: true,
        termsAccepted: 1,
        sfx: true,
        music: true,
        volume: 0.8,
        themePreference: ThemePreference.dark,
      ),
    );
  }
  return s;
}

Future<void> startApp(WidgetTester t, AppServices s) async {
  await t.pumpWidget(SandBurstMagicApp(services: s));
  expect(
    await waitFor(t, () => find.byKey(const ValueKey('play-classic')).evaluate().isNotEmpty),
    isTrue,
    reason: 'home screen should appear',
  );
  await wait(t, 800);
}

Future<void> stopApp(WidgetTester t, AppServices s) async {
  s.audio.stopMusic();
  await t.pumpWidget(const SizedBox.shrink());
  await wait(t, 500);
  await s.flush();
  await s.audio.dispose();
  _live.remove(s);
  await wait(t, 1500);
}

PluginAudioService audioOf(AppServices s) => s.audio as PluginAudioService;

/// The AdMob service, or null when this build has ads switched off.
AdMobAdService? adsOf(AppServices s) =>
    s.ads is AdMobAdService ? s.ads as AdMobAdService : null;

GameController controllerOf(WidgetTester t) =>
    t.state<GameScreenState>(find.byType(GameScreen)).controller;

/// Taps a widget by key (scrolling to it first if needed).
Future<void> tapKey(WidgetTester t, String key, {int settle = 900}) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f);
  await wait(t, 300);
  await t.tap(f, warnIfMissed: false);
  await wait(t, settle);
}

/// Places a piece like a finger: tap the tray piece, then the board cell
/// twice (preview, then confirm).
Future<bool> tapPlace(WidgetTester t, int slot, int row, int col) async {
  final c = controllerOf(t);
  await waitFor(t, () => !c.finished, seconds: 1);
  final before = c.state.moves;
  final p = slot == 3 ? c.state.bonus : c.state.tray[slot];
  if (p == null) return false;
  await t.tap(find.byKey(ValueKey('tray-$slot')), warnIfMissed: false);
  await wait(t, 200);
  final board = t.getRect(find.byKey(const ValueKey('sand-board')));
  final cell = board.width / 10;
  final rows = shapes[p.shape].rows;
  final cols = shapes[p.shape].cols;
  // The tapped cell becomes the piece's centre cell.
  final tr = row + (rows - 1) ~/ 2;
  final tc = col + (cols - 1) ~/ 2;
  final at = board.topLeft + Offset((tc + 0.5) * cell, (tr + 0.5) * cell);
  await t.tapAt(at);
  await wait(t, 200);
  await t.tapAt(at);
  // Let the sand settle and the tray refill.
  await waitFor(t, () => c.state.moves > before, seconds: 3);
  await wait(t, 1400);
  return c.state.moves > before;
}

/// Back to the home screen from anywhere.
Future<void> backToHome(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    if (find.byKey(const ValueKey('play-classic')).evaluate().isNotEmpty) {
      return;
    }
    final pause = find.byKey(const ValueKey('pause-button'));
    final home = find.byKey(const ValueKey('results-home'));
    if (home.evaluate().isNotEmpty) {
      await t.tap(home, warnIfMissed: false);
    } else if (pause.evaluate().isNotEmpty &&
        find.byKey(const ValueKey('continue-decline')).evaluate().isEmpty) {
      await t.tap(pause);
      await wait(t, 700);
      await t.tap(find.byKey(const ValueKey('pause-home')));
    } else if (find.byKey(const ValueKey('continue-decline')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const ValueKey('continue-decline')));
    } else {
      await t.pageBack();
    }
    await wait(t, 1200);
  }
}
