import 'dart:math';

import '../core/levels.dart';
import '../data/models.dart';
import 'app_services.dart';
import 'game_controller.dart';

/// Creates the controller for a game, resuming the saved one when there
/// is one for exactly that game.
abstract final class Launcher {
  static int _seed() => Random().nextInt(0x7FFFFFFF);

  /// Whether [mode] has a game in progress (for "Continue" labels).
  static bool hasSaved(AppServices s, GameMode mode) => s.saves.has(mode);

  /// Classic, Time Challenge, Limited Moves or Endless Sand. [fresh]
  /// discards a saved game of that mode.
  static GameController mode(AppServices s, GameMode m, {bool fresh = false}) {
    final saved = s.saves.get(m);
    if (!fresh && saved != null) return GameController.resume(s, saved);
    final seed = _seed();
    final config = switch (m) {
      GameMode.time => Modes.time(seed),
      GameMode.moves => Modes.moves(
        seed,
        Modes.movesTarget(s.progress.stats.movesWins),
      ),
      GameMode.endless => Modes.endless(seed),
      _ => Modes.classic(seed),
    };
    return GameController.start(s, GameSpec(m), config);
  }

  /// Campaign level [number]; null if it is locked.
  static GameController? level(
    AppServices s,
    int number, {
    bool fresh = false,
  }) {
    if (number < 1 ||
        number > LevelCatalog.count ||
        !s.progress.isLevelUnlocked(number)) {
      return null;
    }
    final saved = s.saves.get(GameMode.campaign);
    if (!fresh && saved != null && saved.spec.level == number) {
      return GameController.resume(s, saved);
    }
    final def = LevelCatalog.level(number);
    return GameController.start(
      s,
      GameSpec(GameMode.campaign, level: number),
      def.config(),
    );
  }

  /// Today's Daily Puzzle (generated in the background the first time).
  static Future<GameController> daily(AppServices s) async {
    final today = s.progress.today;
    final saved = s.saves.get(GameMode.daily);
    if (saved != null && saved.spec.date == today) {
      return GameController.resume(s, saved);
    }
    final puzzle = await s.daily.forDate(today);
    return GameController.start(
      s,
      GameSpec(GameMode.daily, date: today),
      puzzle.config,
    );
  }
}
