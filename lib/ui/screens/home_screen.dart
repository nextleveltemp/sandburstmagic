import 'package:flutter/material.dart';

import '../../core/levels.dart';
import '../../l10n/strings.dart';
import '../../services/audio_service.dart';
import '../../state/app_services.dart';
import '../../state/game_controller.dart';
import '../../state/launcher.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/game_widgets.dart';
import 'campaign_screen.dart';
import 'daily_sheet.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';

/// Opens [c] on the game screen.
Future<void> openGame(BuildContext context, GameController c) =>
    Navigator.of(context).push(
      FadeScaleRoute<void>(builder: (_) => GameScreen(controller: c)),
    );

/// The home screen, laid out like Block Burst Magic and Water Sort Magic:
/// player card (opens Statistics), Themes and Settings; the wordmark; Play
/// (or Continue) with Levels under it; today's goals; more ways to play.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(FadeScaleRoute<void>(builder: (_) => screen));

  void _click(BuildContext context) =>
      AppScope.read(context).audio.play(Sfx.button);

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final s = Strings.of(context);
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([
          services.progress,
          services.saves,
          services.settings,
        ]),
        builder: (context, _) {
          final p = services.progress;
          final next = p.unlockedLevel;
          final world = worldOf(next);
          final saved = services.saves.get(GameMode.classic);
          final dailyDone = p.dailyDoneToday;
          final streak = p.streak;
          final chevron = Icon(
            Icons.chevron_right_rounded,
            color: palette.textMuted,
          );

          Widget mode(GameMode m, IconData icon, Color colour) => Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: ActionTile(
              key: ValueKey('mode-${m.name}'),
              title: s.modeName(m),
              subtitle: Launcher.hasSaved(services, m)
                  ? s.continueGame
                  : '${s.modeBlurb(m)} ${s.bestScore(p.stats.best(m))}',
              leading: Icon(icon, color: colour, size: 30),
              trailing: chevron,
              onTap: () {
                _click(context);
                openGame(context, Launcher.mode(services, m));
              },
            ),
          );

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.lg,
                Space.xl,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Semantics(
                          button: true,
                          label:
                              '${s.statistics}. ${s.playerCard(next, s.worldName(world.id))}. '
                              '${s.playerCardSub(p.totalStars, p.coins)}',
                          child: InkWell(
                            key: const ValueKey('home-stats'),
                            borderRadius: BorderRadius.circular(Radii.md),
                            onTap: () => _push(context, const StatsScreen()),
                            child: ExcludeSemantics(
                              child: Padding(
                                padding: const EdgeInsets.all(Space.xs),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LevelBadge(
                                      level: next,
                                      progress:
                                          p.totalStars /
                                          (LevelCatalog.count * 3),
                                    ),
                                    const SizedBox(width: Space.sm),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.playerCard(
                                              next,
                                              s.worldName(world.id),
                                            ),
                                            style: theme.textTheme.titleSmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            s.playerCardSub(
                                              p.totalStars,
                                              p.coins,
                                            ),
                                            style: theme.textTheme.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    RoundIconButton(
                      key: const ValueKey('home-themes'),
                      icon: Icons.palette_outlined,
                      tooltip: s.themes,
                      onPressed: () =>
                          _push(context, const ShopScreen(initialTab: 1)),
                    ),
                    const SizedBox(width: Space.sm),
                    RoundIconButton(
                      key: const ValueKey('home-settings'),
                      icon: Icons.settings_outlined,
                      tooltip: s.settings,
                      onPressed: () => _push(context, const SettingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xxl),
                Center(child: Wordmark(height: 40, subtitle: s.byStudio)),
                const SizedBox(height: Space.xxl),
                FilledButton(
                  key: const ValueKey('play-classic'),
                  onPressed: () {
                    _click(context);
                    openGame(
                      context,
                      Launcher.mode(services, GameMode.classic),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                  ),
                  child: Semantics(
                    label: saved != null
                        ? '${s.continueGame}. ${s.continueSubtitle(saved.state.score)}'
                        : '${s.play}. ${s.modeName(GameMode.classic)}',
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 32),
                          const SizedBox(width: Space.sm),
                          // The words sit in the exact centre: an empty
                          // space on the right balances the icon.
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  saved != null ? s.continueGame : s.play,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                Text(
                                  saved != null
                                      ? s.continueSubtitle(saved.state.score)
                                      : s.modeName(GameMode.classic),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32 + Space.sm),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                // The 100 campaign levels, one tap from the top.
                OutlinedButton.icon(
                  key: const ValueKey('home-levels'),
                  onPressed: () {
                    _click(context);
                    _push(context, const CampaignScreen());
                  },
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text(s.levels),
                ),
                const SizedBox(height: Space.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: palette.gold,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${s.modeName(GameMode.classic)}: '
                        '${s.bestScore(p.stats.best(GameMode.classic))}',
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Icon(Icons.star_rounded, size: 18, color: palette.gold),
                    const SizedBox(width: 2),
                    Text(
                      s.starsTotal(p.totalStars),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                if (services.settings.value.showDailyGoals) ...[
                  SectionTitle(s.missions),
                  _GoalsCard(services: services),
                ],
                SectionTitle(s.modesHeading),
                ActionTile(
                  key: const ValueKey('home-daily'),
                  title: s.daily,
                  subtitle: dailyDone
                      ? (streak > 0
                            ? '${s.dailyBlurbDone}. ${s.dailyStreak(streak)}'
                            : s.dailyBlurbDone)
                      : (streak > 0
                            ? '${s.dailyBlurbNew}. ${s.dailyStreak(streak)}'
                            : s.dailyBlurbNew),
                  leading: Icon(
                    Icons.calendar_today_rounded,
                    color: palette.gold,
                    size: 28,
                  ),
                  trailing: dailyDone
                      ? Icon(Icons.check_circle_rounded, color: palette.cyan)
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: palette.violet,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () {
                    _click(context);
                    showDailySheet(context);
                  },
                ),
                mode(GameMode.time, Icons.timer_rounded, palette.cyan),
                mode(
                  GameMode.moves,
                  Icons.grid_view_rounded,
                  const Color(0xFFFF8A1F),
                ),
                mode(
                  GameMode.endless,
                  Icons.all_inclusive_rounded,
                  palette.violet,
                ),
                const SizedBox(height: Space.sm),
                ActionTile(
                  key: const ValueKey('home-shop'),
                  title: s.shop,
                  subtitle: s.shopBlurb(p.coins),
                  leading: const CoinIcon(size: 28),
                  trailing: chevron,
                  onTap: () {
                    _click(context);
                    _push(context, const ShopScreen());
                  },
                ),
                if (!p.rewardsAllowed) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    s.dailyPaused,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.danger,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Today's three goals with progress bars (as in Block Burst Magic).
class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final m = services.progress.missions;
    final allDone = m.missions.every(m.isDone);
    return Container(
      key: const ValueKey('home-goals'),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: palette.stroke.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allDone ? s.missionsAllDone : s.missionsHint,
            style: theme.textTheme.bodySmall,
          ),
          for (final g in m.missions) ...[
            const SizedBox(height: Space.md),
            _GoalRow(
              text: s.missionText(g),
              value: m.valueOf(g),
              target: g.target,
              done: m.isDone(g),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.text,
    required this.value,
    required this.target,
    required this.done,
  });

  final String text;
  final int value;
  final int target;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final shown = value > target ? target : value;
    return Semantics(
      label: '$text: $shown / $target${done ? ', done' : ''}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: done ? palette.cyan : palette.textMuted,
              size: 22,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: target == 0 ? 0 : shown / target,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Text('$shown/$target', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
