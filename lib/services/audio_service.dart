import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound effects used by the game. Each maps to `assets/audio/sfx/<name>.ogg`.
enum Sfx {
  /// A piece is picked up from the tray.
  select,

  /// A piece is placed on the board.
  place,

  /// Sand pours and settles.
  sand,

  /// A placement is not possible.
  invalid,

  /// A row is complete and bursts.
  burst,

  /// Two or more rows at once, or a combo.
  combo,

  /// A power-up is used.
  power,

  /// A level or daily puzzle is won.
  win,

  /// A game ends (no room, no moves or time up).
  over,

  /// The last move is taken back.
  undo,

  /// A hint is shown.
  hint,

  /// Menu buttons.
  button,

  /// An achievement unlocks or coins are earned.
  achievement,
}

/// Music loops: menus and gameplay.
enum MusicTrack { main, relax }

/// Audio interface. The game never depends on audio succeeding: every
/// method is fire-and-forget and failures are swallowed.
abstract class AudioService {
  Future<void> init();
  void play(Sfx sfx);
  void playMusic(MusicTrack track);
  void stopMusic();
  void pauseForBackground();
  void resumeFromBackground();
  void applySettings({
    required bool sfx,
    required bool music,
    required double volume,
  });
  Future<void> dispose();
}

/// Used in tests and if the audio plugin is unavailable.
class SilentAudioService implements AudioService {
  final List<Sfx> played = [];
  MusicTrack? currentTrack;

  @override
  Future<void> init() async {}

  @override
  void play(Sfx sfx) => played.add(sfx);

  @override
  void playMusic(MusicTrack track) => currentTrack = track;

  @override
  void stopMusic() => currentTrack = null;

  @override
  void pauseForBackground() {}

  @override
  void resumeFromBackground() {}

  @override
  void applySettings({
    required bool sfx,
    required bool music,
    required double volume,
  }) {}

  @override
  Future<void> dispose() async {}
}

/// Implementation on top of `audioplayers`.
///
/// Effects use small round-robin pools of low-latency players so rapid
/// repeats (several clears in a row) never cut each other off. Effects mix
/// with other apps' audio instead of stealing audio focus, so a player's own
/// music keeps playing.
class PluginAudioService implements AudioService {
  static const _voices = 3;
  static const _musicGain = 0.45;

  final Map<Sfx, List<AudioPlayer>> _pools = {};
  final Map<Sfx, int> _next = {};
  AudioPlayer? _music;
  MusicTrack? _wantedTrack;
  MusicTrack? _loadedTrack;
  bool _sfxOn = true;
  bool _musicOn = true;
  double _volume = 0.8;
  bool _ready = false;
  bool _disabled = false;
  bool _backgrounded = false;
  int _effectsStarted = 0;
  int _failures = 0;

  /// Diagnostics for on-device tests (read-only).
  bool get isReady => _ready;
  bool get isDisabled => _disabled;
  int get effectsStarted => _effectsStarted;
  int get failures => _failures;
  bool get sfxEnabled => _sfxOn;
  bool get musicEnabled => _musicOn;
  MusicTrack? get loadedTrack => _loadedTrack;
  PlayerState? get musicState => _music?.state;
  Future<Duration?> musicPosition() async {
    try {
      return await _music?.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  static double _sfxGain(Sfx s) => switch (s) {
    Sfx.button => 0.45,
    Sfx.select => 0.5,
    Sfx.place => 0.6,
    Sfx.sand => 0.4,
    Sfx.invalid => 0.5,
    Sfx.undo => 0.5,
    Sfx.hint => 0.6,
    _ => 0.85,
  };

  @override
  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      for (final s in Sfx.values) {
        final players = <AudioPlayer>[];
        for (var i = 0; i < _voices; i++) {
          // Stop loading if the service was disposed meanwhile.
          if (_isDisposed) {
            for (final p in players) {
              await p.dispose();
            }
            return;
          }
          final p = AudioPlayer();
          players.add(p);
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('audio/sfx/${s.name}.ogg'));
        }
        if (_isDisposed) {
          for (final p in players) {
            await p.dispose();
          }
          return;
        }
        _pools[s] = players;
        _next[s] = 0;
      }
      if (_isDisposed) return;
      _ready = true;
      final wanted = _wantedTrack;
      if (wanted != null) playMusic(wanted);
    } catch (e) {
      // Missing assets or an unsupported platform: continue silently.
      debugPrint('Audio disabled: $e');
      _disabled = true;
    }
  }

  @override
  void play(Sfx sfx) {
    if (!_ready || _disabled || !_sfxOn || _volume <= 0) return;
    final pool = _pools[sfx];
    if (pool == null || pool.isEmpty) return;
    final i = _next[sfx] ?? 0;
    _next[sfx] = (i + 1) % pool.length;
    final player = pool[i];
    unawaited(_restart(player, _volume * _sfxGain(sfx)));
  }

  Future<void> _restart(AudioPlayer p, double volume) async {
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
      _effectsStarted++;
    } catch (e) {
      _failures++;
      debugPrint('Sfx failed: $e');
    }
  }

  @override
  void playMusic(MusicTrack track) {
    _wantedTrack = track;
    if (!_ready || _disabled) return;
    unawaited(_syncMusic());
  }

  @override
  void stopMusic() {
    _wantedTrack = null;
    unawaited(_syncMusic());
  }

  Future<void> _musicOps = Future<void>.value();
  bool _isDisposed = false;

  /// Brings the music player in line with the wanted track and settings.
  /// Calls are queued so a quick play/stop sequence (e.g. switching music
  /// off while it is still loading) can never interleave and leave the
  /// player in the wrong state.
  Future<void> _syncMusic() {
    final op = _musicOps.then((_) => _applyMusic());
    _musicOps = op;
    return op;
  }

  Future<void> _applyMusic() async {
    if (_isDisposed) return;
    try {
      final wanted = _wantedTrack;
      final shouldPlay =
          wanted != null && _musicOn && _volume > 0 && !_backgrounded;
      if (!shouldPlay) {
        await _music?.pause();
        return;
      }
      final player = _music ??= AudioPlayer();
      if (_loadedTrack != wanted) {
        await player.stop();
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setSource(AssetSource('audio/music/${wanted.name}.ogg'));
        _loadedTrack = wanted;
      }
      await player.setVolume(_volume * _musicGain);
      await player.resume();
    } catch (e) {
      _failures++;
      debugPrint('Music failed: $e');
    }
  }

  @override
  void pauseForBackground() {
    _backgrounded = true;
    unawaited(_syncMusic());
  }

  @override
  void resumeFromBackground() {
    _backgrounded = false;
    unawaited(_syncMusic());
  }

  @override
  void applySettings({
    required bool sfx,
    required bool music,
    required double volume,
  }) {
    _sfxOn = sfx;
    _musicOn = music;
    _volume = volume < 0 ? 0.0 : (volume > 1 ? 1.0 : volume);
    if (_ready) unawaited(_syncMusic());
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _ready = false;
    await _musicOps;
    // Copy first: loading may still be adding pools while we await below.
    final pools = List.of(_pools.values);
    _pools.clear();
    for (final pool in pools) {
      for (final p in pool) {
        await p.dispose();
      }
    }
    await _music?.dispose();
    _music = null;
  }
}
