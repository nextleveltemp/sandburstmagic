import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../../state/game_controller.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

enum PauseAction { resume, restart, home }

/// Pause menu: resume, restart, sound and vibration switches, home. The
/// game clock (Time Challenge) is stopped while it is open.
Future<PauseAction?> showPauseSheet(BuildContext context, GameController c) {
  return showAppSheet<PauseAction>(
    context: context,
    builder: (ctx) => _PauseSheet(controller: c),
  );
}

class _PauseSheet extends StatelessWidget {
  const _PauseSheet({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final services = AppScope.of(context);
    final pal = AppPalette.of(context);
    return ValueListenableBuilder(
      valueListenable: services.settings,
      builder: (context, settings, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.paused,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Space.lg),
          FilledButton.icon(
            key: const ValueKey('pause-resume'),
            onPressed: () => Navigator.pop(context, PauseAction.resume),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(s.resume),
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            key: const ValueKey('pause-restart'),
            onPressed: () async {
              final ok = await confirm(
                context,
                title: s.restartTitle,
                body: s.restartBody,
                confirmLabel: s.restart,
                cancelLabel: s.cancel,
              );
              if (ok && context.mounted) {
                Navigator.pop(context, PauseAction.restart);
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(s.restart),
          ),
          const SizedBox(height: Space.md),
          SwitchListTile(
            title: Text(s.soundEffects),
            value: settings.sfx,
            onChanged: (v) =>
                services.settings.update((x) => x.copyWith(sfx: v)),
          ),
          SwitchListTile(
            title: Text(s.music),
            value: settings.music,
            onChanged: (v) =>
                services.settings.update((x) => x.copyWith(music: v)),
          ),
          SwitchListTile(
            title: Text(s.haptics),
            value: settings.haptics,
            onChanged: (v) =>
                services.settings.update((x) => x.copyWith(haptics: v)),
          ),
          const SizedBox(height: Space.sm),
          TextButton.icon(
            key: const ValueKey('pause-home'),
            onPressed: () => Navigator.pop(context, PauseAction.home),
            icon: Icon(Icons.home_rounded, color: pal.textMuted),
            label: Text(s.home),
          ),
        ],
      ),
    );
  }
}
