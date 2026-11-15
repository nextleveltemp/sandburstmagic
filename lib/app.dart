import 'dart:async';

import 'package:flutter/material.dart';

import 'app_info.dart';
import 'data/models.dart';
import 'l10n/strings.dart';
import 'state/app_services.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/tutorial_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/theme/app_theme.dart';

class SandBurstMagicApp extends StatefulWidget {
  const SandBurstMagicApp({
    super.key,
    required this.services,
    this.startAds = true,
  });

  final AppServices services;

  /// Tests disable the consent/ads start-up.
  final bool startAds;

  @override
  State<SandBurstMagicApp> createState() => _SandBurstMagicAppState();
}

class _SandBurstMagicAppState extends State<SandBurstMagicApp> {
  late final AppLifecycleListener _lifecycle;
  late final bool _showTutorial = !widget.services.settings.value.tutorialSeen;
  late final bool _showWelcome =
      widget.services.settings.value.termsAccepted < AppInfo.termsVersion;
  bool _adsStarted = false;

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    _s.settings.addListener(_onSettings);
    unawaited(_s.audio.init());
    unawaited(_s.syncReminders());
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _s.audio.pauseForBackground();
        unawaited(_s.flush());
      },
      onShow: () {
        _s.audio.resumeFromBackground();
        _s.progress.observeToday();
        _s.progress.markActive();
        unawaited(_s.syncReminders());
      },
    );
    unawaited(_s.purchases.init());
    // Consent forms need a visible activity, so wait for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartAds());
  }

  /// Ads (and Google's consent form, where required) start only after the
  /// player has accepted the Terms of Use on the welcome card.
  void _maybeStartAds() {
    if (_adsStarted || !widget.startAds) return;
    if (_s.settings.value.termsAccepted < AppInfo.termsVersion) return;
    _adsStarted = true;
    unawaited(_s.ads.init());
  }

  void _onSettings() {
    _s.applySettings();
    unawaited(_s.syncReminders());
    _maybeStartAds();
    setState(() {});
  }

  @override
  void dispose() {
    _s.settings.removeListener(_onSettings);
    _lifecycle.dispose();
    super.dispose();
  }

  ThemeMode get _themeMode => switch (_s.settings.value.themePreference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.light => ThemeMode.light,
  };

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _s,
      child: MaterialApp(
        title: AppInfo.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        localizationsDelegates: const [StringsDelegate()],
        supportedLocales: StringsDelegate.supportedLocales,
        builder: (context, child) {
          final reduce = _s.settings.value.reduceMotion;
          final media = MediaQuery.of(context);
          return MediaQuery(
            // The in-app "Reduce motion" switch behaves like the system one.
            data: media.copyWith(
              disableAnimations: media.disableAnimations || reduce,
            ),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: _showWelcome
            ? const WelcomeScreen()
            : _showTutorial
            ? const TutorialScreen(firstRun: true)
            : const HomeScreen(),
      ),
    );
  }
}
