# Testing

## Automated tests

Run everything with `flutter test`. The suites:

| File | Covers |
| --- | --- |
| `test/core/board_test.dart` | Valid pours (empty tube, same colour, the design example, contiguous runs, partial fill, order kept); invalid pours (other colour, full, from empty, same tube, out of range) change nothing; completion (solved, initially solved, partly solved, one colour but not full, empty tubes, several completed tubes); encoding and validation of malformed positions; canonical keys; useful pours |
| `test/core/engine_test.dart` | Selection rules (select, ignore empty, deselect, attempt pour); engine pours, history, invalid pours; winning; undo once and several times with exact boards and counts; undo limits; restart; move limits (failure); history cap; extra tube (once, undo still works); hints spent/granted; stuck detection; hints are legal, don't modify the board, solve levels when followed, work off the stored path; proven dead end vs search timeout; tutorial script |
| `test/core/levels_test.dart` | 300 levels: valid positions, none starts solved, **every stored solution replays to a solved board**, no duplicates (levels and challenges), difficulty order, colour growth; Dart exact A* re-proves par on a sample; fast solver on the largest levels; star thresholds; ≥ 30 challenges, every objective met by its solution |
| `test/core/reference_test.dart` | Against `test/fixtures/reference_vectors.json` from the Python model: random numbers, hash, deals, pours, useful pours, solver (same status, solution and effort), Daily and Relax puzzles, star thresholds |
| `test/core/progression_test.dart` | Player level curve, XP rules, level records never get worse, every achievement condition, no double awards, daily streaks, once-per-date rewards, clock rollback, date keys, theme unlocks |
| `test/core/engagement_test.dart` | Rating prompt rules, reminder times, share-text helpers, interstitial frequency (not after the first puzzle, then every puzzle, 60 s apart) |
| `test/data/persistence_test.dart` | DocStore: save/restore, missing data, malformed data → backup, garbage → defaults, migration, newer-version data never overwritten, invalid values never saved. Models: tolerant settings, progress round trip, interrupted puzzle resumes exactly (with undo), corrupt and mismatched saves rejected, finished puzzles not resumed, cached daily checked |
| `test/state/controllers_test.dart` | Taps through the controller; rapid taps never pour twice; level unlocks, records, replays never lower results; saving and resuming; replays don't replace the current save; hints; rewards only when the ad reports them; failed ads don't block; double XP; challenge failure and unlocking; undo limits; daily rewarded once, cache, clock rollback; Relax; reset; sessions |
| `test/app_info_test.dart` | Version matches `pubspec.yaml`; application ID and name the same everywhere; all assets exist; Play icon is 512 × 512 |
| `test/widget/app_flow_test.dart` | Home and settings persistence; tutorial skip and full walkthrough; level 1 by taps (select, deselect, refused pour with explanation, pour, undo, solve, results, next level); restart confirmation; back keeps the puzzle; hint; themes; daily; challenges; locked levels; small phone with large text; result card PNG shared |

## On-device tests (CI: `.github/workflows/device.yml`)

Run on Android 14 emulators on every push to `main`:

| Job | What runs |
| --- | --- |
| phone | `device_smoke.sh`: the **release** APK with Google's test ads, driven with real Android touch input (launch, tutorial, Skip survives a restart, banner, two taps that pour in level 1, Android's own audio and vibration logs, launcher label). Then `device_check_test.dart`. |
| small | `device_check_test.dart` on a 360 × 640 dp screen with three-button navigation |
| play | `playthrough_test.dart`: tutorial, levels 1–8, a hint and an undo, the Daily Puzzle, a Relax puzzle, challenge 1, a theme change, interstitials only at natural breaks |
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
rules, the solver or the generator, change both implementations and
regenerate the vectors and the levels.

## Manual checklist (do on real phones)

- [ ] First launch: splash with the icon (~1.5 s), tutorial appears; Skip
      works; every step can be followed; "Start playing" leads home.
- [ ] Tap a tube: it lifts with an outline and a chevron. Tap it again: it
      drops. Tap an empty tube with nothing selected: nothing happens.
- [ ] Pour onto the same colour and into an empty tube; watch the tilt,
      stream and levels. Tap quickly between tubes: nothing breaks.
- [ ] Refused pour: target shakes gently, source stays selected.
- [ ] Undo several times; Restart asks first; Hint shows an arrow.
- [ ] Finish a level: stars, pours, best, XP; Next level, Replay, Home.
- [ ] Leave mid-level with Back, kill the app, reopen: "Continue level N".
- [ ] Daily: play, solve once (reward), replay (no reward), streak display.
- [ ] Challenges: lock/unlock, pour limit failure, undo limit, no hints.
- [ ] Relax: calm music, no stars, "Another puzzle".
- [ ] Settings: each switch works and survives a restart; light theme
      readable; Reduce motion removes tilting and sparkles; Colour symbols
      show shapes; Reset requires typing RESET.
- [ ] Sound and vibration off → game fully playable.
- [ ] TalkBack on: tubes are announced with their contents; taps work.
- [ ] Largest system font size: no clipped essential text.
- [ ] Airplane mode: everything except ads works.
- [ ] Ads: banner only at the bottom of the puzzle screen; interstitial
      about 1 s after a puzzle ends (not after the very first), once per
      puzzle, never on Restart; rewarded only after tapping, reward only after
      finishing the ad; consent form in an EEA region (VPN or UMP debug
      geography).
- [ ] Small phone (≈ 5″), tall phone, tablet; gesture and 3-button navigation.
- [ ] `flutter run --profile` and check frame times while pouring.
