# Publishing to Google Play

Requirements change; items marked **verify** must be re-checked in the Play
Console at submission time. Facts below were taken over from Block Burst
Magic, where they were checked on 19 October 2026; re-check them before
you submit.

## 1. Confirm the identity (permanent!)

- Application ID: `com.sandburstmagic` (confirmed by the owner; in
  `android/app/build.gradle.kts`, `namespace` and `applicationId`, and the
  Kotlin package folder). **It cannot change after the first upload.**
  A unit test checks that all places agree, including `lib/app_info.dart`.
- Display name: "Sand Burst Magic"
  (`android/app/src/main/res/values/strings.xml`).
- Version: `version: 1.0.0+1` in `pubspec.yaml`. The part after `+` is the
  version code and must increase with every upload. Keep
  `lib/app_info.dart` in sync (a test checks it).

### Links and contact details (supplied at build time)

These live in `lib/app_info.dart` and are switched on with `--dart-define`
values, which you can keep in `config/ads.prod.json` next to the AdMob IDs
(see `config/ads.example.json`):

| Value | What it does | Until you set it |
| --- | --- | --- |
| `SBM_STORE_LISTED=true` | Shared links point to `https://play.google.com/store/apps/details?id=com.sandburstmagic`; Settings shows "Rate Sand Burst Magic" | Shared links point to `https://magivix.com`; no Rate row |
| `SBM_CONTACT_EMAIL` | Settings → Magivix Studio → "Send feedback" opens an email to this address | Defaults to support@magivix.com (also when left empty) |
| `SBM_PRIVACY_POLICY_URL` | Welcome card and Settings → "Privacy policy" open this page (the in-app summary if no browser can open it) | Defaults to https://magivix.com/privacy-policy/ (also when left empty) |
| `SBM_TERMS_URL` | Welcome card and Settings → "Terms of Use" open this page (the in-app note if no browser can open it) | Defaults to https://magivix.com/terms-of-use/ (also when left empty) |
| `SBM_FACEBOOK_URL`, `SBM_TIKTOK_URL`, `SBM_INSTAGRAM_URL`, `SBM_YOUTUBE_URL`, `SBM_X_URL` | The "Follow us" icons under "Visit our website" in Settings open these pages | Default to facebook.com/magivix, tiktok.com/@magivix, instagram.com/magivixstudio, youtube.com/@magivix and x.com/magivixstudio (also when left empty) |
| `SBM_REMOVE_ADS_ID` | Google Play product ID of "Remove ads" (default `remove_ads`) | — |

The Terms of Use and Privacy Policy links are built in (the studio's
general pages on magivix.com). The welcome card asks every new player to
accept the Terms of Use.

Set `SBM_STORE_LISTED=true` for every build you upload to Google Play: the
store link works as soon as the listing is live. Don't enter a privacy
policy URL before the page is actually published.

### "Remove ads" (in-app purchase)

1. Play Console → your app → **Monetize with Play → Products → One-time
   products → Create product**. Product ID: **`remove_ads`** (must match
   `SBM_REMOVE_ADS_ID`; an ID can never be reused). Name "Remove ads", set
   your price, activate it.
2. Billing works only for builds installed from Google Play (internal or
   closed testing track). Add your Google account under **Settings →
   License testing** to buy without being charged.
3. In the app: Settings → Ads → Remove ads. After buying, the banner and
   between-puzzles ads disappear for good; rewarded ads stay (players
   choose them). "Restore purchase" brings it back after a reinstall.
4. Data safety: purchases are processed by Google Play; the game stores
   only an "ads removed" flag on the phone and sends nothing to you.
   **Verify** the form's purchase-history question against your final
   setup.

## 2. Create your upload key (once)

```bash
keytool -genkey -v -keystore ~/sand-burst-magic-upload.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store the `.jks` file and both passwords somewhere safe (password manager +
backup). If you lose it you will need Google support to reset the upload key.

Create `android/key.properties` (copy `android/key.properties.example`):

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/Users/you/sand-burst-magic-upload.jks
```

This file is git-ignored. Without it, release builds are signed with the
debug key and Play will reject them.

Use **Play App Signing** (the default for new apps): Google holds the app
signing key; you only keep the upload key.

## 3. Build the App Bundle

```bash
flutter clean
flutter pub get
flutter test
flutter build appbundle --release --dart-define-from-file=config/ads.prod.json
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

Technical requirements:

- **Target API:** from 31 August 2026, new apps and updates must target
  Android 16 (API 36) or higher
  ([source](https://developer.android.com/google/play/requirements/target-sdk)).
  Flutter 3.47.7 sets `targetSdk` and `compileSdk` to 36. **Verify** in
  Play Console after upload.
- **Minimum SDK:** 24 (Android 7.0), from Flutter and the AdMob SDK.
- **16 KB memory pages:** **verify** in Play Console → App bundle explorer
  that the bundle is compatible.
- Code shrinking: R8 is switched **off** in `android/app/build.gradle.kts`
  (a lesson from Block Burst Magic, where it broke plugins at runtime).

## 4. Play Console setup

1. Create the app (name, default language, game, free).
2. **App content** section:
   - Privacy policy URL (required – host `docs/PRIVACY_POLICY_TEMPLATE.md`
     after editing; no URL is provided by this project).
   - Ads: **Yes, my app contains ads**.
   - App access: all functionality available without login.
   - Target audience and content: recommended **13+** (see `docs/ADMOB.md`
     about children).
   - Content rating questionnaire (IARC): puzzle game, no violence, no user
     interaction, no purchases, contains ads → typically "Everyone"/PEGI 3.
     Answer honestly; the result is decided by the questionnaire.
   - Data safety (next section).
   - Advertising ID declaration: **Yes**, used for advertising (the Google
     Mobile Ads SDK adds the `AD_ID` permission automatically).
   - Government apps / financial features / health: No.
3. **Store listing:** short and full description, icon
   `store/icon-512.png`, feature graphic `store/feature-graphic-1024x500.png`,
   at least 2 phone screenshots (take them on a device/emulator), category
   *Puzzle*, contact email.
4. Release to **Internal testing** first, install from Play on a real
   phone, check ads and consent, then promote.
5. New personal developer accounts may need a closed test with testers for
   a period before production access – **verify** the current rule in the
   Console.

## 5. Data safety – what to verify

Sand Burst Magic itself collects nothing: progress, statistics and settings stay on
the device (and in the user's own Android backup). The daily reminder is a
local notification scheduled on the phone; sharing only opens Android's
share sheet when the player taps Share, and the player chooses the app.
Google's in-app review card is shown by Google Play itself. None of these
send data to you, so they add nothing to the Data safety form. The Google Mobile Ads SDK
does collect and share data. According to Google's disclosure page for SDK
25.5.0 ([source](https://developers.google.com/admob/android/privacy/play-data-disclosure)),
the SDK automatically collects:

| Data type (Play category) | Collected | Shared | Purpose |
| --- | --- | --- | --- |
| Approximate location (derived from IP address) | Yes | Yes | Advertising, analytics, fraud prevention |
| App interactions (launches, taps, video views) | Yes | Yes | Advertising, analytics, fraud prevention |
| Diagnostics (performance) | Yes | Yes | Analytics, fraud prevention |
| Device or other IDs (advertising ID, app set ID) | Yes | Yes | Advertising, analytics, fraud prevention |

Also state: data is **encrypted in transit**; users can reset/delete the
advertising ID in Android settings; collection is required for ads.

**Verify** each row against Google's page at submission time (the SDK version
in your final build may differ), and against the UMP disclosure page
<https://developers.google.com/admob/ump/android/play-data-disclosure>.
Do not declare "no data collected" while ads are enabled.

If you build with `--dart-define=ADS_ENABLED=false`, the SDK is still
compiled in; remove the `google_mobile_ads` dependency entirely if you want
to declare no data collection.

## 6. Permissions in the final manifest

Expected from the same plugins as Block Burst Magic (the CI build job
prints the permissions of the built APK; re-check the merged manifest of
your final build):

- `INTERNET` (declared by the app, for ads).
- Added automatically by the Google Mobile Ads SDK and its Google Play
  services / WorkManager libraries: `ACCESS_NETWORK_STATE`,
  `com.google.android.gms.permission.AD_ID`,
  `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`,
  `ACCESS_ADSERVICES_TOPICS` (Android Privacy Sandbox), `WAKE_LOCK`,
  `FOREGROUND_SERVICE`, and the internal
  `com.sandburstmagic.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
  These are normal for apps using AdMob. In Play Console, answer the
  *Advertising ID* declaration with "Yes, for advertising".
- Daily reminder (opt-in, `flutter_local_notifications`):
  `RECEIVE_BOOT_COMPLETED` (declared by the app, to keep the reminder after
  a restart), `POST_NOTIFICATIONS` (asked for only when the player turns the
  reminder on, Android 13+) and `VIBRATE` (added by the plugin). Reminders
  are inexact, so no "Alarms & reminders" (exact alarm) permission is used.
- No camera, microphone, contacts, location or storage permissions.
- Haptics use the system haptic API.

Check the merged manifest after a build:
`build/app/intermediates/merged_manifests/release/…/AndroidManifest.xml`
(or Android Studio → *Merged Manifest* tab).

## 7. Remaining tasks before submission

See the README, "what has and hasn't been verified", for what CI has run.

Needs you:

- [ ] Play on your own phone(s) with the `docs/TESTING.md` checklist,
      ideally including a low-end phone; check vibration and sound by ear.
- [ ] Create the upload key and `android/key.properties` (section 2).
- [ ] AdMob: create the app and the three ad units, publish the consent
      messages (GDPR and US states), add `app-ads.txt` to your developer
      website, then put the IDs in local config (`docs/ADMOB.md`). Without
      published messages, players in regulated regions get no ads.
- [ ] Enter the privacy policy URL (https://magivix.com/privacy-policy/,
      the studio's general policy, already built into the game) in Play
      Console. Send feedback goes to support@magivix.com.
- [ ] Play Console: Data safety (section 5), content rating questionnaire,
      target audience (not "children" while ads are personalised), ads
      declaration "Yes", app category Games → Puzzle.
- [ ] Store listing: short and full description, phone screenshots (2–8,
      `store/screenshots/`), feature graphic
      (`store/feature-graphic-1024x500.png`), icon (`store/icon-512.png`).
- [ ] **Closed test before production** if your developer account is a
      personal account created after 13 November 2023: at least 12 testers
      opted in for 14 consecutive days, then apply for production access
      ([Google's rule](https://support.google.com/googleplay/android-developer/answer/14151465)).
      **Verify** the current numbers in the Console; start early.
- [ ] Optional: replace the synthesised audio with professional audio.
