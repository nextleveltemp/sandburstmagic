
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/engine.dart';
import '../../core/sand.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../game/board_fx.dart';
import '../game/sand_painter.dart';
import '../theme/tokens.dart';
import '../widgets/game_widgets.dart';
import 'home_screen.dart';

/// How to play: four short pages, each with a live demo board that plays
/// itself with the real rules.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.firstRun});

  final bool firstRun;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  static const pages = 4;
  int _page = 0;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  late GameConfig _cfg;
  late GameState _state;
  late BoardFx _fx;
  double _wait = 0;

  @override
  void initState() {
    super.initState();
    _reset();
    _ticker = createTicker(_tick)..start();
  }

  void _reset() {
    _cfg = GameConfig(
      seed: 4 + _page,
      layout: _page >= 2 ? layoutText(makeLayout(11 + _page, 3, density: 92)) : null,
      weights: gentleWeights,
      palette: const [6, 9, 2, 7, 0, 1],
    );
    _state = newGame(_cfg);
    _fx = BoardFx(_state.board);
    _wait = 600;
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    if (dt <= 0 || dt > 250) return;
    _fx.tick(dt);
    if (_fx.busy) return;
    _wait -= dt;
    if (_wait > 0) return;
    _wait = 900;
    if (!_state.isPlaying || _state.moves > 14) {
      _fx.dispose();
      _reset();
      setState(() {});
      return;
    }
    final m = bestMove(_state, _cfg);
    if (m == null) return;
    final turn = place(_state, _cfg, m.$1, m.$2, m.$3);
    if (turn != null) _fx.play(turn, _state.board);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fx.dispose();
    super.dispose();
  }

  void _finish() {
    final services = AppScope.read(context);
    services.settings.update((s) => s.copyWith(tutorialSeen: true));
    if (widget.firstRun) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_page == pages - 1) {
      _finish();
      return;
    }
    setState(() {
      _page++;
      _fx.dispose();
      _reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final look = lookOf(AppScope.of(context));
    return Scaffold(
      body: ThemedBackground(
        theme: look.board,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      s.tutorialProgress(_page + 1, pages),
                      style: TextStyle(color: pal.textMuted),
                    ),
                    const Spacer(),
                    TextButton(
                      key: const ValueKey('tutorial-skip'),
                      onPressed: _finish,
                      child: Text(s.skip),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Text(
                  s.tutorialTitle(_page),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  s.tutorialBody(_page),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: Space.lg),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CustomPaint(
                        painter: SandBoardPainter(
                          fx: _fx,
                          look: look,
                          overlay: BoardOverlay.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('tutorial-next'),
                    onPressed: _next,
                    child: Text(_page == pages - 1 ? s.startPlaying : s.next),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

