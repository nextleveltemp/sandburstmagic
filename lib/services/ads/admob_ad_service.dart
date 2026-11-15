import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/doc_store.dart';
import '../../data/docs.dart';
import '../../data/models.dart';
import 'ad_config.dart';
import 'ad_service.dart';

/// Google AdMob implementation (official `google_mobile_ads` plugin),
/// including Google's User Messaging Platform (UMP) for consent.
///
/// Placement rules enforced here and by the callers:
/// * One banner, at the very bottom of the puzzle screen, below the
///   controls (space reserved in advance so nothing jumps); none on menus.
/// * Interstitials only between puzzles: a moment after one ends (or as
///   the player leaves its results sooner), at most once per puzzle, and
///   only within [InterstitialPolicy] limits.
/// * Rewarded ads only when the player explicitly taps "Watch ad"; rewards
///   are granted only from the SDK's `onUserEarnedReward` callback.
class AdMobAdService extends AdService {
  AdMobAdService({
    required this.config,
    required DocStore store,
    this.policy = const InterstitialPolicy(),
    DateTime Function()? clock,
    ConsentDebugSettings? consentDebugSettings,
  }) : _store = store,
       _consentDebugOverride = consentDebugSettings,
       _clock = clock ?? DateTime.now;

  final AdConfig config;
  final InterstitialPolicy policy;
  final DocStore _store;
  final DateTime Function() _clock;

  /// Testing only (on-device tests): simulated consent region. Ignored
  /// unless Google's test ad units are in use.
  final ConsentDebugSettings? _consentDebugOverride;

  AdState _state = const AdState();
  bool _sdkReady = false;
  bool _canRequestAds = false;
  bool _privacyRequired = false;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  int _interstitialFailures = 0;
  int _rewardedFailures = 0;
  Timer? _interstitialRetry;
  Timer? _rewardedRetry;
  int _interstitialLoadedAt = 0;
  int _rewardedLoadedAt = 0;
  bool _disposed = false;
  bool _adsRemoved = false;
  AdSize? _bannerSize;

  /// Google: a loaded full-screen ad expires after one hour, and showing an
  /// expired one fails. Ads older than this are thrown away and reloaded.
  static const _maxAdAge = Duration(minutes: 50);

  /// No interstitial within this time after a rewarded ad was watched.
  static const rewardedCooldown = Duration(seconds: 60);
  int _lastRewardedMillis = 0;

  bool _expired(int loadedAt) =>
      loadedAt > 0 &&
      _clock().millisecondsSinceEpoch - loadedAt > _maxAdAge.inMilliseconds;

  @override
  bool get adsEnabled => config.enabled;

  @override
  bool get canShowAds => config.enabled && _sdkReady && _canRequestAds;

  @override
  bool get usingTestAds => config.usingTestIds;

  @override
  bool get adsRemoved => _adsRemoved;

  @override
  void setAdsRemoved(bool removed) {
    if (_adsRemoved == removed) return;
    _adsRemoved = removed;
    if (removed) {
      _interstitialRetry?.cancel();
      _interstitial?.dispose();
      _interstitial = null;
    } else {
      _loadInterstitial();
    }
    if (!_disposed) notifyListeners();
  }

  bool get _bannerAllowed => canShowAds && !_adsRemoved;

  @override
  double get gameBannerHeight =>
      _bannerAllowed ? (_bannerSize?.height.toDouble() ?? 0) : 0;

  @override
  bool get rewardedReady =>
      canShowAds && _rewarded != null && !_expired(_rewardedLoadedAt);

  @override
  bool get rewardedLoading => canShowAds && _loadingRewarded;

  @override
  void requestRewarded() {
    if (!canShowAds) return;
    if (_rewarded != null && _expired(_rewardedLoadedAt)) {
      _rewarded?.dispose();
      _rewarded = null;
    }
    if (_rewarded != null || _loadingRewarded) return;
    // The player is waiting: skip any back-off delay.
    _rewardedRetry?.cancel();
    _loadRewarded();
  }

  /// Diagnostics for on-device tests (read-only).
  int get interstitialsShown => _interstitialsShown;
  int get rewardedShown => _rewardedShown;
  int get rewardsEarned => _rewardsEarned;
  int get fullScreenDismissed => _fullScreenDismissed;
  int _interstitialsShown = 0;
  int _rewardedShown = 0;
  int _rewardsEarned = 0;
  int _fullScreenDismissed = 0;
  bool get interstitialReady => canShowAds && _interstitial != null;
  bool get sdkReady => _sdkReady;
  bool get canRequestAds => _canRequestAds;
  AdState get adState => _state;

  @override
  bool get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> init() async {
    _state = _store.load(Docs.ads).value ?? const AdState();
    if (!config.enabled) return;
    try {
      await _updateConsent();
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) debugPrint('Consent form: ${error.message}');
      });
    } catch (e) {
      debugPrint('Consent flow failed: $e');
    }
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      _privacyRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (_canRequestAds) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
        );
        await MobileAds.instance.initialize();
        _sdkReady = true;
        _loadInterstitial();
        _loadRewarded();
        await _measureBanner();
      }
    } catch (e) {
      debugPrint('Ads unavailable: $e');
    }
    if (!_disposed) notifyListeners();
  }

  // Testing only: lets an emulator or test phone simulate a region for the
  // consent flow. Both values come from --dart-define and are ignored unless
  // Google's test ad units are in use, so production builds never set them.
  static const _umpTestDevice = String.fromEnvironment('SBM_UMP_TEST_DEVICE');
  static const _umpGeography = String.fromEnvironment(
    'SBM_UMP_DEBUG_GEOGRAPHY',
  );

  ConsentDebugSettings? _consentDebugSettings() {
    if (!config.usingTestIds) return null;
    if (_consentDebugOverride != null) return _consentDebugOverride;
    if (_umpTestDevice.isEmpty) return null;
    final geography = switch (_umpGeography) {
      'eea' => DebugGeography.debugGeographyEea,
      'us' => DebugGeography.debugGeographyRegulatedUsState,
      'other' => DebugGeography.debugGeographyOther,
      _ => DebugGeography.debugGeographyDisabled,
    };
    return ConsentDebugSettings(
      debugGeography: geography,
      testIdentifiers: [_umpTestDevice],
    );
  }

  Future<void> _updateConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(consentDebugSettings: _consentDebugSettings()),
      () {
        if (!done.isCompleted) done.complete();
      },
      (FormError error) {
        debugPrint('Consent info update failed: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  /// The puzzle screen reserves this much space for the banner: Google's
  /// anchored adaptive banner, as wide as the screen (no gaps at the
  /// sides) and only as tall as that width needs (about 56-64 dp on
  /// phones), as in Block Burst Magic.
  Future<void> _measureBanner() async {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final width = (view.physicalSize.width / view.devicePixelRatio)
          .truncate();
      // The standard anchored adaptive size (full width, short). Its
      // replacement, the "large" size, is taller than this game wants.
      final adaptive =
          // ignore: deprecated_member_use
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      _bannerSize = adaptive ?? AdSize.banner;
      debugPrint(
        'Banner size: ${_bannerSize!.width} x ${_bannerSize!.height} dp',
      );
    } catch (e) {
      debugPrint('Banner size unavailable: $e');
    }
  }

  Duration _backoff(int failures) {
    final minutes = math.min(30, 1 << math.min(failures, 5));
    return Duration(minutes: minutes);
  }

  void _loadInterstitial() {
    if (!canShowAds || _adsRemoved) return;
    if (_interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: config.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialFailures = 0;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitial = ad;
          _interstitialLoadedAt = _clock().millisecondsSinceEpoch;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          _interstitialFailures++;
          debugPrint('Interstitial failed to load: ${error.message}');
          _interstitialRetry?.cancel();
          _interstitialRetry = Timer(
            _backoff(_interstitialFailures),
            _loadInterstitial,
          );
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!canShowAds || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    if (!_disposed) notifyListeners();
    RewardedAd.load(
      adUnitId: config.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewardedFailures = 0;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _rewarded = ad;
          _rewardedLoadedAt = _clock().millisecondsSinceEpoch;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          _rewardedFailures++;
          debugPrint('Rewarded failed to load: ${error.message}');
          if (!_disposed) notifyListeners();
          _rewardedRetry?.cancel();
          _rewardedRetry = Timer(_backoff(_rewardedFailures), _loadRewarded);
        },
      ),
    );
  }

  @override
  void onGameFinished() {
    _state = _state.copyWith(
      gamesCompleted: _state.gamesCompleted + 1,
      gamesSinceInterstitial: _state.gamesSinceInterstitial + 1,
    );
    unawaited(_store.save(Docs.ads, _state));
  }

  @override
  Future<void> maybeShowInterstitial() async {
    final ad = _interstitial;
    if (!canShowAds || _adsRemoved || ad == null) return;
    if (_expired(_interstitialLoadedAt)) {
      ad.dispose();
      _interstitial = null;
      _loadInterstitial();
      return;
    }
    final now = _clock().millisecondsSinceEpoch;
    final allowed = policy.allows(
      gamesCompleted: _state.gamesCompleted,
      gamesSinceLast: _state.gamesSinceInterstitial,
      lastShownMillis: _state.lastInterstitialMillis,
      nowMillis: now,
    );
    if (!allowed) return;
    if (now - _lastRewardedMillis < rewardedCooldown.inMilliseconds) return;
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (ad) => _interstitialsShown++,
      onAdDismissedFullScreenContent: (ad) {
        _fullScreenDismissed++;
        ad.dispose();
        if (!done.isCompleted) done.complete();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: ${error.message}');
        ad.dispose();
        if (!done.isCompleted) done.complete();
        _loadInterstitial();
      },
    );
    _state = _state.copyWith(
      gamesSinceInterstitial: 0,
      lastInterstitialMillis: now,
    );
    unawaited(_store.save(Docs.ads, _state));
    try {
      await ad.show();
    } catch (e) {
      debugPrint('Interstitial show error: $e');
      if (!done.isCompleted) done.complete();
    }
    // Never leave the player stuck if a callback is lost.
    await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (!canShowAds || ad == null) return false;
    if (_expired(_rewardedLoadedAt)) {
      requestRewarded();
      return false;
    }
    _rewarded = null;
    notifyListeners();
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (ad) => _rewardedShown++,
      onAdDismissedFullScreenContent: (ad) {
        _fullScreenDismissed++;
        ad.dispose();
        // The player just watched an ad: no interstitial right after it.
        _lastRewardedMillis = _clock().millisecondsSinceEpoch;
        if (!done.isCompleted) done.complete(earned);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded failed to show: ${error.message}');
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _loadRewarded();
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          earned = true;
          _rewardsEarned++;
        },
      );
    } catch (e) {
      debugPrint('Rewarded show error: $e');
      if (!done.isCompleted) done.complete(false);
    }
    return done.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => earned,
    );
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) debugPrint('Privacy form: ${error.message}');
        if (!done.isCompleted) done.complete();
      });
    } catch (e) {
      debugPrint('Privacy options failed: $e');
      if (!done.isCompleted) done.complete();
    }
    await done.future;
    try {
      final could = _canRequestAds;
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (_canRequestAds && !could && !_sdkReady) {
        await MobileAds.instance.initialize();
        _sdkReady = true;
      }
      if (_canRequestAds) {
        _loadInterstitial();
        _loadRewarded();
        if (_bannerSize == null) await _measureBanner();
      }
    } catch (e) {
      debugPrint('Consent refresh failed: $e');
    }
    if (!_disposed) notifyListeners();
  }

  @override
  Widget buildBanner(BuildContext context) {
    final size = _bannerSize;
    if (!_bannerAllowed || size == null) return const SizedBox.shrink();
    return _AdaptiveBanner(adUnitId: config.bannerId, size: size);
  }

  @override
  void dispose() {
    _disposed = true;
    _interstitialRetry?.cancel();
    _rewardedRetry?.cancel();
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }
}

/// Anchored adaptive banner in the space the game screen reserved for it.
/// Shows nothing (the reserved space stays the game's background) until an
/// ad has loaded.
class _AdaptiveBanner extends StatefulWidget {
  const _AdaptiveBanner({required this.adUnitId, required this.size});

  final String adUnitId;
  final AdSize size;

  @override
  State<_AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<_AdaptiveBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // No ad (offline, no fill): the slot simply stays empty and the
          // game goes on. Try again a minute later.
          debugPrint('Banner failed: ${error.message}');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          _retry?.cancel();
          _retry = Timer(const Duration(seconds: 60), () {
            if (mounted && _ad == null) _load();
          });
        },
      ),
    );
    _ad = ad;
    unawaited(ad.load());
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
