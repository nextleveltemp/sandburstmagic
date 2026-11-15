# Assets

All assets are original or openly licensed and stored in the project; nothing
is loaded from the internet.

## Fonts

`assets/fonts/Outfit-*.ttf` – the **Outfit** typeface, © 2021 The Outfit
Project Authors (Smartsheet Inc, Rodrigo Fuenzalida), licensed under the SIL
Open Font License 1.1 (`assets/fonts/OFL.txt`). The same files as in Block
Burst Magic.

## Sounds and music

`assets/audio/sfx/*.ogg` (13 effects) and `assets/audio/music/*.ogg` (`main`
and `relax` loops) were synthesised by `tool/generate_audio.py` (effects)
and `tool/generate_music.py` (music).

The sand effects are granular: thousands of tiny randomly timed clicks
through a band-pass filter, thinning out like settling sand. Bursts add a
rising filtered-noise whoosh and struck-glass sparkles; combos add a quick
rising arpeggio. A synthetic reverb gives everything a small room.

The music loops are the studio's warm pads with soft bell arpeggios, shared
with Water Sort Magic (`main` in menus, `relax` during games).

No samples or third-party audio are used; there is nothing to license.

Regenerate: `python3 tool/generate_audio.py` (needs `numpy`, `scipy` and
`ffmpeg` with libvorbis; `--preview DIR` also writes MP3 copies) and
`python3 tool/generate_music.py` (needs `numpy` and `ffmpeg`). Both are
deterministic: the decoded audio comes out identical (the Ogg files differ
only in a random stream number).

To replace them with professionally produced audio, keep the same file names
and format (Ogg Vorbis, mono is fine). Effects should be short (under about
3 s) and normalised to similar loudness; music should loop seamlessly.

| File | Plays when |
| --- | --- |
| `select.ogg` | A piece is picked up |
| `place.ogg` | A piece lands (soft thud and a sand hiss) |
| `sand.ogg` | A sand trickle (spare effect) |
| `invalid.ogg` | A placement or power-up is not possible |
| `burst.ogg` | A row bursts |
| `combo.ogg` | Two or more rows at once, or a combo of 3+ |
| `power.ogg` | A power-up is used |
| `win.ogg` | A level, target or daily puzzle is won |
| `over.ogg` | A game ends (no room, no moves, time up) |
| `undo.ogg` | A move is taken back |
| `hint.ogg` | A hint appears |
| `achievement.ogg` | An achievement unlocks |
| `button.ogg` | Menu buttons |

## Icons and store graphics

**Source artwork:** `tool/icon_source/sand_burst_magic_icon_master.png` is the
official Sand Burst Magic icon exactly as supplied (1254 × 1254 px, RGB,
SHA-256 `f3d62407…cfcf3aa7`). Never edit it; every icon file below is
generated from it by `tool/generate_icons.py` (needs Pillow and numpy):

```bash
python3 tool/generate_icons.py
```

| Output | Size | Use |
| --- | --- | --- |
| `store/icon-512.png` | 512 × 512, 32-bit RGBA | **Google Play icon.** The master downscaled with no other change (Play applies its own rounded mask). |
| `store/feature-graphic-1024x500.png` | 1024 × 500 | Play feature graphic (artwork + wordmark) |
| `mipmap-*/ic_launcher_foreground.png` | 108 dp | Adaptive icon foreground (Android 8+) |
| `mipmap-*/ic_launcher_background.png` | 108 dp | Adaptive icon background in the artwork's navy |
| `mipmap-*/ic_launcher_monochrome.png` | 108 dp | Themed icon (Android 13+): the T piece, falling grains and the dune as flat shapes |
| `mipmap-*/ic_launcher.png` | 48 dp | Legacy icon (Android 7.x): the full artwork |
| `mipmap-*/ic_launcher_round.png` | 48 dp | Legacy round icon (Android 7.1) |
| `drawable-*/splash_mark.png` | 128 dp | Launch screen on Android 7–11 |
| `mipmap-anydpi-v26/ic_launcher*.xml` | – | Adaptive icon definitions |
| `drawable/ic_stat_sandburstmagic.xml` | 24 dp vector | Reminder notification icon |
| `tool/icon_source/preview-masks.png` | – | Check image: the icon under four launcher masks, at 48 px, and the themed icon |

Densities: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi (×1, 1.5, 2, 3, 4).

**Mask safety.** Launchers crop adaptive icons to their own shape, but only
the central 66 dp circle of the 108 dp layer is guaranteed visible. The neon
frame's farthest points (its rounded corners, about 709 px from the centre of
the master) are placed 31.5 dp from the centre, inside that circle. So the
piece, the sand and the complete frame show under circle, squircle, rounded-square and
teardrop masks (see `preview-masks.png`). Outside the frame, the artwork's
navy surround fades into a background layer sampled from the same colours,
so there is no seam. On Android 12+, the system splash screen also uses the
adaptive foreground; the app holds the launch screen for at least 1.5 s.

**Replacing the icon later:** put the new square artwork (at least 1024 px)
at `tool/icon_source/sand_burst_magic_icon_master.png`, update the frame
measurements and themed-icon geometry at the top of
`tool/generate_icons.py` if the layout changed, run the script, and check
`preview-masks.png`.

**Store screenshots:** the CI "store" job captures raw screens;
`python3 tool/store_screenshots.py <folder with store-S*.png>` writes the
captioned 1080 × 1920 (9:16) images to `store/screenshots/`.
