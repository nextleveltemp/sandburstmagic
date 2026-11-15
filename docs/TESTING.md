# Testing

## Automated tests

Run everything with `flutter test`. The suites:

| File | Covers |
| --- | --- |
| `test/core/reference_test.dart` | Against `test/fixtures/reference_vectors.json` from the Python model: random numbers, string hash, generated layouts, four whole bot games turn by turn (bot's choice, points, rows, animation phases, mystery reveals, full state), every power-up |
| `test/core/rules_test.dart` | Placement (sand falls, invalid and restricted placements change nothing, new set only after three pieces), sand movement (fall, diagonal slide, heavy, frozen, sticky, traps, nothing lost), row detection, single and multi-row clears and their points, sand settling after a clear, incomplete rows never clear, combo and chain scoring, explosive / stone / ice / lock rules, game over (no room, move limit, time), objectives, "Keep playing", every power-up and power-ups with nothing to do, fair dealing, save and restore |
| `test/core/levels_test.dart` | 100 levels in six worlds; every starting board settled with no complete row; goals and stars sane; **every stored solution replays to a win within its move limit**; mechanics introduced once each; daily puzzles deterministic and won by the bot |
| `test/core/progression_test.dart` | Coins, prices, cosmetics, missions, daily streak and clock protection, achievements, stars |
| `test/core/engagement_test.dart` | Rating prompt rules, reminder times, share-text helpers, interstitial frequency (every 2nd finished game, 60 s apart) |
| `test/data/persistence_test.dart` | Progress and saved games round-trip, broken data falls back to defaults, a restored level plays on to the same win |
| `test/state/game_controller_test.dart` | Winning level 1 pays coins and unlocks level 2; saving and resuming; free and rewarded hints and undo; power-ups from the inventory; Time Challenge clock; "Keep playing?" once; double coins once; cosmetics; the daily puzzle and its streak |
| `test/widget/app_flow_test.dart` | Welcome card; tutorial to home; Classic by taps (preview, then confirm), pause, home, Continue; drag a piece onto the board; level 1 intro card; buying in the shop |
| `test/app_info_test.dart` | Version, application ID and name the same everywhere; every declared asset exists; Play icon size |

## On-device tests (CI: `.github/workflows/device.yml`)

Run on Android 14 emulators when `main` is pushed to `run-device-tests` (or from Actions → Device tests):

| Job | What runs |
| --- | --- |
| phone | `device_smoke.sh`: the **release** APK with Google's test ads, driven with real Android touch input (launch, tutorial, Skip survives a restart, banner, a piece placed in Classic with real taps, Android's own audio and vibration logs, launcher label). Then `device_check_test.dart`. |
| small | `device_check_test.dart` on a 360 × 640 dp screen with three-button navigation |
| play | `playthrough_test.dart`: welcome card, tutorial, 25 Classic moves by taps, levels 1–3, Time Challenge, buying in the shop, interstitials only at natural breaks |
| store | `store_screens_test.dart`: raw screens for the Play listing (ads off, staged progress, clean status bar set once) |

`device_check_test.dart` uses real storage, real audio and Google's test
ads, in dark and light mode, and checks: every screen with screenshots;
that the last item of every scrolling screen clears the navigation bar;
banner ad; music actually playing; sound switches taking effect; reminders
(permission dialog answered, 7 scheduled, 0 after switching off); level 1
by finger taps with sound and vibration; refused pour; undo; hint; pause;
results; Android's share sheet; next level; no interstitial after the
first puzzle, one a moment after the second ends (closed by the watcher
like a player) and no second one when leaving its results;
a rewarded hint and a rewarded extra tube granted only after the reward;
progress and settings surviving a restart; Reset all progress through its
dialog; Daily, Relax and a challenge.

`device_watch.sh` takes the screenshots the test asks for (`SBMSHOT`),
closes full-screen ads like a player (it waits 35 s on rewarded ads so the
reward is earned), answers the notification permission dialog, closes the
share sheet with BACK, and answers Android's own "isn't responding" dialogs
before screenshots.

Google's consent SDK only allows ads in regions where consent is not
required (or after the form). The test registers the emulator as a consent
test device and simulates an unregulated region; this only works with
Google's test ad units and never affects real builds.

### Reference vectors

`test/fixtures/reference_vectors.json` is produced by the Python model in
`tool/reference_model/` (`python3 gen_vectors.py` there). If you change the
rules, the bot or the level content, change both implementations and
regenerate the vectors and the levels.

## Manual checklist (do on real phones)

- [ ] First launch: splash (~1.5 s), welcome card, tutorial with live demo
      boards; Skip works; "Start playing" leads home.
- [ ] Drag a piece: it floats above your finger, the preview shows green
      cells (or red where it can't go), it snaps on release.
- [ ] Tap a piece, tap the board: preview; tap again: placed. Tap elsewhere
      to move the preview first.
- [ ] Watch the block dissolve into grains that fall and slide; rows glow
      and burst; two rows at once shake the board and say "Double Burst!".
- [ ] Special sands and obstacles behave as their intro cards say (levels
      18, 20, 21, 24, 35, 37, 39, 40, 52, 54, 55, 56, 69–73, 85, 86).
- [ ] Power-ups: each one with and without stock (buy sheet, rewarded ad).
- [ ] Hint and undo: first free, then "Watch an ad".
- [ ] "Keep playing?" after running out of room in Classic, once.
- [ ] Results: score, best, rows, combo, coins, double coins, share, next.
- [ ] Time Challenge stops while paused; Limited Moves counts down.
- [ ] Daily Puzzle: same for two phones on the same date; streak.
- [ ] Shop: buy and use a board, sand colours, grains, bursts, pieces.
- [ ] Settings: sound, music, vibration, reduce motion, reminders, links.
- [ ] Close the app mid-game (swipe away): Continue resumes exactly.
- [ ] TalkBack: pieces, board and buttons are announced.
- [ ] Ads: banner only at the bottom of the game screen with a gap;
      interstitial about 1 s after every 2nd finished game, 60 s apart;
      rewarded only after tapping, reward only after watching.
- [ ] `flutter run --profile` on a low-end phone during big bursts.
