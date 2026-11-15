import 'package:flutter/widgets.dart';

/// Advertising abstraction. Gameplay never waits on, or depends on, ads:
/// every call is safe to make when ads are disabled, not consented, or failed
/// to load.
abstract class AdService extends ChangeNotifier {
  /// Starts consent collection and SDK initialisation. Never throws.
  Future<void> init();

  /// Whether this build is configured to show ads at all.
  bool get adsEnabled;

  /// Whether a banner may be shown at all (ads enabled and consent allows).
  bool get canShowAds;

  /// Whether the build is using Google's test ad units.
  bool get usingTestAds;

  /// Builds the banner shown at the very bottom of the puzzle screen, or an
  /// empty box. The space for it is [gameBannerHeight].
  Widget buildBanner(BuildContext context);

  /// Height to reserve for the puzzle screen banner (0 = no banner), known
  /// before the ad loads so the board never jumps.
  double get gameBannerHeight;

  /// "Remove ads" was bought: no banner and no between-puzzles ads. Rewarded
  /// ads stay available (the player chooses them).
  bool get adsRemoved;
  void setAdsRemoved(bool removed);

  /// Tells the service a puzzle was solved (for frequency capping).
  void onGameFinished();

  /// Shows an interstitial if the frequency cap allows and one is loaded.
  /// Completes when the ad is dismissed, or immediately if nothing is shown.
  Future<void> maybeShowInterstitial();

  /// Whether a rewarded ad is loaded and ready.
  bool get rewardedReady;

  /// Whether a rewarded ad is being loaded right now.
  bool get rewardedLoading;

  /// Loads a rewarded ad now if none is ready (the player asked for one).
  void requestRewarded();

  /// Shows a rewarded ad. Completes with `true` only if the ad SDK confirmed
  /// the reward was earned.
  Future<bool> showRewarded();

  /// Whether the privacy-options entry point must be shown (UMP).
  bool get privacyOptionsRequired;

  /// Shows the consent / privacy options form.
  Future<void> showPrivacyOptions();
}

/// Used when ads are disabled, in tests, and on unsupported platforms.
class NoAdService extends AdService {
  @override
  Future<void> init() async {}

  @override
  bool get adsEnabled => false;

  @override
  bool get canShowAds => false;

  @override
  bool get usingTestAds => false;

  @override
  Widget buildBanner(BuildContext context) => const SizedBox.shrink();

  @override
  double get gameBannerHeight => 0;

  @override
  bool get adsRemoved => false;

  @override
  void setAdsRemoved(bool removed) {}

  @override
  void onGameFinished() {}

  @override
  Future<void> maybeShowInterstitial() async {}

  @override
  bool get rewardedReady => false;

  @override
  bool get rewardedLoading => false;

  @override
  void requestRewarded() {}

  @override
  Future<bool> showRewarded() async => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
