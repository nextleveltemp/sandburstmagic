import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/engine.dart';
import '../core/levels.dart';
import '../data/doc_store.dart';
import '../data/docs.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../services/ads/ad_service.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/purchase_service.dart';
import '../services/reminder_service.dart';
import '../services/review_service.dart';
import '../services/share_service.dart';
import 'progress_controller.dart';
import 'settings_controller.dart';

/// Saved, resumable puzzles (one per mode).
class GameSaves extends ChangeNotifier {
  GameSaves(this._store) {
    for (final m in Docs.savedModes) {
      final loaded = _store.load(Docs.game(m)!).value;
      if (loaded != null && loaded.state.isPlaying) _cache[m] = loaded;
    }
  }

  final DocStore _store;
  final Map<GameMode, SavedGame> _cache = {};

  SavedGame? get(GameMode mode) => _cache[mode];

  bool _notifyQueued = false;

  /// Saves also happen while a game screen is being disposed (when the
  /// widget tree is locked), so listeners are told a moment later.
  void _changed() {
    if (_notifyQueued) return;
    _notifyQueued = true;
    scheduleMicrotask(() {
      _notifyQueued = false;
      notifyListeners();
    });
  }

  bool has(GameMode mode) => _cache.containsKey(mode);

  Future<void> save(SavedGame game) async {
    final spec = Docs.game(game.spec.mode);
    if (spec == null) return;
    final hadIt = _cache.containsKey(game.spec.mode);
    _cache[game.spec.mode] = game;
    if (!hadIt) _changed();
    await _store.save(spec, game);
  }

  /// Deletes the save of [mode] only if it belongs to the puzzle [key]
  /// (finishing a replayed level must not delete another level's save).
  Future<void> deleteIfFor(GameMode mode, String key) async {
    final saved = _cache[mode];
    if (saved == null || saved.spec.key != key) return;
    await delete(mode);
  }

  Future<void> delete(GameMode mode) async {
    final spec = Docs.game(mode);
    if (spec == null) return;
    if (_cache.remove(mode) != null) _changed();
    await _store.delete(spec);
  }

  Future<void> deleteAll() async {
    for (final m in Docs.savedModes) {
      await delete(m);
    }
  }
}

/// Runs bot searches off the UI thread (background isolate), so the game
/// never stutters while a daily puzzle is generated or a hint is found.
class PuzzleWorker {
  /// [inline] runs jobs on the calling isolate (widget tests).
  const PuzzleWorker({this.inline = false});

  final bool inline;

  Future<T> _run<T>(T Function() job) =>
      inline || kIsWeb ? Future<T>.sync(job) : Isolate.run(job);

  Future<Move?> hint(GameConfig config, GameState state) =>
      _run(() => bestMove(state, config));

  Future<DailyPuzzle> daily(String date) =>
      _run(() => DailyPuzzle.generate(date));
}

/// Provides today's daily puzzle. Generation runs the solver, so it happens
/// on a background isolate and the result is cached for the day.
class DailyService {
  DailyService(this._store, this._worker);

  final DocStore _store;
  final PuzzleWorker _worker;
  DailyPuzzle? _memo;
  Future<DailyPuzzle>? _inFlight;

  Future<DailyPuzzle> forDate(String date) {
    final memo = _memo;
    if (memo != null && memo.dateKey == date) return Future.value(memo);
    final cached = _store.load(Docs.dailyCache).value;
    if (cached != null && cached.puzzle.dateKey == date) {
      _memo = cached.puzzle;
      return Future.value(cached.puzzle);
    }
    final running = _inFlight;
    if (running != null) return running;
    final future = _generate(date);
    _inFlight = future;
    return future;
  }

  Future<DailyPuzzle> _generate(String date) async {
    try {
      final puzzle = await _worker.daily(date);
      _memo = puzzle;
      unawaited(_store.save(Docs.dailyCache, CachedDaily(puzzle)));
      return puzzle;
    } finally {
      _inFlight = null;
    }
  }
}

/// Everything the UI needs, created once at startup.
class AppServices {
  AppServices({
    required this.store,
    required this.settings,
    required this.progress,
    required this.saves,
    required this.audio,
    required this.haptics,
    required this.ads,
    required this.daily,
    required this.share,
    required this.review,
    required this.reminders,
    required this.purchases,
    required this.appVersion,
    this.worker = const PuzzleWorker(),
  }) {
    // "Remove ads" switches the banner and between-puzzles ads off.
    ads.setAdsRemoved(purchases.adsRemoved);
    purchases.addListener(() => ads.setAdsRemoved(purchases.adsRemoved));
  }

  final DocStore store;
  final SettingsController settings;
  final ProgressController progress;
  final GameSaves saves;
  final AudioService audio;
  final HapticsService haptics;
  final AdService ads;
  final DailyService daily;
  final ShareService share;
  final ReviewService review;
  final ReminderService reminders;
  final PurchaseService purchases;
  final String appVersion;
  final PuzzleWorker worker;

  String? _reminderPlan;
  Future<void> _reminderOps = Future.value();

  /// Brings the scheduled reminders in line with the settings and today's
  /// daily puzzle. Cheap to call often: it only reschedules when the
  /// setting, the time, the date or the solved state changed (or [force]).
  Future<void> syncReminders({bool force = false}) {
    final op = _reminderOps.then((_) => _syncReminders(force));
    _reminderOps = op.catchError((Object e) {
      debugPrint('Reminder sync failed: $e');
    });
    return _reminderOps;
  }

  Future<void> _syncReminders(bool force) async {
    final s = settings.value;
    final solved = progress.dailyDoneToday;
    final plan = s.reminder
        ? 'on/${s.reminderMinutes}/${progress.today}/$solved'
        : 'off';
    if (!force && plan == _reminderPlan) return;
    _reminderPlan = plan;
    if (!s.reminder) {
      await reminders.cancelAll();
      return;
    }
    final t = Strings.forLocale(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    await reminders.schedule(
      minutesAfterMidnight: s.reminderMinutes,
      solvedToday: solved,
      title: t.reminderTitle,
      body: t.reminderBody,
      channelName: t.reminderChannel,
      channelDescription: t.reminderChannelDescription,
    );
  }

  /// Applies settings to services that cache them.
  void applySettings() {
    final s = settings.value;
    audio.applySettings(sfx: s.sfx, music: s.music, volume: s.volume);
    haptics.enabled = s.haptics;
  }

  /// Saves everything now (app going to background or closing).
  Future<void> flush() async {
    await progress.flush();
    await store.flush();
  }

  /// Deletes progress and saved games but keeps settings.
  Future<void> resetProgress() async {
    await saves.deleteAll();
    await store.delete(Docs.dailyCache);
    await progress.resetAll();
    unawaited(syncReminders());
  }
}

/// Makes [AppServices] available to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!.services;
  }

  /// Lookup without subscribing to changes; safe in `initState`.
  static AppServices read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
