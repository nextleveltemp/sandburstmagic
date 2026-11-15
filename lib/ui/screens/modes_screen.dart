import 'package:flutter/material.dart';

import '../../core/levels.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../../state/launcher.dart';
import '../theme/tokens.dart';
import '../widgets/game_widgets.dart';
import 'home_screen.dart';

/// Classic, Time Challenge, Limited Moves and Endless Sand.
class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  static const modes = [
    GameMode.classic,
    GameMode.time,
    GameMode.moves,
    GameMode.endless,
  ];

  static IconData icon(GameMode m) => switch (m) {
    GameMode.time => Icons.timer_rounded,
    GameMode.moves => Icons.grid_view_rounded,
    GameMode.endless => Icons.all_inclusive_rounded,
    _ => Icons.play_arrow_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final services = AppScope.of(context);
    final pal = AppPalette.of(context);
    final look = lookOf(services);
    return ListenableBuilder(
      listenable: Listenable.merge([services.progress, services.saves]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(s.modes),
          backgroundColor: Colors.transparent,
        ),
        extendBodyBehindAppBar: true,
        body: ThemedBackground(
          theme: look.board,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                for (final m in modes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Material(
                      color: pal.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: InkWell(
                        key: ValueKey('mode-${m.name}'),
                        borderRadius: BorderRadius.circular(Radii.lg),
                        onTap: () =>
                            openGame(context, Launcher.mode(services, m)),
                        child: Padding(
                          padding: const EdgeInsets.all(Space.lg),
                          child: Row(
                            children: [
                              Icon(icon(m), size: 36, color: pal.gold),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.modeName(m),
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.modeBlurb(m),
                                      style: TextStyle(color: pal.textMuted),
                                    ),
                                    if (m == GameMode.moves)
                                      Text(
                                        s.movesTarget(
                                          Modes.movesTarget(
                                            services.progress.stats.movesWins,
                                          ),
                                        ),
                                        style: TextStyle(color: pal.cyan),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.bestScore(
                                        services.progress.stats.best(m),
                                      ),
                                      style: TextStyle(
                                        color: pal.gold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (Launcher.hasSaved(services, m))
                                Text(
                                  s.continueGame,
                                  style: TextStyle(
                                    color: pal.cyan,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
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
