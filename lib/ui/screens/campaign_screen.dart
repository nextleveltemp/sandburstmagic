import 'package:flutter/material.dart';

import '../../core/levels.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../../state/launcher.dart';
import '../theme/sand_theme.dart';
import '../theme/tokens.dart';
import '../widgets/game_widgets.dart';
import 'home_screen.dart';

/// The six worlds and their 100 levels.
class CampaignScreen extends StatelessWidget {
  const CampaignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.progress,
      builder: (context, _) {
        final p = services.progress;
        final next = p.unlockedLevel;
        return Scaffold(
          appBar: AppBar(
            title: Text(s.campaign),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: Space.md),
                child: Center(child: CoinPill(coins: p.coins)),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              for (final w in worlds) ...[
                SliverToBoxAdapter(
                  child: _WorldHeader(world: w, unlocked: next >= w.first),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.sm,
                  ),
                  sliver: SliverGrid.count(
                    crossAxisCount: 5,
                    mainAxisSpacing: Space.sm,
                    crossAxisSpacing: Space.sm,
                    children: [
                      for (var n = w.first; n <= w.last; n++)
                        _LevelCell(
                          number: n,
                          unlocked: n <= next,
                          current: n == next,
                          stars: p.record(n)?.stars ?? 0,
                          theme: BoardTheme.byId(w.id),
                          onTap: () {
                            final c = Launcher.level(services, n);
                            if (c != null) openGame(context, c);
                          },
                        ),
                    ],
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
            ],
          ),
        );
      },
    );
  }
}

class _WorldHeader extends StatelessWidget {
  const _WorldHeader({required this.world, required this.unlocked});

  final World world;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = BoardTheme.byId(world.id);
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(colors: [theme.top, theme.bottom]),
        border: Border.all(color: theme.accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.worldN(world.number).toUpperCase(),
                  style: TextStyle(
                    color: theme.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
                Text(
                  s.worldName(world.id),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!unlocked)
                  Text(
                    s.worldLocked(world.first),
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          Icon(
            unlocked ? Icons.landscape_rounded : Icons.lock_rounded,
            color: Colors.white70,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({
    required this.number,
    required this.unlocked,
    required this.current,
    required this.stars,
    required this.theme,
    required this.onTap,
  });

  final int number;
  final bool unlocked;
  final bool current;
  final int stars;
  final BoardTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    return Semantics(
      button: unlocked,
      label: s.levelCellLabel(number, unlocked, current, stars),
      child: ExcludeSemantics(
        child: Material(
          key: ValueKey('level-$number'),
          color: unlocked ? theme.cell : pal.surface.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: current
                ? BorderSide(color: theme.accent, width: 2.5)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: unlocked ? onTap : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (unlocked)
                  Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                else
                  Icon(Icons.lock_rounded, color: pal.textMuted, size: 18),
                if (unlocked)
                  Text(
                    '★' * stars + '☆' * (3 - stars),
                    style: TextStyle(color: pal.gold, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
