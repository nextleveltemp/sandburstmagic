# Advertising (Google AdMob)

Sand Burst Magic uses the official [`google_mobile_ads`](https://pub.dev/packages/google_mobile_ads)
Flutter plugin (version 9.1.0, Google Mobile Ads Android SDK 25.4.0 and UMP
SDK 4.0.0 at the time of writing). The game never depends on ads: if they are
disabled, not consented to, or fail to load, nothing changes for the player.

## Where ads can appear

The same final settings as Block Burst Magic: no ad near the board or
controls, none at launch or exit, none during a game, and every rewarded
ad is the player's choice with the reward stated first.

| Format | Where | Rules |
| --- | --- | --- |
| Banner (anchored adaptive) | At the very bottom of the game screen, below the tray and power-up bar, full screen width (about 56–64 dp tall on phones) | Space reserved before the ad loads (the board never jumps); a 16 dp gap keeps the controls away from the ad; none on the home screen or menus; none in the tutorial. Hidden after "Remove ads". |
| Interstitial | About 1 second after a game ends (level won or lost, game over, time up, or "No thanks" on "Keep playing?"), once the results are up. Never on Restart | Never after "Remove ads". Never during play, never at launch or exit. One after every 2nd finished game (the first after the 2nd game), never two within 60 seconds, and never within 60 seconds after a rewarded ad. |
| Rewarded: hint / undo | Hint and Undo buttons after the free one of the game is used (the badge shows ▶) | The player must tap. Granted only in the reward callback. If no ad is ready, one is requested ("Loading an ad…"). |
| Rewarded: power-up | Tapping a power-up with none left → "Watch an ad: use one free" | One use, granted only after the reward. Buying with coins is offered next to it. |
| Rewarded: free coins | Shop → "Watch an ad: +40 coins" | Only when tapped. |
| Rewarded: "Keep playing?" | When no piece fits | Once per game: clears the bottom three rows and deals new pieces, stated before the ad. "No thanks" is always there and shows the results. |
| Rewarded: double coins | Results → "Watch ad: double coins (+N)" | Once per game, only when the game earned coins and an ad is ready. |

Implementation: `lib/services/ads/` (`ad_service.dart` interface,
`admob_ad_service.dart` implementation, `ad_config.dart` IDs and frequency
policy). The policy has unit tests.

## Test IDs (used automatically in debug builds)

From Google's documentation (Android:
<https://developers.google.com/admob/android/test-ads>):

| | ID |
| --- | --- |
| App ID (sample) | `ca-app-pub-3940256099942544~3347511713` |
| Adaptive banner | `ca-app-pub-3940256099942544/9214589741` |
| Interstitial | About 1 second after a game ends (level won or lost, game over, time up, or "No thanks" on "Keep playing?"), once the results are up. Never on Restart | Never after "Remove ads". Never during play, never at launch or exit. One after every 2nd finished game (the first after the 2nd game), never two within 60 seconds, and never within 60 seconds after a rewarded ad. |
| Rewarded | `ca-app-pub-3940256099942544/5224354917` |

Never click your own live ads, and never ship test IDs.

## Setting up production ads

1. In <https://admob.google.com>: **Apps → Add app** (Android, not yet
   published is fine). Note the **App ID** (`ca-app-pub-…~…`).
2. Create three ad units for the app: **Banner**, **Interstitial**,
   **Rewarded** (reward: 1 hint). Note each **ad unit ID** (`ca-app-pub-…/…`).
3. Copy `android/admob.properties.example` → `android/admob.properties`:

   ```properties
   admob.appId=ca-app-pub-1234567890123456~1234567890
   ```

   The Gradle build injects this into `AndroidManifest.xml`
   (`com.google.android.gms.ads.APPLICATION_ID`). Alternatively set the
   `ADMOB_APP_ID` environment variable on your build machine.
4. Copy `config/ads.example.json` → `config/ads.prod.json` and fill in the
   three ad unit IDs.
5. Build with `--dart-define-from-file=config/ads.prod.json`.

Both files are in `.gitignore`. If production unit IDs are missing, **release
builds show no ads** (they do not fall back to test ads). To deliberately
use test ads in a release build for internal testing, add
`--dart-define=ADMOB_USE_TEST_IDS=true`. To build without any ads at all:
`--dart-define=ADS_ENABLED=false`.

While developing with real ad units, register your phone as a test device
(see Google's guide) to avoid invalid traffic.

## Consent (UMP)

At start-up (after the first frame) the app:

1. requests consent information (`ConsentInformation.requestConsentInfoUpdate`),
2. shows the consent form if required (`ConsentForm.loadAndShowConsentFormIfRequired`),
3. initialises the Mobile Ads SDK and loads ads **only** if
   `canRequestAds()` is true.

If the privacy options entry point is required (for example in the EEA/UK),
**Settings → Ad privacy choices** opens the form again.

What you must do in AdMob: **Privacy & messaging** → create a **European
regulations (GDPR)** message, and a **US state regulations** message if you
distribute in the US. Without a published message the form will not appear,
**and the app will show no ads at all to players in those regions**: the
consent SDK then reports that consent is required but cannot be collected,
so `canRequestAds()` stays false. (Seen in Block Burst Magic testing: with Google's sample
App ID, which has no messages, a US-based emulator got "No available form
can be built" and no ads. The on-device tests therefore simulate an
unregulated region for the test device only.)
Review Google's current requirements in the AdMob Help Center
(**Privacy & messaging** section) before launch.

## Content and audience settings

- Requests use `maxAdContentRating: PG`.
- The app is **not** configured as child-directed. If you choose a target
  audience that includes children under 13 in the Play Console, you must
  follow the Families policy and use only Families-certified ad SDK
  configurations (`tagForChildDirectedTreatment`, appropriate ratings). Ask
  before changing this; it affects revenue and compliance.

## Before going live

- [ ] Real App ID and unit IDs configured; build is a release build.
- [ ] `app-ads.txt` published on the developer website listed in Play
      (AdMob → Apps → app-ads.txt).
- [ ] Consent messages published in AdMob.
- [ ] AdMob account and app approved. (This project has **not** been
      reviewed by AdMob.)
- [ ] Data safety form reflects the Google Mobile Ads SDK (see
      `docs/PUBLISHING.md`).
