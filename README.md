# Sand Burst Magic

An original block-and-sand puzzle game for Android (iOS-ready), built with
Flutter by Magivix Studio. Place colourful pieces on a 10 × 10 board; they
dissolve into grains of sand that fall, slide and settle. Fill a whole row
and it bursts.

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
| `docs/ARCHITECTURE.md` | How the code is organised: rules, sand simulation, levels, saves, rendering |
| `docs/LEVELS.md` | The 100 campaign levels: goals, move limits and proofs (generated) |
| `docs/ADMOB.md` | Ads, consent, frequency caps, test vs production IDs |
| `docs/PUBLISHING.md` | Signing, App Bundles, Play Console steps, Data safety answers to verify |
| `docs/PRIVACY_POLICY_TEMPLATE.md` | A starting point for your privacy policy (needs your review) |
| `docs/TESTING.md` | What the automated tests cover and a manual test checklist |
| `docs/ASSETS.md` | Fonts, sounds, icons, and how to regenerate them |

---

## What's in the game

- **The core** – a 10 × 10 board and a tray of three pieces (15 shapes in 30
  orientations: singles, lines of 2–5, square, L, reverse L, T, small
  corner, zigzags). Drag a piece onto the board, or tap it and tap a cell to
  see a preview, then tap again to confirm. Placed blocks become sand: each
  grain falls, slides diagonally off slopes and settles. A full row bursts
  (colours never need to match); two or more at once score much more. A new
  set of three is dealt only when all three are used, and never a set where
  nothing fits if something could. The game ends when no piece fits.
- **The logical grid is the truth.** The rules simulate sand cell by cell
  in plain Dart; the screen replays exactly what the rules did (every grain
  move, burst and trap), then snaps to the real board, so the picture can
  never create or remove a row.
- **Scoring** – 1 point per placed block; 100 / 250 / 450 / 700 for 1–4
  rows at once, plus 10 per cleared grain, combo multipliers for
  consecutive bursts, chain-reaction bonuses, +40 per crystal grain, +100 per
  crystal wall and +1,000 for clearing the whole board.
- **Special sand** (introduced level by level): heavy, sticky, explosive,
  rainbow, frozen, crystal, golden (coins), magnetic, volcanic, mystery.
- **Obstacles**: stone (two bursts), wooden barriers, frozen cells, locked
  cells (open after N rows), unbreakable blocks, sand traps (swallow three
  grains), crystal walls, moving barriers, and restricted cells where pieces
  can't be placed.
- **Power-ups**: Sand Sweep, Colour Blast, Sand Shaker, Row Clear, Block
  Crusher, Gravity Shift, Sand Bomb, Extra Move. Bought with coins, given
  for finishing worlds, or used once for free after an optional rewarded ad.
  Never needed: every level is proven winnable without them.
- **Modes**: Classic (endless, frozen and sticky sand appear as the score
  grows), Campaign (100 levels in six worlds: Candy Dunes, Crystal Desert,
  Ocean Sands, Sunset Valley, Mystic Forest, Cosmic Sands), Time Challenge
  (2 minutes, +4 s per row), Limited Moves (30 pieces to reach a target that
  rises as you win), Daily Puzzle (same for everyone on a date, streaks) and
  Endless Sand (special sands join as the score climbs).
- **Proven levels** – every campaign level was won by a bot when it was
  generated; its winning moves are stored and replayed by the tests.
  Daily puzzles are proven by the same bot on the phone before they are
  offered.
- **Rewards** – coins for rows, golden sand, levels (more for stars),
  daily wins and streaks, three daily missions and 22 achievements. The shop
  sells power-ups and looks only (8 board themes, 4 sand palettes, 4 grain
  styles, 4 burst effects, 3 piece styles); looks never change the game.
- **Help** – one free hint and one free undo per game, more with an
  optional rewarded ad; "Keep playing?" (clear the bottom three rows) once
  per game with an ad; double coins on the results with an ad.
- **Extras** (as in Block Burst Magic): splash screen held 1.5 s, welcome
  card with terms and privacy, tutorial with live demo boards, share a
  result card plus link, Google Play in-app rating at happy moments only,
  opt-in daily reminder, statistics, Settings with a Magivix Studio section,
  a privacy screen, and "Remove ads" (Google Play in-app purchase).

## Important: what has and hasn't been verified

This project was written in an environment that cannot run Flutter, so it is
compiled, analysed, tested and built by GitHub Actions, including on Android
emulators. Results, logs and screenshots are saved to the branches
`ci-logs-test`, `ci-logs-build`, `ci-logs-store-shots`,
`ci-logs-device-phone`, `ci-logs-device-small`, `ci-logs-device-play` and
`ci-logs-device-store`.

The rules exist twice: the Python reference model (`tool/reference_model/`)
generated and proved the levels, and `test/core/reference_test.dart`
requires the Dart engine to reproduce the model's recorded games turn by
turn (board, pieces, score, bot choices, power-ups).

### CI status (15 November 2026)

- Commit `439829f`: packages install, `dart format` clean, `flutter analyze`
  clean, **all unit and widget tests pass** (including the Python reference
  vectors and the replay of all 100 level proofs), release APK and App
  Bundle build (`com.sandburstmagic`, versionCode 1). Host-rendered store
  screenshots: all 8 captioned images made; one check failed on a pending
  save timer, fixed in the next commit.
- Commits after `439829f` (denser sand grains, burst screenshot, play time
  saved with other changes, docs, notification icon) have **not** been run:
  GitHub refused every job with "account is locked due to a billing issue".
- The on-device emulator tests have **not run yet** for the same reason.
  Once Actions works again, push `main` to `run-device-tests` (or start
  Actions → Device tests) and check the `ci-logs-device-*` branches.

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
  core/        Pure Dart rules (no Flutter): sand.dart (board, cells, shapes,
               settling, row bursts, layouts), engine.dart (config, dealing,
               turns, power-ups, bot), levels.dart (worlds, modes, daily;
               level_data.dart is generated), progression.dart (coins, shop,
               missions, achievements)
  data/        Versioned local saves (shared_preferences), models
  services/    Audio, haptics, ads (AdMob + consent), share, rating,
               reminders – all fail-safe
  state/       Controllers that connect rules, saves and UI
  ui/          Theme, sand renderer (game/board_fx.dart, sand_painter.dart),
               screens, share card
  l10n/        All user-facing text (ready for more languages)
test/          Unit, widget and reference-vector tests
integration_test/  On-device tests (device check, play session, store shots)
tool/          Python reference model and level generator, asset generators
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
  system backup can restore it). No global leaderboards.
- Daily puzzles and missions follow the device's local date. Without a
  server the game cannot verify the true date; moving the clock back pauses
  rewards instead.
- One game in progress is kept per mode. A Time Challenge clock is saved
  with the game but does not run while the app is closed.
- Only English text is included (the text system is ready for translations).
- iOS: the code is cross-platform, but the `ios/` folder is not included.
  Create it with `flutter create --platforms=ios .` and add your AdMob iOS
  App ID to `ios/Runner/Info.plist` (`GADApplicationIdentifier`).
- Frame times have not been measured on a low-end phone yet. The sand is
  drawn in a few batched calls per frame (about 2,500 grains at most) and
  burst particles use a fixed pool of 700, so it should hold up, but please
  check with `flutter run --profile`.
- Sounds and music are simple synthesised originals (the music loops are
  shared with Water Sort Magic); replace them with professionally produced,
  licensed audio if you like (same file names).
- Flame was not needed: the board is one CustomPainter fed by a small
  animation timeline and a particle pool.
