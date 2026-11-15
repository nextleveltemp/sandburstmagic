import '../core/engine.dart';
import '../core/levels.dart';
import '../core/progression.dart';

enum ThemePreference { system, dark, light }

/// User preferences.
class AppSettings {
  const AppSettings({
    this.sfx = true,
    this.music = true,
    this.volume = 0.8,
    this.haptics = true,
    this.themePreference = ThemePreference.dark,
    this.reduceMotion = false,
    this.showDailyGoals = true,
    this.tutorialSeen = false,
    this.reminder = false,
    this.reminderMinutes = defaultReminderMinutes,
    this.termsAccepted = 0,
  });

  /// 7:00 PM local time.
  static const int defaultReminderMinutes = 19 * 60;

  final bool sfx;
  final bool music;

  /// Master volume 0.0–1.0 applied to effects and music.
  final double volume;
  final bool haptics;
  final ThemePreference themePreference;
  final bool reduceMotion;

  /// Today's goals card on the home screen.
  final bool showDailyGoals;
  final bool tutorialSeen;

  /// Opt-in daily puzzle reminder (local notification), off by default.
  final bool reminder;

  /// Reminder time as minutes after local midnight.
  final int reminderMinutes;

  /// Version of the Terms of Use the player accepted (0 = not yet).
  final int termsAccepted;

  AppSettings copyWith({
    bool? sfx,
    bool? music,
    double? volume,
    bool? haptics,
    ThemePreference? themePreference,
    bool? reduceMotion,
    bool? showDailyGoals,
    bool? tutorialSeen,
    bool? reminder,
    int? reminderMinutes,
    int? termsAccepted,
  }) => AppSettings(
    sfx: sfx ?? this.sfx,
    music: music ?? this.music,
    volume: volume ?? this.volume,
    haptics: haptics ?? this.haptics,
    themePreference: themePreference ?? this.themePreference,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    showDailyGoals: showDailyGoals ?? this.showDailyGoals,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    reminder: reminder ?? this.reminder,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    termsAccepted: termsAccepted ?? this.termsAccepted,
  );

  Map<String, Object?> toJson() => {
    'sfx': sfx,
    'music': music,
    'volume': volume,
    'haptics': haptics,
    'theme': themePreference.name,
    'reduceMotion': reduceMotion,
    'showDailyGoals': showDailyGoals,
    'tutorialSeen': tutorialSeen,
    'reminder': reminder,
    'reminderMinutes': reminderMinutes,
    'termsAccepted': termsAccepted,
  };

  /// Tolerant parser: any missing or invalid field falls back to its default.
  static AppSettings fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    bool b(String k, bool def) {
      final v = json[k];
      return v is bool ? v : def;
    }

    final vol = json['volume'];
    final rawVolume = vol is num ? vol.toDouble() : d.volume;
    final volume = rawVolume.isNaN
        ? d.volume
        : (rawVolume < 0 ? 0.0 : (rawVolume > 1 ? 1.0 : rawVolume));
    final themeName = json['theme'];
    final theme = ThemePreference.values.where((t) => t.name == themeName);
    final minutes = json['reminderMinutes'];
    final terms = json['termsAccepted'];
    return AppSettings(
      sfx: b('sfx', d.sfx),
      music: b('music', d.music),
      volume: volume,
      haptics: b('haptics', d.haptics),
      themePreference: theme.isEmpty ? d.themePreference : theme.first,
      reduceMotion: b('reduceMotion', d.reduceMotion),
      showDailyGoals: b('showDailyGoals', d.showDailyGoals),
      tutorialSeen: b('tutorialSeen', d.tutorialSeen),
      reminder: b('reminder', d.reminder),
      reminderMinutes: minutes is int && minutes >= 0 && minutes < 24 * 60
          ? minutes
          : d.reminderMinutes,
      termsAccepted: terms is int && terms >= 0 ? terms : d.termsAccepted,
    );
  }
}

/// What the player bought (one-time Google Play purchases).
class PurchaseState {
  const PurchaseState({this.adsRemoved = false});

  /// "Remove ads": no banner and no between-puzzles ads, forever.
  final bool adsRemoved;

  Map<String, Object?> toJson() => {'adsRemoved': adsRemoved};

  static PurchaseState fromJson(Map<String, Object?> json) =>
      PurchaseState(adsRemoved: json['adsRemoved'] == true);
}

/// When the app last asked for a Play Store rating (in-app review).
class ReviewState {
  const ReviewState({this.count = 0, this.lastMillis = 0});

  final int count;
  final int lastMillis;

  Map<String, Object?> toJson() => {'count': count, 'last': lastMillis};

  static ReviewState fromJson(Map<String, Object?> json) {
    final c = json['count'];
    final l = json['last'];
    return ReviewState(
      count: c is int && c >= 0 ? c : 0,
      lastMillis: l is int && l >= 0 ? l : 0,
    );
  }
}

/// Everything the player has earned. Mutable; the ProgressController is
/// the only writer.
class PlayerProgress {
  PlayerProgress({
    this.coins = Coins.starting,
    Map<PowerUp, int>? inventory,
    Set<String>? owned,
    Map<String, String>? selected,
    Map<int, LevelRecord>? levels,
    DailyRecord? daily,
    LifetimeStats? stats,
    Map<String, int>? achievements,
    this.missions,
    Set<String>? seenIntros,
  }) : inventory = inventory ?? Map<PowerUp, int>.of(PowerShop.starting),
       owned = owned ?? <String>{},
       selected = selected ?? <String, String>{},
       levels = levels ?? <int, LevelRecord>{},
       daily = daily ?? DailyRecord(),
       stats = stats ?? LifetimeStats(),
       achievements = achievements ?? <String, int>{},
       seenIntros = seenIntros ?? <String>{};

  int coins;
  final Map<PowerUp, int> inventory;

  /// Bought cosmetics (Cosmetic.key).
  final Set<String> owned;

  /// Chosen cosmetic id per CosmeticKind.name.
  final Map<String, String> selected;
  final Map<int, LevelRecord> levels;
  final DailyRecord daily;
  final LifetimeStats stats;

  /// Achievement id -> unlock time (millis).
  final Map<String, int> achievements;
  MissionsState? missions;

  /// Mechanics whose introduction card the player has seen.
  final Set<String> seenIntros;

  int count(PowerUp p) => inventory[p] ?? 0;

  /// The highest level the player may play (the first not yet won).
  int get unlockedLevel {
    var n = 1;
    while (n < LevelCatalog.count && (levels[n]?.stars ?? 0) > 0) {
      n++;
    }
    return n;
  }

  int get levelsCompleted => levels.values.where((r) => r.stars > 0).length;

  Map<String, Object?> toJson() => {
    'coins': coins,
    'inventory': {for (final e in inventory.entries) e.key.name: e.value},
    'owned': owned.toList()..sort(),
    'selected': Map<String, String>.of(selected),
    'levels': {for (final e in levels.entries) '${e.key}': e.value.toJson()},
    'daily': daily.toJson(),
    'stats': stats.toJson(),
    'achievements': Map<String, int>.of(achievements),
    'missions': missions?.toJson(),
    'intros': seenIntros.toList()..sort(),
  };

  static PlayerProgress fromJson(Map<String, Object?> json) {
    final coins = json['coins'];
    final inv = <PowerUp, int>{};
    final rawInv = json['inventory'];
    if (rawInv is Map) {
      for (final e in rawInv.entries) {
        final p = PowerUp.values.where((v) => v.name == e.key);
        final v = e.value;
        if (p.isNotEmpty && v is int && v >= 0) inv[p.first] = v;
      }
    } else {
      inv.addAll(PowerShop.starting);
    }
    final owned = <String>{};
    final rawOwned = json['owned'];
    if (rawOwned is List) {
      for (final k in rawOwned) {
        if (k is String && Cosmetics.byKey(k) != null) owned.add(k);
      }
    }
    final selected = <String, String>{};
    final rawSel = json['selected'];
    if (rawSel is Map) {
      for (final e in rawSel.entries) {
        if (e.key is String && e.value is String) {
          selected[e.key as String] = e.value as String;
        }
      }
    }
    final levels = <int, LevelRecord>{};
    final rawLevels = json['levels'];
    if (rawLevels is Map) {
      for (final e in rawLevels.entries) {
        final k = e.key is String ? int.tryParse(e.key as String) : null;
        if (k != null && k > 0 && k <= LevelCatalog.count) {
          levels[k] = LevelRecord.fromJson(e.value);
        }
      }
    }
    final ach = <String, int>{};
    final rawAch = json['achievements'];
    if (rawAch is Map) {
      for (final e in rawAch.entries) {
        final k = e.key;
        final v = e.value;
        if (k is String && v is int && Achievements.byId(k) != null) {
          ach[k] = v;
        }
      }
    }
    final intros = json['intros'];
    return PlayerProgress(
      coins: coins is int && coins >= 0 ? coins : Coins.starting,
      inventory: inv,
      owned: owned,
      selected: selected,
      levels: levels,
      daily: DailyRecord.fromJson(json['daily']),
      stats: LifetimeStats.fromJson(json['stats']),
      achievements: ach,
      missions: MissionsState.fromJson(json['missions']),
      seenIntros: {
        if (intros is List)
          for (final i in intros)
            if (i is String) i,
      },
    );
  }
}

/// What a saved game is: its mode, the campaign level or daily date, and
/// for Time Challenge the seconds left.
class GameSpec {
  const GameSpec(this.mode, {this.level = 0, this.date = ''});
  final GameMode mode;
  final int level;
  final String date;

  String get key => switch (mode) {
    GameMode.campaign => 'level-$level',
    GameMode.daily => 'daily-$date',
    _ => mode.name,
  };

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    if (level > 0) 'level': level,
    if (date.isNotEmpty) 'date': date,
  };

  static GameSpec fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid spec');
    final mode = GameMode.values.where((m) => m.name == json['mode']);
    if (mode.isEmpty) throw const FormatException('Invalid mode');
    final level = json['level'];
    final date = json['date'];
    return GameSpec(
      mode.first,
      level: level is int ? level : 0,
      date: date is String ? date : '',
    );
  }
}

/// A game in progress, saved after every move so it survives the app being
/// closed or killed.
class SavedGame {
  const SavedGame({
    required this.spec,
    required this.config,
    required this.state,
    required this.savedAtMillis,
    this.playSeconds = 0,
    this.timeLeftMs = 0,
    this.hintsUsed = 0,
    this.undosUsed = 0,
    this.powerUpsUsed = 0,
    this.continued = false,
  });

  final GameSpec spec;
  final GameConfig config;
  final GameState state;
  final int savedAtMillis;
  final int playSeconds;
  final int timeLeftMs;
  final int hintsUsed;
  final int undosUsed;
  final int powerUpsUsed;
  final bool continued;

  Map<String, Object?> toJson() => {
    'spec': spec.toJson(),
    'config': config.toJson(),
    'state': state.toJson(),
    'savedAt': savedAtMillis,
    'playSeconds': playSeconds,
    'timeLeftMs': timeLeftMs,
    'hints': hintsUsed,
    'undos': undosUsed,
    'powers': powerUpsUsed,
    'continued': continued,
  };

  static SavedGame fromJson(Map<String, Object?> json) {
    int n(String k) {
      final v = json[k];
      return v is int && v >= 0 ? v : 0;
    }

    final saved = SavedGame(
      spec: GameSpec.fromJson(json['spec']),
      config: GameConfig.fromJson(json['config']),
      state: GameState.fromJson(json['state']),
      savedAtMillis: n('savedAt'),
      playSeconds: n('playSeconds'),
      timeLeftMs: n('timeLeftMs'),
      hintsUsed: n('hints'),
      undosUsed: n('undos'),
      powerUpsUsed: n('powers'),
      continued: json['continued'] == true,
    );
    if (saved.spec.mode == GameMode.campaign &&
        (saved.spec.level < 1 || saved.spec.level > LevelCatalog.count)) {
      throw const FormatException('Invalid level');
    }
    return saved;
  }
}

/// Today's Daily Puzzle, cached so it is generated once per day.
class CachedDaily {
  const CachedDaily(this.puzzle);
  final DailyPuzzle puzzle;

  Map<String, Object?> toJson() => {
    'date': puzzle.dateKey,
    'config': puzzle.config.toJson(),
  };

  static CachedDaily fromJson(Map<String, Object?> json) {
    final date = json['date'];
    if (date is! String || DateKey.parse(date) == null) {
      throw const FormatException('Invalid cached daily');
    }
    return CachedDaily(
      DailyPuzzle(date, GameConfig.fromJson(json['config'])),
    );
  }
}

/// Persistent state for advertising frequency caps.
class AdState {
  const AdState({
    this.gamesSinceInterstitial = 0,
    this.lastInterstitialMillis = 0,
    this.gamesCompleted = 0,
  });

  /// Puzzles solved since the last interstitial.
  final int gamesSinceInterstitial;
  final int lastInterstitialMillis;

  /// Puzzles solved in total (for the first-puzzles grace period).
  final int gamesCompleted;

  AdState copyWith({
    int? gamesSinceInterstitial,
    int? lastInterstitialMillis,
    int? gamesCompleted,
  }) => AdState(
    gamesSinceInterstitial:
        gamesSinceInterstitial ?? this.gamesSinceInterstitial,
    lastInterstitialMillis:
        lastInterstitialMillis ?? this.lastInterstitialMillis,
    gamesCompleted: gamesCompleted ?? this.gamesCompleted,
  );

  Map<String, Object?> toJson() => {
    'gamesSince': gamesSinceInterstitial,
    'lastShown': lastInterstitialMillis,
    'completed': gamesCompleted,
  };

  static AdState fromJson(Map<String, Object?> json) {
    int n(String k) {
      final v = json[k];
      return v is int && v >= 0 ? v : 0;
    }

    return AdState(
      gamesSinceInterstitial: n('gamesSince'),
      lastInterstitialMillis: n('lastShown'),
      gamesCompleted: n('completed'),
    );
  }
}
