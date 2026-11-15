import 'package:flutter/material.dart';

import '../../core/levels.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../../state/launcher.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Today's Daily Puzzle: date, streak and a play button.
Future<void> showDailySheet(BuildContext context) => showAppSheet<void>(
  context: context,
  builder: (ctx) => const _DailySheet(),
);

class _DailySheet extends StatefulWidget {
  const _DailySheet();

  @override
  State<_DailySheet> createState() => _DailySheetState();
}

class _DailySheetState extends State<_DailySheet> {
  bool _loading = false;

  Future<void> _play() async {
    final services = AppScope.read(context);
    final s = Strings.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final c = await Launcher.daily(services);
      if (!mounted) return;
      nav.pop();
      await openGame(nav.context, c);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(s.dailyFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final services = AppScope.of(context);
    final p = services.progress;
    final saved = services.saves.get(GameMode.daily);
    final resume = saved != null && saved.spec.date == p.today;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.calendar_today_rounded, size: 44, color: pal.cyan),
        const SizedBox(height: Space.sm),
        Text(
          s.dailyTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          s.dailyFor(p.today),
          textAlign: TextAlign.center,
          style: TextStyle(color: pal.textMuted),
        ),
        const SizedBox(height: Space.md),
        Text(
          '${s.dailyStreak(p.streak)} · ${s.bestStreak(p.progress.daily.bestStreak)}',
          textAlign: TextAlign.center,
          style: TextStyle(color: pal.gold, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Space.md),
        Text(s.dailyExplain, style: TextStyle(color: pal.textMuted)),
        if (!p.rewardsAllowed)
          Text(s.dailyPaused, style: TextStyle(color: pal.danger)),
        const SizedBox(height: Space.lg),
        FilledButton.icon(
          key: const ValueKey('daily-play'),
          onPressed: _loading ? null : _play,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(
            _loading
                ? s.dailyPreparing
                : resume
                ? s.dailyContinue
                : p.dailyDoneToday
                ? s.dailyDoneAgain
                : s.dailyPlay,
          ),
        ),
      ],
    );
  }
}
