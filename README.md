# Sand Burst Magic

An original water-sorting puzzle game for Android (iOS-ready), built with
Flutter by Magivix Studio. Pour coloured liquids between glass tubes until
every tube holds a single colour.

Everything works offline. There is no account, no server and no analytics SDK.
Ads (Google AdMob) are optional and only appear at natural breaks.

---

## Contents

1. [What's in the game](#whats-in-the-game)
2. [Important: what has and hasn't been verified](#important-what-has-and-hasnt-been-verified)
3. [Set up your computer](#set-up-your-computer)
4. [Run the game](#run-the-game)
5. [Run the tests](#run-the-tests)
6. [Test on an Android phone](#test-on-an-android-phone)
7. [Project layout](#project-layout)
8. [Configure AdMob](#configure-admob)
9. [Build a signed App Bundle for Google Play](#build-a-signed-app-bundle-for-google-play)
10. [Before you submit to Google Play](#before-you-submit-to-google-play)
11. [Known limitations](#known-limitations)

More detail lives in `docs/`:

| File | What it covers |
| --- | --- |
| `docs/ARCHITECTURE.md` | How the code is organised: rules, solver, levels, saves, animation |
| `docs/LEVELS.md` | The 300 levels and 36 challenges: difficulty curve and proofs (generated) |
| `docs/ADMOB.md` | Ads, consent, frequency caps, test vs production IDs |
| `docs/PUBLISHING.md` | Signing, App Bundles, Play Console steps, Data safety answers to verify |
| `docs/PRIVACY_POLICY_TEMPLATE.md` | A starting point for your privacy policy (needs your review) |
| `docs/TESTING.md` | What the automated tests cover and a manual test checklist |
| `docs/ASSETS.md` | Fonts, sounds, icons, and how to regenerate them |

---

## What's in the game

- **Levels** – 300 levels in four groups (Easy, Medium, Hard, Expert), from
  2 colours up to 10 colours, with a few "one spare tube" levels mixed in.
  Every level was solved by a computer search when it was made, and its
  shortest solution is stored and replayed by the tests. Stars for solving
  within a target number of pours; best results are kept.
- **Daily Puzzle** – the same puzzle for everyone on the same date, playable
  offline, with streaks and a once-per-day reward. Protected against
  changing the device clock to farm rewards.
- **Challenges** – 36 challenges in four tiers: pour limits, undo limits,
  no hints, one spare tube, and expert puzzles. Each is proven winnable.
- **Relax** – roomy puzzles (three spare tubes), no target, calm music.
- **Rules** – tap a tube to pick it up, tap another to pour. All matching
  liquid on top pours together, as much as fits; only onto the same colour
  or into an empty tube. Unlimited free undo (except in undo-limit
  challenges), restart with confirmation, and hints computed by the solver.
- **Feel** – glass tubes with liquid drawn by area (levels stay true even
  in the rounded bottom and while a tube tilts), a tilt-and-pour animation
  with a liquid stream, a stopper on completed tubes, gentle shake for a
  refused pour, original synthesised sounds and music, light haptics.
- **Progression** – player level and XP, 17 achievements, eight visual
  themes (Moonlit Potion and Clear Crystal free; Mermaid Lagoon, Fairy
  Spring, Golden Elixir, Bubblegum Fizz, Frozen Spell and Ruby Ember
  unlocked by playing), two bottle shapes earned by playing, lifetime
  statistics.
- **Accessibility** – dark/light/system themes, reduce-motion switch (also
  follows the system setting), optional colour symbols on every liquid,
  large touch targets, screen-reader labels for every tube ("Tube 2 of 7,
  3 of 4 full, bottom to top: red, blue, blue"), selection shown by lift,
  outline and a chevron (not colour alone).
- **Sharing** – a result card image (drawn by the game, with the solved
  tubes) plus the link; the Daily Puzzle shares a spoiler-free text.
- **Ads** – banner at the very bottom of the puzzle screen only (space
  reserved, 24 dp gap above it, never over the tubes or controls);
  full-screen ads only between puzzles, as in Block Burst Magic: one a
  moment (1 s) after every 2nd finished puzzle (the first after the 2nd),
  at most one per puzzle, never two within 60 s and never within 60 s
  after a rewarded ad; rewarded ads only when the player asks, with
  the reward stated first: an extra hint, an extra empty tube (once per
  attempt, not in challenges), "Keep playing?" with 5 more pours when a
  challenge's pour limit runs out (once per attempt), or double XP on the
  results card. Details in `docs/ADMOB.md`.
- **Rating** – Google Play's in-app review card, only after a three-star
  solve, a solved daily or a first challenge win, after at least 8 solved
  puzzles, at most 3 times, 45+ days apart.
- **Daily reminder** – opt-in, time of your choice, skips days you already
  solved, local notification only.
- **First launch** – a 2-second launch screen with the icon, then a
  welcome card asking the player to accept the Terms of Use (links to the
  Terms and the Privacy Policy; ads and Google's consent form start only
  after Accept), then the 30-second interactive tutorial (skippable,
  replayable from Settings → How to play), then home.
- **Remove ads** – one-time Google Play purchase (Settings → Ads), with
  Restore purchase. Rewarded ads stay available.
- **Settings extras** – Privacy policy and Terms of Use (open the
  magivix.com pages; the in-app text if no browser), Send feedback
  (support@magivix.com), Follow us (Facebook, TikTok, Instagram, YouTube
  and X icons under the website link, opening the Magivix Studio pages
  shared with Block Burst Magic), Magivix Studio website.
- **Bottle shapes** – Tube, Bottle, Flask, Jar and Potion from the start;
  Vial at player level 8 and Teardrop after winning 24 challenges (chosen
  on the Themes screen; a new shape is announced on the results card).
  Every shape holds the same four pours.

---

## Important: what has and hasn't been verified

This project was written in an environment that cannot run Flutter, so it is
compiled, analysed, tested and built by GitHub Actions (Flutter 3.47.7),
including on Android 14 emulators. Results, logs and screenshots are saved
to the branches `ci-logs-test`, `ci-logs-build` (also holds the test APK
`sand-burst-magic-release-test.apk`, which shows Google's test ads),
`ci-logs-device-phone`, `ci-logs-device-small`, `ci-logs-device-play` and
`ci-logs-device-store`.

The level bank itself was checked outside Flutter: the Python reference
model (`tool/reference_model/`) found a proven-shortest solution for all 300
levels and 36 challenges and replayed each one (see `docs/LEVELS.md`).

The status of each CI check is recorded in the section below as runs
complete.

### CI status

Every push to `main` runs the CI workflow. As of November 2026: packages
install, `dart format` is clean, `flutter analyze` reports no issues, all
widget and unit tests pass, and the release APK and App Bundle build. Store
screenshots are rendered on every push to `ci-logs-store-shots`. The
on-device tests (Actions → Device tests) are started by hand.

---

## Set up your computer

You need three things. If you already have Android Studio and Flutter, skip
to step 3.

1. **Flutter SDK 3.47.7 (stable) or newer 3.x.** Follow
   <https://docs.flutter.dev/get-started/install> for your operating system
   and choose *Android* as the target.
2. **Android Studio** (it installs the Android SDK and an emulator). During
   setup, also install the *Android SDK Command-line Tools*. Then run
   `flutter doctor --android-licenses` and accept the licences.
3. Open a terminal **in this project folder** and run:

   ```bash
   flutter doctor          # every Android item should have a green tick
   flutter pub get         # downloads the packages this project uses
   ```

> Tip: `flutter doctor` explains how to fix anything missing.

---

## Run the game

Start an Android emulator from Android Studio (*Device Manager* → ▶), or plug
in a phone (see below). Then:

```bash
flutter run
```

Debug builds show Google **test** ads. That is expected and safe.

---

## Run the tests

```bash
dart format .           # tidies code layout (changes whitespace only)
flutter analyze         # static checks – should print "No issues found!"
flutter test            # unit and widget tests (a few minutes)
flutter build apk --debug
```

On-device tests (need a running emulator or connected phone):

```bash
flutter test integration_test/app_test.dart
flutter test integration_test/device_check_test.dart
```

What the tests cover is listed in `docs/TESTING.md`.

---

## Test on an Android phone

1. On the phone: **Settings → About phone →** tap **Build number** seven
   times to enable Developer options.
2. **Settings → System → Developer options →** turn on **USB debugging**.
3. Connect the phone by USB and accept the "Allow USB debugging?" prompt.
4. Run `flutter devices` – your phone should be listed.
5. Run `flutter run` (debug) or `flutter run --release` (closer to real
   performance; uses the debug signing key unless you set up signing).

To install a built APK directly: `flutter build apk --debug`, then
`flutter install`, or copy `build/app/outputs/flutter-apk/app-debug.apk` to the
phone and open it. The CI test APK is on the `ci-logs-build` branch.

---

## Project layout

```
lib/
  core/        Pure Dart rules (no Flutter): board and pours, engine (undo,
               restart, limits), A* solver and hints, generator, levels and
               challenges (level_data.dart is generated), daily, progression
  data/        Versioned local saves (shared_preferences), models
  services/    Audio, haptics, ads (AdMob + consent), share, rating,
               reminders – all fail-safe
  state/       Controllers that connect rules, saves and UI
  ui/          Theme, tube painter, board and pour animation, screens
  l10n/        All user-facing text (ready for more languages)
test/          Unit, widget and reference-vector tests
integration_test/  On-device tests (device check, play session, store shots)
tool/          Level generator and Python reference model, asset generators
android/       Android project (Gradle Kotlin DSL)
assets/        Fonts, sound effects, music
store/         Play icon (512×512), feature graphic (1024×500), screenshots
docs/          Detailed documentation
```

---

## Configure AdMob

Short version (full guide: `docs/ADMOB.md`):

1. Create the app and three ad units (Banner, Interstitial, Rewarded) in
   <https://admob.google.com>.
2. Copy `android/admob.properties.example` to `android/admob.properties` and
   put your **App ID** in it.
3. Copy `config/ads.example.json` to `config/ads.prod.json` and put your
   **ad unit IDs** in it.
4. Build with: `flutter build appbundle --dart-define-from-file=config/ads.prod.json`

Without step 4, release builds contain **no ads at all**. Debug builds always
use Google's test ads. Both files from steps 2–3 are git-ignored, so they are
never committed.

---

## Build a signed App Bundle for Google Play

Short version (full guide with explanations: `docs/PUBLISHING.md`):

```bash
# 1. Create an upload key once (keep the file and passwords safe forever)
keytool -genkey -v -keystore ~/sand-burst-magic-upload.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload

# 2. Copy android/key.properties.example to android/key.properties and fill it in

# 3. Build
flutter build appbundle --release --dart-define-from-file=config/ads.prod.json
```

The bundle is at `build/app/outputs/bundle/release/app-release.aab`.
Increase the number after `+` in `pubspec.yaml` (`version: 1.0.0+1`) before
every upload, and update `lib/app_info.dart` to match.

---

## Before you submit to Google Play

A full checklist is in `docs/PUBLISHING.md`. The essentials:

- [ ] Run all checks in [Run the tests](#run-the-tests) and fix any failures.
- [ ] Application ID `com.sandburstmagic` (confirmed; permanent after the
      first upload).
- [ ] Play-test on at least one low-end and one modern Android phone.
- [ ] Set up signing and AdMob production IDs.
- [ ] Publish a privacy policy at a public URL (template in `docs/`).
- [ ] Complete the Data safety form (verified answers list in `docs/PUBLISHING.md`).
- [ ] Complete content rating and target audience (recommended: 13+; ads
      configuration assumes the app is **not** directed at children).
- [ ] Store listing: icon `store/icon-512.png`, feature graphic
      `store/feature-graphic-1024x500.png`, phone screenshots
      `store/screenshots/` (made by the CI "store" job).
- [ ] Test through Play's internal testing track before production.

---

## Known limitations

- Not yet tested on a real phone; emulators only (see above).
- No cloud save or cross-device sync; progress lives on the device (Android
  system backup can restore it). Statistics are personal and local – there
  are no global leaderboards.
- Daily puzzles follow the device's local date. Without a server the game
  cannot verify the true date; moving the clock back pauses rewards instead.
- One puzzle in progress is kept per mode. Replaying an already solved level
  is not saved, so it never replaces the level you are working on.
- Only English text is included (the text system is ready for translations).
- iOS: the code is cross-platform, but the `ios/` folder is not included.
  Create it with `flutter create --platforms=ios .` and add your AdMob iOS
  App ID to `ios/Runner/Info.plist` (`GADApplicationIdentifier`) before
  building for iPhone.
- Performance targets (60 FPS) have not been measured on a device yet.
- Sounds and music are simple synthesised originals; you may want to replace
  them with professionally produced, licensed audio (same file names).
- Undo is free and unlimited in levels, so there is no "watch an ad for an
  undo"; the rewarded "continue" is the extra empty tube.
