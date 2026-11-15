import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The game's mark: a purple T-piece pouring into a rainbow sand dune
/// (echoing the app icon), drawn in code so it stays sharp at any size.
class SandMark extends StatelessWidget {
  const SandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const _dune = [
    Color(0xFF2E86FF),
    Color(0xFF2ECC71),
    Color(0xFFE0245E),
    Color(0xFFFFD23F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cell = s * 0.2;
    const purple = Color(0xFFB45CFF);
    // Sand dune bands.
    for (var i = 0; i < _dune.length; i++) {
      final y = s * (0.98 - i * 0.09);
      final path = Path()
        ..moveTo(0, s)
        ..lineTo(0, y)
        ..quadraticBezierTo(s * 0.3, y - s * 0.08, s * 0.55, y)
        ..quadraticBezierTo(s * 0.8, y + s * 0.06, s, y - s * 0.03)
        ..lineTo(s, s)
        ..close();
      canvas.drawPath(path, Paint()..color = _dune[i]);
    }
    // Purple sand heap under the piece.
    final heap = Path()
      ..moveTo(s * 0.2, s * 0.72)
      ..quadraticBezierTo(s * 0.5, s * 0.5, s * 0.8, s * 0.72)
      ..close();
    canvas.drawPath(heap, Paint()..color = purple);
    // Falling grains.
    final grain = Paint()..color = purple.withValues(alpha: 0.85);
    for (var i = 0; i < 9; i++) {
      final x = s * (0.32 + (i % 3) * 0.12 + (i ~/ 3) * 0.02);
      final y = s * (0.44 + (i ~/ 3) * 0.07);
      canvas.drawCircle(Offset(x, y), s * 0.022, grain);
    }
    // The T piece.
    final rr = Paint()..color = purple;
    final hi = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (final (cx, cy) in const [(0, 0), (1, 0), (2, 0), (1, 1)]) {
      final r = Rect.fromLTWH(
        s * 0.2 + cx * cell,
        s * 0.04 + cy * cell,
        cell * 0.92,
        cell * 0.92,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell * 0.22)),
        rr,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            r.left + cell * 0.12,
            r.top + cell * 0.1,
            cell * 0.5,
            cell * 0.18,
          ),
          Radius.circular(cell * 0.1),
        ),
        hi,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

/// Mark plus "Sand Burst / Magic" set in Outfit, with "Magic" in gold.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.height = 44, this.subtitle});

  /// Height of one line of the name.
  final double height;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    TextStyle line(Color color) => TextStyle(
      fontFamily: 'Outfit',
      fontFamilyFallback: AppTheme.symbolFallback,
      fontSize: height * 0.78,
      height: 1.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -height * 0.03,
      color: color,
    );
    return Semantics(
      header: true,
      label: AppInfo.appName,
      child: ExcludeSemantics(
        // Scales down (never up) on narrow screens or with large text.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SandMark(size: height * 1.7),
              SizedBox(width: height * 0.3),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sand Burst', style: line(palette.text)),
                  SizedBox(height: height * 0.04),
                  Text('Magic', style: line(palette.gold)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: AppTheme.symbolFallback,
                          fontSize: height * 0.3,
                          fontWeight: FontWeight.w500,
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular level indicator with XP progress ring.
class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.level,
    required this.progress,
    this.size = 44,
    this.semanticLabel,
  });

  final int level;
  final double progress;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress,
            track: palette.surfaceHigh,
            color: palette.cyan,
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                '$level',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: AppTheme.symbolFallback,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.38,
                  color: palette.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    if (sweep > 0.01) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

/// Square icon button with a 48dp touch target and tooltip.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 24,
      color: palette.text,
      style: IconButton.styleFrom(
        backgroundColor: palette.surface,
        disabledBackgroundColor: palette.surface.withValues(alpha: 0.5),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: palette.stroke.withValues(alpha: 0.7)),
        ),
      ),
    );
    final b = badge;
    if (b == null) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: -4,
          top: -4,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: palette.violet,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text(
                b,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: AppTheme.symbolFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A tappable surface row used for modes and menu entries.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.accent,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color? accent;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: palette.stroke.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: Space.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: enabled ? palette.text : palette.textMuted,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Space.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three stars, filled up to [stars]. Shape and fill both carry the
/// information (not colour alone).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 18, this.label});

  final int stars;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i < stars ? palette.gold : palette.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// Section title used in lists. Sentence case, no decoration.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xs,
        Space.xl,
        Space.xs,
        Space.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}

/// Confirmation dialog. Returns `true` only if the user confirms.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final palette = AppPalette.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      // Scrolls when the keyboard or large text leaves little room.
      scrollable: true,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: palette.danger)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Page transition: quick fade with a slight scale. Short and calm.
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  FadeScaleRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          final reduce = MediaQuery.disableAnimationsOf(context);
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          if (reduce) return FadeTransition(opacity: curved, child: child);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.985, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Shows a modal bottom sheet that is as tall as its content (up to the
/// full screen) and scrolls when the content does not fit, e.g. on small
/// phones or with large accessibility text. Use instead of
/// [showModalBottomSheet] everywhere.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        SingleChildScrollView(child: builder(sheetContext)),
  );
}

/// [base] plus the system bars' insets at the bottom and sides. The app draws
/// edge-to-edge, so a scrolling screen with its own padding must add these
/// for its last item to scroll fully clear of the navigation bar (gesture
/// handle or three-button bar).
EdgeInsets withSystemInsets(BuildContext context, EdgeInsets base) {
  final insets = MediaQuery.paddingOf(context);
  return base.copyWith(
    left: base.left + insets.left,
    right: base.right + insets.right,
    bottom: base.bottom + insets.bottom,
  );
}
