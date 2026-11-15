import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import 'home_screen.dart';
import 'tutorial_screen.dart';

/// First launch: the launch screen (app icon on the midnight background,
/// exactly like Android's) with a welcome card in the lower half. The player
/// accepts the Terms of Use to continue (then the tutorial on first launch);
/// both documents are links.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => openTerms(context);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => openPrivacy(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _in.value = 1;
      } else {
        _in.forward();
      }
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  void _accept() {
    final services = AppScope.read(context);
    // First-time players go through the short tutorial next.
    final tutorial = !services.settings.value.tutorialSeen;
    services.settings.update(
      (v) => v.copyWith(termsAccepted: AppInfo.termsVersion),
    );
    services.applySettings();
    Navigator.of(context).pushReplacement(
      FadeScaleRoute<void>(
        builder: (_) => tutorial
            ? const TutorialScreen(firstRun: true)
            : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final palette = AppPalette.dark;
    final theme = Theme.of(context);
    final link = TextStyle(
      color: palette.cyan,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: palette.cyan,
    );
    return Scaffold(
      // Same colour and icon as Android's launch screen, so the card simply
      // appears on top of it.
      backgroundColor: const Color(0xFF0D1433),
      body: Stack(
        children: [
          Center(
            child: ClipOval(
              child: SizedBox.square(
                dimension: 160,
                child: OverflowBox(
                  maxWidth: 240,
                  maxHeight: 240,
                  child: Image.asset(
                    'assets/images/launch_icon.png',
                    width: 240,
                    height: 240,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  0,
                  Space.lg,
                  Space.lg,
                ),
                child: AnimatedBuilder(
                  animation: _in,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_in.value);
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 40),
                        child: child,
                      ),
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      key: const ValueKey('welcome-card'),
                      padding: const EdgeInsets.all(Space.xl),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(Radii.xl),
                        border: Border.all(
                          color: palette.violet.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              s.welcomeTitle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: palette.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.md),
                          Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: palette.textMuted,
                                height: 1.45,
                              ),
                              children: [
                                TextSpan(text: s.welcomeBefore),
                                TextSpan(
                                  text: s.termsOfUse,
                                  style: link,
                                  recognizer: _terms,
                                ),
                                TextSpan(text: s.welcomeMiddle),
                                TextSpan(
                                  text: s.privacyPolicy,
                                  style: link,
                                  recognizer: _privacy,
                                ),
                                TextSpan(text: s.welcomeAfter),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Space.xl),
                          FilledButton(
                            key: const ValueKey('welcome-accept'),
                            onPressed: _accept,
                            child: Text(s.accept),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
