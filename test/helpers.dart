import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:sand_burst_magic/bootstrap.dart';
import 'package:sand_burst_magic/data/kv_store.dart';
import 'package:sand_burst_magic/services/ads/ad_service.dart';
import 'package:sand_burst_magic/services/audio_service.dart';
import 'package:sand_burst_magic/services/purchase_service.dart';
import 'package:sand_burst_magic/services/reminder_service.dart';
import 'package:sand_burst_magic/services/review_service.dart';
import 'package:sand_burst_magic/services/share_service.dart';
import 'package:sand_burst_magic/state/app_services.dart';

/// Golden values exported by tool/reference_model (gen_vectors.py).
Map<String, Object?> loadVectors() {
  final raw = File('test/fixtures/reference_vectors.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, Object?>;
}

/// An ad service whose rewarded ads either play to the end (and report the
/// reward) or are never available.
class FakeAdService extends AdService {
  FakeAdService({this.fill = true, this.earn = true, this.bannerHeight = 0});

  /// Whether a rewarded ad is available.
  bool fill;

  /// Whether the SDK reports the reward as earned when the ad closes.
  bool earn;
  int rewardedShown = 0;
  int finished = 0;
  int interstitialChecks = 0;

  @override
  Future<void> init() async {}
  @override
  bool get adsEnabled => true;
  @override
  bool get canShowAds => true;
  @override
  bool get usingTestAds => true;

  /// Height the puzzle screen reserves for the banner (0 = none).
  double bannerHeight;
  bool _removed = false;

  @override
  Widget buildBanner(BuildContext context) => _removed || bannerHeight == 0
      ? const SizedBox.shrink()
      : const SizedBox.expand(key: ValueKey('fake-banner'));
  @override
  double get gameBannerHeight => _removed ? 0 : bannerHeight;
  @override
  bool get adsRemoved => _removed;
  @override
  void setAdsRemoved(bool removed) {
    _removed = removed;
    notifyListeners();
  }

  @override
  void onGameFinished() => finished++;
  @override
  Future<void> maybeShowInterstitial() async => interstitialChecks++;
  @override
  bool get rewardedReady => fill;
  @override
  bool get rewardedLoading => false;
  @override
  void requestRewarded() {}
  @override
  Future<bool> showRewarded() async {
    if (!fill) return false;
    rewardedShown++;
    return earn;
  }

  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> showPrivacyOptions() async {}
}

/// Services backed by memory storage, silent audio, no ads, and puzzle
/// searches run inline (no isolates) so widget tests stay deterministic.
Future<AppServices> testServices({
  MemoryKvStore? store,
  bool tutorialSeen = true,
  bool termsAccepted = true,
  AdService? ads,
  PurchaseService? purchases,
  DateTime Function()? clock,
}) async {
  final services = await bootstrap(
    storeOverride: store ?? MemoryKvStore(),
    audioOverride: SilentAudioService(),
    adsOverride: ads ?? NoAdService(),
    shareOverride: RecordingShareService(),
    reviewOverride: NoReviewService(),
    remindersOverride: NoReminderService(),
    purchasesOverride: purchases ?? NoPurchaseService(),
    worker: const PuzzleWorker(inline: true),
    clock: clock,
  );
  if (termsAccepted) {
    services.settings.update((s) => s.copyWith(termsAccepted: 1));
  }
  if (tutorialSeen) {
    services.settings.update((s) => s.copyWith(tutorialSeen: true));
  }
  return services;
}
