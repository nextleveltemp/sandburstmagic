#!/usr/bin/env bash
# Installs the release APK on the running emulator and checks that it:
#   1. starts and stays running (first launch shows the welcome card),
#   2. can save: after tapping "Accept" (then skipping the tutorial),
#      force-stopping and relaunching, the home screen (with "Play")
#      appears instead of the welcome card,
#   3. logs no crash, fatal signal or storage failure.
# Records logcat, screenshots and UI dumps into ci-out/. Never fails itself;
# the verdict is written to ci-out/RESULT.txt.
set -u
APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
PKG=com.sandburstmagic
OUT=ci-out
mkdir -p "$OUT"

shot() { adb exec-out screencap -p > "$OUT/screen-$1.png" 2>/dev/null; }
# Fresh UI dump (retries; removes the old file first, because a failed dump
# would otherwise leave the previous screen's dump in place).
dump_ui() {  # dump_ui <device path> <local file>
  for _ in 1 2 3 4 5; do
    adb shell rm -f "$1" > /dev/null 2>&1
    adb shell uiautomator dump "$1" > /dev/null 2>&1
    adb shell cat "$1" > "$2" 2>/dev/null
    grep -q '<hierarchy' "$2" && return 0
    sleep 2
  done
  return 1
}
# Reads the screen; a busy emulator keeps raising "isn't responding" dialogs
# (its launcher or system UI), so answer them and read again.
ui() {
  for _ in 1 2 3 4 5 6; do
    dump_ui /sdcard/ui.xml "$OUT/ui-$1.xml"
    grep -qiE "isn.t responding" "$OUT/ui-$1.xml" || return 0
    dismiss_system_dialogs
    sleep 3
  done
}
alive() { echo "$1 pid=$(adb shell pidof $PKG)" >> "$OUT/12-alive.txt"; }
# Dismisses "System UI isn't responding" style dialogs from the slow emulator.
dismiss_system_dialogs() {
  dump_ui /sdcard/d.xml "$OUT/.d.xml"
  if grep -q 'text="Wait"' "$OUT/.d.xml"; then
    b=$(tr '>' '\n' < "$OUT/.d.xml" | grep 'text="Wait"' |
      sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/')
    set -- $b
    [ $# -eq 4 ] && adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
    echo "dismissed a system dialog" >> "$OUT/12-alive.txt"
  fi
}
# Taps the first UI node whose text or desc matches. A busy emulator keeps
# raising "isn't responding" dialogs over the game: answer them and retry.
tap_text() {  # tap_text <label>
  for _ in 1 2 3 4; do
    dismiss_system_dialogs
    if tap_text_once "$1"; then return 0; fi
    sleep 3
  done
  return 1
}
tap_text_once() {
  dump_ui /sdcard/t.xml "$OUT/.t.xml"
  b=$(tr '>' '\n' < "$OUT/.t.xml" |
    grep -E "(text|content-desc)=\"$1\"" | head -n1 |
    sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/')
  set -- $b
  if [ $# -eq 4 ]; then
    adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
    return 0
  fi
  return 1
}

adb wait-for-device
# Let the freshly booted emulator settle; its own apps (launcher, Play
# services) are slow at first and often show "isn't responding" dialogs.
sleep 90
dismiss_system_dialogs
sleep 5
dismiss_system_dialogs
adb shell getprop ro.build.version.release > "$OUT/device.txt" 2>&1
adb shell getprop ro.product.cpu.abilist >> "$OUT/device.txt" 2>&1
adb install -r "$APK" > "$OUT/10-install.txt" 2>&1
adb logcat -c
adb logcat -v threadtime > "$OUT/20-logcat-full.txt" 2>&1 &
LOGPID=$!

# ---- 1. first launch -------------------------------------------------------
adb shell am start -W -n "$PKG/.MainActivity" > "$OUT/11-start.txt" 2>&1
sleep 8; shot first-8s; alive first-8s
sleep 10; dismiss_system_dialogs; shot first-18s; alive first-18s; ui first

# ---- 2. accept the welcome card, skip the tutorial, restart, expect home --
dismiss_system_dialogs
if grep -q 'Welcome to Sand Burst Magic' "$OUT/ui-first.xml"; then welcome_first=1; else welcome_first=0; fi
if tap_text "Accept"; then accepted=1; else accepted=0; fi
sleep 5; shot after-accept; ui after-accept
# First launch: the tutorial follows Accept; skip it.
if tap_text "Skip"; then tutorial_after_accept=1; else tutorial_after_accept=0; fi
sleep 5; shot after-skip; ui after-skip
if grep -q 'Play' "$OUT/ui-after-skip.xml"; then home_after_accept=1; else home_after_accept=0; fi
sleep 3   # writes are asynchronous; give them a moment
adb shell am force-stop "$PKG"
sleep 2
adb shell am start -W -n "$PKG/.MainActivity" >> "$OUT/11-start.txt" 2>&1
sleep 10; dismiss_system_dialogs; shot relaunch; alive relaunch; ui relaunch
if grep -q 'Welcome to Sand Burst Magic' "$OUT/ui-relaunch.xml"; then welcome_again=1; else welcome_again=0; fi
if grep -q 'Play' "$OUT/ui-relaunch.xml"; then home_relaunch=1; else home_relaunch=0; fi

# ---- 3. no banner on the home screen any more ------------------------------
sleep 25; dismiss_system_dialogs; shot home-ads; ui home-ads
if grep -qE 'android.webkit.WebView|AdView|Test Ad' "$OUT/ui-home-ads.xml"; then home_banner=1; else home_banner=0; fi

# ---- 4. Android's own record of our audio (music on the home screen) -------
APPUID=$(adb shell pm list packages -U "$PKG" | sed -E 's/.*uid:([0-9]+).*/\1/' | tr -d '\r')
adb shell dumpsys audio > "$OUT/30-dumpsys-audio-home.txt" 2>&1

# ---- 5. start Classic and place a piece with real touch taps -------------
# Tap the first tray piece, then the middle of the board twice (the first
# tap shows where the piece goes, the second places it), and check that the
# score (screen-reader label "Score N") moved above 0.
if tap_text 'Play\. Classic[^"]*'; then played=1; else played=0; fi
sleep 6; dismiss_system_dialogs; shot game; alive game; ui game
# The banner sits at the bottom of the game screen; give it time to load.
sleep 15; ui game-ad; shot game-ad
if grep -qE 'android.webkit.WebView|AdView|Test Ad' "$OUT/ui-game-ad.xml"; then banner=1; else banner=0; fi
src_line=$(tr '>' '\n' < "$OUT/ui-game.xml" | grep -E 'content-desc="Piece 1:' | head -n1)
dst_line=$(tr '>' '\n' < "$OUT/ui-game.xml" | grep -E 'content-desc="Game board' | head -n1)
poured=0
if [ -n "$src_line" ] && [ -n "$dst_line" ]; then
  read -r sx1 sy1 sx2 sy2 <<< "$(echo "$src_line" | sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/')"
  read -r dx1 dy1 dx2 dy2 <<< "$(echo "$dst_line" | sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/')"
  sx=$(( (sx1 + sx2) / 2 )); sy=$(( (sy1 + sy2) / 2 ))
  dx=$(( (dx1 + dx2) / 2 )); dy=$(( (dy1 + dy2) / 2 ))
  echo "tap $sx $sy then $dx $dy twice" > "$OUT/31-place.txt"
  adb shell input tap $sx $sy
  sleep 1
  adb shell input tap $dx $dy
  sleep 1
  adb shell input tap $dx $dy
  sleep 3; shot after-place; ui after-place
  # Android's audio record right after the placement sound.
  adb shell dumpsys audio > "$OUT/32-dumpsys-audio-game.txt" 2>&1
  for attempt in 1 2 3; do
    if grep -qE 'content-desc="Score [1-9]' "$OUT/ui-after-place.xml"; then poured=1; break; fi
    echo "attempt $attempt: score not found yet" >> "$OUT/31-place.txt"
    sleep 2; ui after-place
  done
fi
# Android's vibration log (the emulator has a virtual vibrator).
adb shell dumpsys vibrator_manager > "$OUT/35-vibrator.txt" 2>&1
if grep -q "$PKG" "$OUT/35-vibrator.txt"; then haptics_os=1; else haptics_os=0; fi

# Installed icon and label in the launcher's app list.
adb shell input keyevent KEYCODE_HOME
sleep 3
shot launcher-home
adb shell input swipe 540 1900 540 500 300
sleep 3
shot launcher-apps
adb shell rm -f /sdcard/apps.xml < /dev/null > /dev/null 2>&1
adb shell uiautomator dump /sdcard/apps.xml < /dev/null > /dev/null 2>&1
launcher_label="$(adb shell cat /sdcard/apps.xml < /dev/null 2>/dev/null | tr '>' '\n' |
  grep -oE '(text|content-desc)="Sand Burst[^"]*"' | head -n1)"
adb shell input keyevent KEYCODE_HOME

grep -E "u/pid:${APPUID}/|uid/pid:${APPUID}/|uid:${APPUID} " "$OUT/30-dumpsys-audio-home.txt" "$OUT/32-dumpsys-audio-game.txt" \
  2>/dev/null > "$OUT/33-audio-our-app.txt"
# Android logs "player piid:N event:started" when one of our players starts.
sound_os=0
for piid in $(grep -oE 'piid:[0-9]+' "$OUT/33-audio-our-app.txt" | sort -u | cut -d: -f2); do
  if grep -qE "piid:${piid} event:started" "$OUT/30-dumpsys-audio-home.txt" "$OUT/32-dumpsys-audio-game.txt" 2>/dev/null; then
    sound_os=1
    grep -hE "piid:${piid} (event:started|format update)" "$OUT/32-dumpsys-audio-game.txt" >> "$OUT/34-audio-events.txt" 2>/dev/null
  fi
done

kill $LOGPID 2>/dev/null
adb logcat -d -b crash > "$OUT/21-logcat-crash.txt" 2>&1
grep -E "AndroidRuntime|FATAL|flutter|Flutter|libc |$PKG" \
  "$OUT/20-logcat-full.txt" | tail -n 1500 > "$OUT/22-logcat-relevant.txt"
tail -n 20000 "$OUT/20-logcat-full.txt" > "$OUT/20.tmp" && mv "$OUT/20.tmp" "$OUT/20-logcat-full.txt"

crash=0
# Only the game's own process counts (test tools such as uiautomator can
# crash on a busy emulator without affecting the app).
grep -A1 "FATAL EXCEPTION" "$OUT/20-logcat-full.txt" | grep -q "Process: $PKG" && crash=1
grep -E "Fatal signal" "$OUT/20-logcat-full.txt" | grep -q "$PKG" && crash=1
grep -q "ANR in $PKG" "$OUT/20-logcat-full.txt" && crash=1
grep -q "pid=$" "$OUT/12-alive.txt" && crash=1
storage_failed=0
grep -q "Persistent storage unavailable" "$OUT/20-logcat-full.txt" && storage_failed=1

ok=1
[ $crash -eq 0 ] || ok=0
[ $storage_failed -eq 0 ] || ok=0
[ $welcome_first -eq 1 ] || ok=0
[ $accepted -eq 1 ] || ok=0
[ $tutorial_after_accept -eq 1 ] || ok=0
[ $home_relaunch -eq 1 ] || ok=0
[ $welcome_again -eq 0 ] || ok=0
[ $poured -eq 1 ] || ok=0
{
  echo "app_ok=$ok"
  echo "crash=$crash storage_failed=$storage_failed"
  echo "welcome_first=$welcome_first accepted=$accepted tutorial_after_accept=$tutorial_after_accept home_after_tutorial=$home_after_accept"
  echo "home_relaunch=$home_relaunch welcome_again=$welcome_again played=$played home_banner=$home_banner"
  echo "game_banner=$banner real_touch_place=$poured sound_in_android_audio_log=$sound_os haptics_in_android_log=${haptics_os:-0} uid=$APPUID"
  echo "installed_package=$(adb shell pm list packages < /dev/null | grep -o "package:$PKG\$" | head -n1) launcher_label=${launcher_label:-not-found}"
  cat "$OUT/12-alive.txt"
} > "$OUT/RESULT.txt"
exit 0
