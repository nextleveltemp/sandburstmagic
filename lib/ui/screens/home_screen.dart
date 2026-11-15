import 'dart:async';

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
import 'modes_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';

/// Opens [c] on the game screen.
Future<void> openGame(BuildContext context, GameController c) => Navigator.of(
  context,
).push(FadeScaleRoute<void>(builder: (_) => GameScreen(controller: c)));

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        services.progress,
        services.saves,
        services.settings,
      ]),
      builder: (context, _) => _HomeBody(services: services),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.services});

  final AppServices services;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(FadeScaleRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final p = services.progress;
    final look = lookOf(services);
    final next = p.unlockedLevel;
    final world = worldOf(next);
    final classicSaved = Launcher.hasSaved(services, GameMode.classic);
    final missions = p.missions;
    return Scaffold(
      body: ThemedBackground(
        theme: look.board,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.xl,
            ),
            children: [
              Row(
                children: [
                  CoinPill(
                    key: const ValueKey('home-coins'),
                    coins: p.coins,
                    onTap: () => _push(context, const ShopScreen()),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    key: const ValueKey('home-stats'),
                    icon: Icons.bar_chart_rounded,
                    tooltip: s.statistics,
                    onPressed: () => _push(context, const StatsScreen()),
                  ),
                  const SizedBox(width: Space.sm),
                  RoundIconButton(
                    key: const ValueKey('home-settings'),
                    icon: Icons.settings_rounded,
                    tooltip: s.settings,
                    onPressed: () => _push(context, const SettingsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              const Center(child: Wordmark(height: 46)),
              const SizedBox(height: Space.xl),
              _BigPlay(
                key: const ValueKey('play-classic'),
                label: classicSaved ? s.continueGame : s.play,
                sub:
                    '${s.modeName(GameMode.classic)} · '
                    '${s.bestScore(p.stats.best(GameMode.classic))}',
                onTap: () => openGame(
                  context,
                  Launcher.mode(services, GameMode.classic),
                ),
              ),
              const SizedBox(height: Space.md),
              _Card(
                key: const ValueKey('home-campaign'),
                icon: Icons.map_rounded,
                colour: pal.violet,
                title: s.campaign,
                subtitle:
                    '${s.levelN(next)} · ${s.worldName(world.id)} · ${s.starsTotal(p.totalStars)}',
                onTap: () => _push(context, const CampaignScreen()),
              ),
              _Card(
                key: const ValueKey('home-daily'),
                icon: Icons.calendar_today_rounded,
                colour: pal.cyan,
                title: s.daily,
                subtitle:
                    '${p.dailyDoneToday ? s.dailyBlurbDone : s.dailyBlurbNew} · ${s.dailyStreak(p.streak)}',
                onTap: () => showDailySheet(context),
              ),
              _Card(
                key: const ValueKey('home-modes'),
                icon: Icons.sports_esports_rounded,
                colour: const Color(0xFFFF8A1F),
                title: s.modes,
                subtitle:
                    '${s.modeName(GameMode.time)} · ${s.modeName(GameMode.moves)} · ${s.modeName(GameMode.endless)}',
                onTap: () => _push(context, const ModesScreen()),
              ),
              Row(
                children: [
                  Expanded(
                    child: _Card(
                      key: const ValueKey('home-shop'),
                      icon: Icons.storefront_rounded,
                      colour: pal.gold,
                      title: s.shop,
                      onTap: () => _push(context, const ShopScreen()),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _Card(
                      key: const ValueKey('home-themes'),
                      icon: Icons.palette_rounded,
                      colour: const Color(0xFFFF6FC8),
                      title: s.themes,
                      onTap: () =>
                          _push(context, const ShopScreen(initialTab: 1)),
                    ),
                  ),
                ],
              ),
              if (services.settings.value.showDailyGoals) ...[
                const SizedBox(height: Space.md),
                Material(
                  color: pal.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.missions,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: Space.xs),
                        if (!p.rewardsAllowed)
                          Text(
                            s.dailyPaused,
                            style: TextStyle(color: pal.danger),
                          ),
                        for (final m in missions.missions)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  missions.isDone(m)
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: missions.isDone(m)
                                      ? const Color(0xFF2ECC71)
                                      : pal.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: Space.sm),
                                Expanded(child: Text(s.missionText(m))),
                                Text(
                                  s.objectiveProgress(
                                    missions.valueOf(m),
                                    m.target,
                                  ),
                                  style: TextStyle(color: pal.textMuted),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: Space.xs),
                        Text(
                          s.missionsHint,
                          style: TextStyle(color: pal.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),
              Center(
                child: Text(
                  s.gameByStudio,
                  style: TextStyle(color: pal.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigPlay extends StatelessWidget {
  const _BigPlay({
    super.key,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $sub',
      child: ExcludeSemantics(
        child: Material(
          borderRadius: BorderRadius.circular(Radii.xl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              AppScope.read(context).audio.play(Sfx.button);
              onTap();
            },
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFB45CFF),
                    Color(0xFFFF6FC8),
                    Color(0xFFFF8A1F),
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.icon,
    required this.colour,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color colour;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Material(
        color: pal.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: () {
            AppScope.read(context).audio.play(Sfx.button);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(icon, color: colour),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: pal.textMuted, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: pal.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps a future alive without awaiting it (used by menu buttons).
void fireAndForget(Future<void> f) => unawaited(f);
