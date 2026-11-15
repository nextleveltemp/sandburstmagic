/// App identity and links. Keep [version] in sync with `version:` in
/// pubspec.yaml (a unit test checks this).
///
/// Values you may need to supply are read from `--dart-define` at build
/// time, so nothing private has to be committed (see docs/PUBLISHING.md):
///
///     flutter build appbundle --release \
///       --dart-define=SBM_STORE_LISTED=true \
///       --dart-define=SBM_CONTACT_EMAIL=you@example.com \
///       --dart-define=SBM_PRIVACY_POLICY_URL=https://example.com/privacy
abstract final class AppInfo {
  static const String version = '1.0.0';
  static const int buildNumber = 1;

  /// Android application ID (permanent once uploaded to Google Play).
  static const String packageId = 'com.sandburstmagic';

  static const String appName = 'Sand Burst Magic';
  static const String studioName = 'Magivix Studio';

  /// The studio website, shown in Settings and used as the share link until
  /// the Play listing is live.
  static const String websiteUrl = 'https://magivix.com';

  /// The Google Play page for [packageId]. It only works once the app is
  /// published; until then [shareUrl] points to [websiteUrl].
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageId';

  /// Set `--dart-define=SBM_STORE_LISTED=true` for builds that go to Google
  /// Play: shared links then point to the store page and "Rate" appears.
  static const bool storeListed = bool.fromEnvironment('SBM_STORE_LISTED');

  /// The link included in shared texts and result cards.
  static const String shareUrl = storeListed ? playStoreUrl : websiteUrl;

  /// Address for Settings → "Send feedback" (as in Block Burst Magic).
  /// `SBM_CONTACT_EMAIL` can replace it; an empty value (as in
  /// config/ads.example.json) keeps support@magivix.com.
  static const String contactEmail = _contactEmailOverride == ''
      ? 'support@magivix.com'
      : _contactEmailOverride;
  static const String _contactEmailOverride = String.fromEnvironment(
    'SBM_CONTACT_EMAIL',
  );

  /// Published privacy policy page on magivix.com (the studio's general
  /// policy; opened from the welcome card and Settings, with the in-app
  /// summary if nothing can open it). Each link below can be replaced with
  /// --dart-define; an empty value keeps the built-in address.
  static const String privacyPolicyUrl = _privacyPolicyUrlOverride == ''
      ? 'https://magivix.com/privacy-policy/'
      : _privacyPolicyUrlOverride;
  static const String _privacyPolicyUrlOverride = String.fromEnvironment(
    'SBM_PRIVACY_POLICY_URL',
  );

  /// Published Terms of Use page on magivix.com (the in-app notice if
  /// nothing can open it).
  static const String termsUrl = _termsUrlOverride == ''
      ? 'https://magivix.com/terms-of-use/'
      : _termsUrlOverride;
  static const String _termsUrlOverride = String.fromEnvironment(
    'SBM_TERMS_URL',
  );

  /// Raise this when the Terms of Use change, so players accept them again.
  static const int termsVersion = 1;

  /// Google Play product ID of the one-time "Remove ads" purchase. Create a
  /// one-time product with exactly this ID in Play Console.
  static const String removeAdsProductId = String.fromEnvironment(
    'SBM_REMOVE_ADS_ID',
    defaultValue: 'remove_ads',
  );

  /// Magivix Studio's social pages (shared with Block Burst Magic): the
  /// "Follow us" icons in Settings, in this order.
  static const String facebookUrl = _facebookUrlOverride == ''
      ? 'https://www.facebook.com/magivix'
      : _facebookUrlOverride;
  static const String _facebookUrlOverride = String.fromEnvironment(
    'SBM_FACEBOOK_URL',
  );
  static const String tiktokUrl = _tiktokUrlOverride == ''
      ? 'https://www.tiktok.com/@magivix'
      : _tiktokUrlOverride;
  static const String _tiktokUrlOverride = String.fromEnvironment(
    'SBM_TIKTOK_URL',
  );
  static const String instagramUrl = _instagramUrlOverride == ''
      ? 'https://www.instagram.com/magivixstudio'
      : _instagramUrlOverride;
  static const String _instagramUrlOverride = String.fromEnvironment(
    'SBM_INSTAGRAM_URL',
  );
  static const String youtubeUrl = _youtubeUrlOverride == ''
      ? 'https://www.youtube.com/@magivix'
      : _youtubeUrlOverride;
  static const String _youtubeUrlOverride = String.fromEnvironment(
    'SBM_YOUTUBE_URL',
  );
  static const String xUrl = _xUrlOverride == ''
      ? 'https://x.com/magivixstudio'
      : _xUrlOverride;
  static const String _xUrlOverride = String.fromEnvironment('SBM_X_URL');

  static const List<(String name, String url)> socialLinks = [
    ('Facebook', facebookUrl),
    ('TikTok', tiktokUrl),
    ('Instagram', instagramUrl),
    ('YouTube', youtubeUrl),
    ('X', xUrl),
  ];
}
