import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/engine.dart';
import '../core/levels.dart';
import '../core/sand.dart';
import '../data/models.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import 'app_services.dart';
import 'progress_controller.dart';

/// Runs one game: placements, power-ups, hints, undo, the Time Challenge
/// clock, "keep playing" and the results. The rules live in core/engine;
/// this class adds the session around them and saves after every move.
class GameController extends ChangeNotifier {
  GameController._(
    this.services,
    this.spec,
    this.config,
    this.state, {
    this.hintsUsed = 0,
    this.undosUsed = 0,
    this.powerUpsUsed = 0,
    this.continued = false,
    int timeLeftMs = 0,
    int playSeconds = 0,
  }) : _timeLeftMs = timeLeftMs,
       _playSeconds = playSeconds;

  factory GameController.start(
    AppServices s,
    GameSpec spec,
    GameConfig config,
  ) {
    final c = GameController._(
      s,
      spec,
      config,
      newGame(config),
      timeLeftMs: spec.mode == GameMode.time ? Modes.timeSeconds * 1000 : 0,
    );
    c._save();
    return c;
  }

  factory GameController.resume(AppServices s, SavedGame saved) =>
      GameController._(
        s,
        saved.spec,
        saved.config,
        saved.state,
        hintsUsed: saved.hintsUsed,
        undosUsed: saved.undosUsed,
        powerUpsUsed: saved.powerUpsUsed,
        continued: saved.continued,
        timeLeftMs: saved.timeLeftMs,
        playSeconds: saved.playSeconds,
      );

  /// Free hints and undos per game; more with a rewarded ad.
  static const int freeHints = 1;
  static const int freeUndos = 1;

  final AppServices services;
  final GameSpec spec;
  final GameConfig config;
  GameState state;

  int hintsUsed;
  int undosUsed;
  int powerUpsUsed;
  bool continued;
  int _timeLeftMs;
  int _playSeconds;
  int _msCarry = 0;

  GameState? _before;

  /// The last turn, for the animation; [turnSerial] changes with each.
  Turn? lastTurn;
  int turnSerial = 0;

  /// The bot's suggestion being shown.
  Move? hint;

  GameReport? report;
  bool rewardDoubled = false;
  bool _disposed = false;

  ProgressController get progress => services.progress;
  GameMode get mode => spec.mode;
  bool get isCampaign => mode == GameMode.campaign;
  LevelDef? get level => isCampaign ? LevelCatalog.level(spec.level) : null;
  bool get finished => report != null;
  int get timeLeftMs => _timeLeftMs;
  bool get timed => mode == GameMode.time;

  bool get canUndo => _before != null && state.isPlaying;
  bool get undoIsFree => undosUsed < freeUndos;
  bool get hintIsFree => hintsUsed < freeHints;
  bool get powerUpsAllowed => config.allowPowerUps;

  int get movesLeft => config.moveLimit > 0
      ? config.moveLimit + state.bonusMoves - state.moves
      : -1;

  /// The game ended for lack of room and the player may watch an ad to
  /// keep playing (once per game).
  bool get offerContinue =>
      !finished &&
      !continued &&
      state.status == Status.lost &&
      state.reason == 'space' &&
      services.ads.canShowAds;

  /// The game is over and waits for the results to be recorded.
  bool get readyToFinish => !state.isPlaying && !finished && !offerContinue;

  // ------------------------------------------------------------ moves

  /// Places the piece in tray [slot] (3: bonus piece) at (row, col).
  bool placePiece(int slot, int row, int col) {
    if (finished || !state.isPlaying) return false;
    final before = state.copy();
    final turn = place(state, config, slot, row, col);
    if (turn == null) {
      services.audio.play(Sfx.invalid);
      services.haptics.fire(Haptic.invalid);
      return false;
    }
    _before = before;
    hint = null;
    progress.recordPiece();
    if (timed && turn.rows > 0) {
      _timeLeftMs += turn.rows * Modes.timePerRow * 1000;
    }
    _afterTurn(turn, Sfx.place);
    return true;
  }

  void _afterTurn(Turn turn, Sfx sound) {
    lastTurn = turn;
    turnSerial++;
    services.audio.play(sound);
    if (turn.rows > 0) {
      final big = turn.biggestWave >= 2 || state.combo >= 3;
      services.audio.play(big ? Sfx.combo : Sfx.burst);
      services.haptics.fire(big ? Haptic.win : Haptic.row);
    } else {
      services.haptics.fire(Haptic.place);
    }
    _save();
    _checkEnd();
    notifyListeners();
  }

  /// Whether [p] can be used now (inventory, level rules).
  bool canUsePowerUp(PowerUp p) =>
      state.isPlaying && !finished && powerUpsAllowed && progress.count(p) > 0;

  /// Uses [p] at [arg] from the inventory. [free]: earned with a rewarded
  /// ad, not taken from the inventory.
  bool usePowerUp(PowerUp p, int? arg, {bool free = false}) {
    if (!state.isPlaying || finished || !powerUpsAllowed) return false;
    if (!free && progress.count(p) <= 0) return false;
    final before = state.copy();
    final turn = power(state, config, p, arg);
    if (turn == null) {
      services.audio.play(Sfx.invalid);
      return false;
    }
    if (!free) progress.consumePowerUp(p);
    powerUpsUsed++;
    _before = before;
    hint = null;
    if (timed && turn.rows > 0) {
      _timeLeftMs += turn.rows * Modes.timePerRow * 1000;
    }
    _afterTurn(turn, Sfx.power);
    return true;
  }

  /// Shows the bot's move. [paid]: unlocked by a rewarded ad.
  Future<bool> showHint({bool paid = false}) async {
    if (!state.isPlaying || finished) return false;
    if (!hintIsFree && !paid) return false;
    final m = await services.worker.hint(config, state.copy());
    if (_disposed || m == null) return false;
    hint = m;
    hintsUsed++;
    progress.recordHint();
    services.audio.play(Sfx.hint);
    _save();
    notifyListeners();
    return true;
  }

  /// Takes back the last move. [paid]: unlocked by a rewarded ad.
  bool undo({bool paid = false}) {
    final prev = _before;
    if (prev == null || !state.isPlaying || finished) return false;
    if (!undoIsFree && !paid) return false;
    state = prev;
    _before = null;
    undosUsed++;
    hint = null;
    lastTurn = null;
    turnSerial++;
    progress.recordUndo();
    services.audio.play(Sfx.undo);
    _save();
    notifyListeners();
    return true;
  }

  /// After a rewarded ad: clears the bottom three rows and deals new pieces.
  bool keepPlaying() {
    if (!offerContinue) return false;
    final turn = continueGame(state, config);
    if (turn == null) return false;
    continued = true;
    _before = null;
    _afterTurn(turn, Sfx.power);
    return true;
  }

  /// The player declined to continue: record the result.
  void declineContinue() {
    if (finished || state.isPlaying) return;
    continued = true;
    _finish();
  }

  /// Advances the Time Challenge clock and the play-time counter.
  void tick(int ms) {
    if (finished || !state.isPlaying) return;
    _msCarry += ms;
    while (_msCarry >= 1000) {
      _msCarry -= 1000;
      _playSeconds++;
      progress.addPlaySeconds(1);
    }
    if (!timed) return;
    _timeLeftMs -= ms;
    if (_timeLeftMs <= 0) {
      _timeLeftMs = 0;
      endForTime(state);
      services.audio.play(Sfx.over);
      _checkEnd();
    }
    notifyListeners();
  }

  void _checkEnd() {
    if (state.isPlaying || finished) return;
    if (offerContinue) {
      services.audio.play(Sfx.over);
      return;
    }
    _finish();
  }

  void _finish() {
    if (finished) return;
    report = progress.recordGame(spec: spec, state: state);
    unawaited(services.saves.deleteIfFor(mode, spec.key));
    services.ads.onGameFinished();
    final won = state.status == Status.won;
    if (won) {
      services.audio.play(Sfx.win);
      services.haptics.fire(Haptic.win);
    } else if (state.reason != 'time') {
      services.audio.play(Sfx.over);
    }
    final r = report!;
    if (r.achievements.isNotEmpty) services.audio.play(Sfx.achievement);
    final happy =
        (won && (r.stars == 3 || mode == GameMode.daily)) || r.newBest;
    unawaited(
      services.review.maybeAsk(
        happyMoment: happy,
        puzzlesSolved: progress.stats.gamesPlayed,
      ),
    );
    unawaited(services.syncReminders());
    notifyListeners();
  }

  /// After a rewarded ad on the results: the game's coins once more.
  bool doubleReward() {
    final r = report;
    if (r == null || rewardDoubled || r.coins <= 0) return false;
    rewardDoubled = true;
    progress.addCoins(r.coins);
    notifyListeners();
    return true;
  }

  /// The game's result for sharing.
  String get shareLine => switch (mode) {
    GameMode.campaign => 'level ${spec.level}',
    GameMode.daily => 'daily ${spec.date}',
    _ => mode.name,
  };

  void _save() {
    if (!state.isPlaying) return;
    unawaited(
      services.saves.save(
        SavedGame(
          spec: spec,
          config: config,
          state: state,
          savedAtMillis: DateTime.now().millisecondsSinceEpoch,
          playSeconds: _playSeconds,
          timeLeftMs: _timeLeftMs,
          hintsUsed: hintsUsed,
          undosUsed: undosUsed,
          powerUpsUsed: powerUpsUsed,
          continued: continued,
        ),
      ),
    );
  }

  /// Saves now (the screen is closing or the app goes to the background).
  void saveNow() {
    _save();
    unawaited(progress.flush());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Board helpers shared by the UI.
extension BoardQueries on GameState {
  bool fits(int slot, int row, int col) {
    final p = slot == 3 ? bonus : tray[slot];
    return p != null && canPlace(board, p.shape, row, col);
  }
}
