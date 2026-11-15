import 'package:flutter/material.dart';

import '../../core/progression.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../theme/sand_theme.dart';
import '../theme/tokens.dart';

/// The look the player chose in the shop.
Look lookOf(AppServices s) {
  final p = s.progress;
  return Look(
    board: BoardTheme.byId(p.selected(CosmeticKind.board)),
    palette: SandPalette.byId(p.selected(CosmeticKind.palette)),
    grain: p.selected(CosmeticKind.grain),
    burst: p.selected(CosmeticKind.burst),
    piece: p.selected(CosmeticKind.piece),
  );
}

void toast(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );
}

/// Shows a rewarded ad if one is ready. Returns true only if the player
/// earned the reward. Never shown without the player asking for it.
Future<bool> watchRewarded(BuildContext context) async {
  final s = Strings.of(context);
  final ads = AppScope.read(context).ads;
  if (!ads.rewardedReady) {
    ads.requestRewarded();
    toast(context, ads.rewardedLoading ? s.adLoading : s.adUnavailable);
    return false;
  }
  final ok = await ads.showRewarded();
  ads.requestRewarded();
  return ok;
}

/// Gradient background of a board theme.
class ThemedBackground extends StatelessWidget {
  const ThemedBackground({super.key, required this.theme, required this.child});

  final BoardTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.top, theme.bottom],
      ),
    ),
    child: child,
  );
}

/// Coin balance; tapping opens the shop.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins, this.onTap});

  final int coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = Strings.of(context);
    return Semantics(
      button: onTap != null,
      label: s.coinsLabel(coins),
      child: ExcludeSemantics(
        child: Material(
          color: p.surface.withValues(alpha: 0.85),
          shape: StadiumBorder(side: BorderSide(color: p.stroke)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.xs + 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 18),
                  const SizedBox(width: Space.xs + 2),
                  Text(
                    s.formatNumber(coins),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: p.text,
                      fontSize: 15,
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

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        colors: [Color(0xFFFFE58A), Color(0xFFE0A21B)],
      ),
      border: Border.all(color: const Color(0xFFB07A0A), width: size * 0.08),
    ),
    alignment: Alignment.center,
    child: Text(
      '\$',
      style: TextStyle(
        fontSize: size * 0.6,
        height: 1,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF8A5A00),
      ),
    ),
  );
}

/// Icon of each power-up.
IconData powerIcon(int index) => const [
  Icons.horizontal_rule_rounded,
  Icons.palette_rounded,
  Icons.shuffle_rounded,
  Icons.format_align_justify_rounded,
  Icons.hardware_rounded,
  Icons.swap_horiz_rounded,
  Icons.brightness_7_rounded,
  Icons.add_box_rounded,
][index];
