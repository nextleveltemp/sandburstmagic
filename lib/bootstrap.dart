import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    show ConsentDebugSettings;

import 'app_info.dart';
import 'data/doc_store.dart';
import 'data/docs.dart';
import 'data/kv_store.dart';
import 'data/models.dart';
import 'services/ads/ad_config.dart';
import 'services/ads/ad_service.dart';
import 'services/ads/admob_ad_service.dart';
import 'services/audio_service.dart';
import 'services/haptics_service.dart';
import 'services/purchase_service.dart';
import 'services/reminder_service.dart';
import 'services/review_service.dart';
import 'services/share_service.dart';
import 'state/app_services.dart';
import 'state/progress_controller.dart';
import 'state/settings_controller.dart';

/// Creates every service. Nothing here may block the app from starting:
/// storage falls back to memory, audio and ads fail silently.
Future<AppServices> bootstrap({
  KvStore? storeOverride,
  AudioService? audioOverride,
  AdService? adsOverride,
  ShareService? shareOverride,
  ReviewService? reviewOverride,
  ReminderService? remindersOverride,
  PurchaseService? purchasesOverride,
  PuzzleWorker worker = const PuzzleWorker(),
  ConsentDebugSettings? consentDebugSettings,
  DateTime Function()? clock,
}) async {
  KvStore kv;
  if (storeOverride != null) {
    kv = storeOverride;
  } else {
    try {
      kv = await PrefsKvStore.open(Docs.allKeys);
    } catch (e) {
      debugPrint('Persistent storage unavailable, using memory: $e');
      kv = MemoryKvStore();
    }
  }
  final store = DocStore(kv);
  final settings = SettingsController(
    store,
    store.load(Docs.settings).value ?? const AppSettings(),
  );
  final progress = ProgressController(
    store: store,
    initial: store.load(Docs.progress).value ?? PlayerProgress(),
    clock: clock,
  );
  progress.markActive();
  final config = AdConfig.resolve();
  final ads =
      adsOverride ??
      (config.enabled
          ? AdMobAdService(
              config: config,
              store: store,
              consentDebugSettings: consentDebugSettings,
            )
          : NoAdService());
  final services = AppServices(
    store: store,
    settings: settings,
    progress: progress,
    saves: GameSaves(store),
    audio: audioOverride ?? PluginAudioService(),
    haptics: HapticsService(),
    ads: ads,
    daily: DailyService(store, worker),
    share: shareOverride ?? PluginShareService(),
    review: reviewOverride ?? PluginReviewService(store),
    reminders: remindersOverride ?? PluginReminderService(),
    purchases: purchasesOverride ?? PlayPurchaseService(store),
    appVersion: AppInfo.version,
    worker: worker,
  );
  services.applySettings();
  return services;
}
