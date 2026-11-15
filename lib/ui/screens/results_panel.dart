import 'package:flutter/material.dart';

import '../../core/engine.dart';
import '../../core/levels.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../../state/game_controller.dart';
import '../share/share_actions.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/game_widgets.dart';
import '../widgets/reminders.dart';

/// The game-over / level-complete panel: final score, best comparison,
/// rows cleared, highest combo, rewards, and what to do next.
class ResultsPanel extends StatelessWidget {
  const ResultsPanel({
    super.key,
    required this.controller,
    required this.onNext,
    required this.onAgain,
    required this.onHome,
    required this.onDouble,
  });

  final GameController controller;
  final VoidCallback onNext;
  final VoidCallback onAgain;
  final VoidCallback onHome;
  final VoidCallback onDouble;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final services = AppScope.of(context);
    final c = controller;
    final r = c.report!;
    final st = c.state;
    final won = st.status == Status.won;
    final title = switch (c.mode) {
      GameMode.campaign when won => s.levelComplete,
      GameMode.daily when won => s.dailySolved,
      GameMode.moves when won => s.targetReached,
      _ when won => s.targetReached,
      _ => s.endTitle(st.reason),
    };
    final canNext = c.isCampaign && won && c.spec.level < LevelCatalog.count;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: Material(
                key: const ValueKey('results-panel'),
                color: pal.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                child: Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (c.isCampaign && won) ...[
                        const SizedBox(height: Space.sm),
                        StarRow(stars: r.stars, size: 36),
                      ],
                      const SizedBox(height: Space.md),
                      Text(
                        s.finalScore,
                        style: TextStyle(color: pal.textMuted),
                      ),
                      Text(
                        s.formatNumber(r.score),
                        key: const ValueKey('final-score'),
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: pal.text,
                        ),
                      ),
                      if (r.newBest)
                        Text(
                          s.newBest,
                          style: TextStyle(
                            color: pal.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else if (r.bestBefore > 0)
                        Text(
                          s.bestWas(r.bestBefore),
                          style: TextStyle(color: pal.textMuted),
                        ),
                      const SizedBox(height: Space.md),
                      _StatRow(s.rowsCleared, s.formatNumber(st.rows)),
                      _StatRow(s.highestCombo, '×${st.bestCombo}'),
                      _StatRow(s.grainsCleared, s.formatNumber(st.sandCleared)),
                      _StatRow(s.movesUsed, s.formatNumber(st.moves)),
                      const SizedBox(height: Space.md),
                      if (r.coins > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CoinIcon(size: 22),
                            const SizedBox(width: Space.sm),
                            Text(
                              c.rewardDoubled
                                  ? s.coinsDoubled(r.coins * 2)
                                  : s.coinsEarned(r.coins),
                              style: TextStyle(
                                color: pal.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      if (r.coins > 0 &&
                          !c.rewardDoubled &&
                          services.ads.canShowAds) ...[
                        const SizedBox(height: Space.sm),
                        OutlinedButton.icon(
                          key: const ValueKey('double-coins'),
                          onPressed: onDouble,
                          icon: const Icon(Icons.ondemand_video_rounded),
                          label: Text(s.doubleCoins(r.coins)),
                        ),
                      ],
                      if (c.mode == GameMode.daily && won && !r.dailyRewarded)
                        Text(
                          s.dailyRewardAlready,
                          style: TextStyle(color: pal.textMuted),
                        ),
                      if (r.gift.isNotEmpty)
                        _Note(
                          s.giftReceived(
                            r.gift.entries
                                .map((e) => '${e.value}× ${s.powerName(e.key)}')
                                .join(', '),
                          ),
                        ),
                      if (r.unlockedTheme != null)
                        _Note(s.themeUnlocked(s.worldName(r.unlockedTheme!))),
                      if (r.missions.isNotEmpty) ...[
                        _Note(s.missionsDone),
                        for (final m in r.missions)
                          _IconLine(Icons.check_rounded, s.missionText(m)),
                        if (r.allMissions) Text(s.allMissionsBonus),
                      ],
                      if (r.achievements.isNotEmpty) ...[
                        _Note(s.achievementsUnlocked),
                        for (final a in r.achievements)
                          _IconLine(
                            Icons.emoji_events_rounded,
                            s.achievementTitle(a.id),
                          ),
                      ],
                      const SizedBox(height: Space.lg),
                      if (canNext)
                        FilledButton.icon(
                          key: const ValueKey('next-level'),
                          onPressed: onNext,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(s.nextLevel),
                        )
                      else
                        FilledButton.icon(
                          key: const ValueKey('play-again'),
                          onPressed: onAgain,
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(won ? s.playAgain : s.tryAgain),
                        ),
                      const SizedBox(height: Space.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            key: const ValueKey('results-home'),
                            onPressed: onHome,
                            icon: const Icon(Icons.home_rounded),
                            label: Text(s.home),
                          ),
                          TextButton.icon(
                            key: const ValueKey('results-share'),
                            onPressed: () => shareResult(context, c),
                            icon: const Icon(Icons.share_rounded),
                            label: Text(s.share),
                          ),
                        ],
                      ),
                      if (c.mode == GameMode.daily &&
                          !services.settings.value.reminder)
                        TextButton.icon(
                          onPressed: () => turnOnReminders(context),
                          icon: const Icon(Icons.notifications_rounded),
                          label: Text(s.remindMe),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: pal.textMuted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppPalette.of(context).cyan,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _IconLine extends StatelessWidget {
  const _IconLine(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 18, color: AppPalette.of(context).gold),
      const SizedBox(width: 6),
      Flexible(child: Text(text)),
    ],
  );
}
