import 'package:flutter/material.dart';

import '../../core/levels.dart';
import '../../core/progression.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Player statistics and achievements.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final services = AppScope.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.statistics),
          bottom: TabBar(
            tabs: [
              Tab(text: s.statsTab),
              Tab(text: s.achievements),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: services.progress,
          builder: (context, _) =>
              TabBarView(children: [_StatsTab(), _AchievementsTab()]),
        ),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final p = AppScope.of(context).progress;
    final st = p.stats;
    Widget row(String label, String value) => ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      children: [
        SectionTitle(s.statsGames),
        row(s.statsPlayed, s.formatNumber(st.gamesPlayed)),
        row(s.statsRows, s.formatNumber(st.rows)),
        row(s.statsGrains, s.formatNumber(st.sand)),
        row(s.statsPieces, s.formatNumber(st.pieces)),
        row(s.statsCombo, '×${st.bestCombo}'),
        row(s.statsBiggest, '${st.bestWave}'),
        row(s.statsMulti, s.formatNumber(st.multi)),
        row(s.statsPerfect, s.formatNumber(st.perfect)),
        row(s.statsPowerUps, s.formatNumber(st.powerUps)),
        row(s.statsCoins, s.formatNumber(st.coinsEarned)),
        row(s.statsPlayTime, s.formatDuration(st.playSeconds)),
        SectionTitle(s.statsBests),
        for (final m in GameMode.values)
          row(s.modeName(m), s.formatNumber(st.best(m))),
        SectionTitle(s.statsLevels),
        row(
          s.statsLevelsCompleted,
          s.levelsProgress(p.levelsCompleted, LevelCatalog.count),
        ),
        row(s.statsStars, '${p.totalStars} / ${LevelCatalog.count * 3}'),
        SectionTitle(s.statsDaily),
        row(s.statsCurrentStreak, '${p.streak}'),
        row(s.statsBestStreak, '${p.progress.daily.bestStreak}'),
        Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text(s.statsNote, style: TextStyle(color: pal.textMuted)),
        ),
      ],
    );
  }
}

class _AchievementsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final got = AppScope.of(context).progress.progress.achievements;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Text(
            s.achievementsCount(got.length, Achievements.all.length),
            style: TextStyle(color: pal.textMuted),
          ),
        ),
        for (final a in Achievements.all)
          Card(
            child: ListTile(
              leading: Icon(
                got.containsKey(a.id)
                    ? Icons.emoji_events_rounded
                    : Icons.lock_outline_rounded,
                color: got.containsKey(a.id) ? pal.gold : pal.textMuted,
              ),
              title: Text(s.achievementTitle(a.id)),
              subtitle: Text(s.achievementDesc(a.id)),
              trailing: Text(
                '+${a.coins}',
                style: TextStyle(color: pal.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
