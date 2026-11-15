import 'package:flutter/foundation.dart';

/// Advertising configuration.
///
/// HOW TO CONFIGURE (see docs/ADMOB.md):
///
/// * The **AdMob App ID** goes in `android/admob.properties`
///   (`admob.appId=ca-app-pub-…~…`). It is read at build time.
/// * **Ad unit IDs** are passed at build time, for example:
///
///   ```
///   flutter build appbundle --dart-define-from-file=config/ads.prod.json
///   ```
///
///   where `config/ads.prod.json` (git-ignored) contains the keys below.
///
/// Debug and profile builds always use Google's official **test** ad units
/// unless overridden. Release builds with no production IDs show **no ads at
/// all** rather than test ads.
class AdConfig {
  const AdConfig({
    required this.enabled,
    required this.usingTestIds,
    required this.bannerId,
    required this.interstitialId,
    required this.rewardedId,
  });

  final bool enabled;
  final bool usingTestIds;
  final String bannerId;
  final String interstitialId;
  final String rewardedId;

  // Google's published test ad unit IDs for Android:
  // https://developers.google.com/admob/android/test-ads
  static const _testAndroidBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // Google's published test ad unit IDs for iOS:
  // https://developers.google.com/admob/ios/test-ads
  static const _testIosBanner = 'ca-app-pub-3940256099942544/2435281174';
  static const _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static const _adsEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: true,
  );
  static const _forceTestIds = bool.fromEnvironment('ADMOB_USE_TEST_IDS');

  static const _androidBanner = String.fromEnvironment('ADMOB_ANDROID_BANNER');
  static const _androidInterstitial = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL',
  );
  static const _androidRewarded = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED',
  );
  static const _iosBanner = String.fromEnvironment('ADMOB_IOS_BANNER');
  static const _iosInterstitial = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL',
  );
  static const _iosRewarded = String.fromEnvironment('ADMOB_IOS_REWARDED');

  static const disabled = AdConfig(
    enabled: false,
    usingTestIds: false,
    bannerId: '',
    interstitialId: '',
    rewardedId: '',
  );

  /// Resolves the configuration for the current platform and build mode.
  static AdConfig resolve() {
    if (!_adsEnabled || kIsWeb) return disabled;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (!isAndroid && !isIos) return disabled;

    final prodBanner = isAndroid ? _androidBanner : _iosBanner;
    final prodInterstitial = isAndroid
        ? _androidInterstitial
        : _iosInterstitial;
    final prodRewarded = isAndroid ? _androidRewarded : _iosRewarded;
    final hasProd =
        prodBanner.isNotEmpty &&
        prodInterstitial.isNotEmpty &&
        prodRewarded.isNotEmpty;

    final useTest = _forceTestIds || !kReleaseMode || !hasProd;
    if (useTest && kReleaseMode && !_forceTestIds) {
      // A release build without production IDs: no ads at all.
      return disabled;
    }
    if (useTest) {
      return AdConfig(
        enabled: true,
        usingTestIds: true,
        bannerId: isAndroid ? _testAndroidBanner : _testIosBanner,
        interstitialId: isAndroid
            ? _testAndroidInterstitial
            : _testIosInterstitial,
        rewardedId: isAndroid ? _testAndroidRewarded : _testIosRewarded,
      );
    }
    return AdConfig(
      enabled: true,
      usingTestIds: false,
      bannerId: prodBanner,
      interstitialId: prodInterstitial,
      rewardedId: prodRewarded,
    );
  }
}

/// Interstitial frequency rules (pure logic, unit tested). Well inside
/// Google's policies: never during play, never on launch or exit, none in a
/// new player's first solved puzzles, and spaced out by puzzles and time.
///
/// Limits (the same as Block Burst Magic's; change them here, the game
/// engine is not involved): one after every 2nd finished puzzle (solved, or
/// a challenge that ran out; the first after the 2nd puzzle), shown a
/// moment after it ends, and never two within 60 seconds. None within 60 seconds after a rewarded ad either (see
/// `AdMobAdService.rewardedCooldown`).
class InterstitialPolicy {
  const InterstitialPolicy({
    this.graceGames = 1,
    this.minGamesBetween = 2,
    this.minInterval = const Duration(seconds: 60),
  });

  /// No interstitials during a player's first [graceGames] finished puzzles.
  final int graceGames;

  /// At least this many finished puzzles between interstitials.
  final int minGamesBetween;

  /// At least this much time between interstitials.
  final Duration minInterval;

  bool allows({
    required int gamesCompleted,
    required int gamesSinceLast,
    required int lastShownMillis,
    required int nowMillis,
  }) {
    if (gamesCompleted <= graceGames) return false;
    if (gamesSinceLast < minGamesBetween) return false;
    if (lastShownMillis > 0 &&
        nowMillis - lastShownMillis < minInterval.inMilliseconds) {
      return false;
    }
    return true;
  }
}
