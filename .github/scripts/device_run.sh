#!/usr/bin/env bash
# Runs inside the emulator step of .github/workflows/device.yml.
#   device_run.sh <name> <smoke:true|false>
# 1. (smoke=true) release APK checks by real touches: device_smoke.sh
# 2. full on-device Dart test with real storage, audio and test ads, with
#    device_watch.sh taking screenshots and closing full-screen ads.
set -u
NAME="$1"
SMOKE="$2"
TEST="${3:-integration_test/device_check_test.dart}"
OUT=ci-out
mkdir -p "$OUT"
: > "$OUT/RESULT.txt"

resources() { { echo "== $1"; free -m; df -h / | tail -n1; } >> "$OUT/resources.txt" 2>&1; }

adb wait-for-device

# Diagnostics for an emulator that disappears mid-run ("device offline"):
# host memory and whether the emulator process is still there, every 15 s,
# and the device log streamed live (it can't be read once the device died).
(
  while true; do
    echo "$(date +%T) $(free -m | awk '/Mem:/ {print "used="$3" avail="$7}') $(free -m | awk '/Swap:/ {print "swap="$3}') emu=$(pgrep -fc 'qemu-system|emulator' ) adbserver=$(pgrep -f 'adb.*fork-server' | tr '\n' ',') adb=$(timeout 5 adb get-state 2>&1)"
    sleep 15
  done
) > "$OUT/host-monitor.txt" 2>&1 &
MON=$!
adb logcat -c 2>/dev/null
adb logcat -v threadtime > "$OUT/.logcat-live.txt" 2>&1 &
LIVE=$!
adb shell wm size >> "$OUT/device.txt" 2>&1
adb shell wm density >> "$OUT/device.txt" 2>&1
resources start
# The small emulator uses three-button navigation (a taller bar than the
# gesture handle), so both navigation modes are covered.
if [ "$NAME" = "small" ]; then
  adb shell cmd overlay enable-exclusive --category com.android.internal.systemui.navbar.threebutton >> "$OUT/device.txt" 2>&1
  sleep 3
fi
adb shell cmd overlay list 2>/dev/null | grep -i "navbar" >> "$OUT/device.txt"

if [ "$NAME" = "store" ]; then
  # Store screenshots: animations on (celebrations), and Android's demo
  # mode for a clean status bar (fixed clock, full battery and signal).
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb shell settings put global $k 1
  done
  adb shell settings put global sysui_demo_allowed 1
  demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" > /dev/null; }
  adb shell settings put system show_touches 0
  adb shell settings put system pointer_location 0
  demo_all() {
    demo enter
    demo clock -e hhmm 0941
    demo battery -e level 100 -e plugged false
    demo network -e wifi show -e level 4 -e fully true
    demo network -e mobile show -e datatype none -e level 4
    demo notifications -e visible false
  }
  # Once, after System UI has settled (repeating it made System UI hang).
  sleep 25
  demo_all
  adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >> "$OUT/device.txt" 2>&1
  echo "store: demo mode on" >> "$OUT/device.txt"
fi

if [ "$SMOKE" = "true" ]; then
  bash .github/scripts/device_smoke.sh build/app/outputs/flutter-apk/app-release.apk
  mv "$OUT/RESULT.txt" "$OUT/RESULT-smoke.txt"
  # Remove the release build so the test build installs cleanly.
  adb uninstall com.sandburstmagic > /dev/null 2>&1
  resources after-smoke
  bash .github/scripts/save_logs.sh "ci-logs-device-${NAME}"
fi

DEVICE=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
TESTLOG="$OUT/40-integration-${NAME}.txt"
: > "$TESTLOG"
IDLE=0; [ "$NAME" = "play" ] && IDLE=1
OUT="$OUT" IDLE_DISMISS=$IDLE bash .github/scripts/device_watch.sh "${NAME}-" "$TESTLOG" &
WATCH=$!
set -o pipefail
flutter test "$TEST" -d "$DEVICE" --reporter expanded 2>&1 |
  tee "$TESTLOG" > /dev/null
itest=${PIPESTATUS[0]}
# A broken SDK download (e.g. the NDK) fails the build before any test
# runs: remove the partial download and build once more.
if [ "$itest" != 0 ] && grep -qE "Gradle task assembleDebug failed|Error on ZipFile" "$TESTLOG"; then
  echo "== build failed before the tests; retrying once" >> "$TESTLOG"
  rm -rf "${ANDROID_SDK_ROOT:-$ANDROID_HOME}/ndk/"*.temp "${ANDROID_SDK_ROOT:-$ANDROID_HOME}/.temp" 2>/dev/null
  for d in "${ANDROID_SDK_ROOT:-$ANDROID_HOME}"/ndk/*; do
    [ -f "$d/source.properties" ] || rm -rf "$d"
  done
  flutter test "$TEST" -d "$DEVICE" --reporter expanded 2>&1 |
    tee -a "$TESTLOG" > /dev/null
  itest=${PIPESTATUS[0]}
fi
sleep 3
kill $WATCH $MON $LIVE 2>/dev/null
# The device log up to the end (or the moment the device was lost), and
# whether the host killed anything for lack of memory.
tail -n 4000 "$OUT/.logcat-live.txt" > "$OUT/logcat-live-tail.txt" 2>/dev/null
grep -iE "AndroidRuntime|FATAL|lowmemorykiller|am_kill|am_proc_died|ActivityManager: (Process|Killing)|E/flutter|F/libc|Abort message|sandburstmagic.*(died|crash)" "$OUT/.logcat-live.txt" | tail -n 300 > "$OUT/app-exit.txt" 2>/dev/null
rm -f "$OUT/.logcat-live.txt"
sudo -n dmesg -T 2>/dev/null | grep -iE "oom|killed process|out of memory|qemu|segfault" | tail -n 60 > "$OUT/host-dmesg.txt"
adb get-state > "$OUT/device-state-at-end.txt" 2>&1
pkill -f "tail -n +1 -F $TESTLOG" 2>/dev/null
pkill -f device_watch.sh 2>/dev/null
{
  echo "integration_test_${NAME}=$itest"
  grep -E "^[0-9:]+ \+[0-9]+.*(All tests passed|Some tests failed)" "$OUT/40-integration-${NAME}.txt" | tail -n1
  [ -f "$OUT/RESULT-smoke.txt" ] && cat "$OUT/RESULT-smoke.txt"
} > "$OUT/RESULT.txt"
resources end
# Which apps Android reported as not responding (if any). Our own app must
# never be one of them (the dialogs are hidden, so this is the check).
timeout 60 adb logcat -d -b events | grep -E "am_anr" > "$OUT/anr-events.txt" 2>&1
echo "own_anr=$(grep -c 'com.sandburstmagic' "$OUT/anr-events.txt")" >> "$OUT/RESULT.txt"
cat "$OUT/RESULT.txt"
timeout 60 adb logcat -d | grep -iE "UserMessagingPlatform|addTestDeviceHashedId|ConsentDebugSettings" | tail -n 50 > "$OUT/ump-log.txt" 2>&1
bash .github/scripts/save_logs.sh "ci-logs-device-${NAME}"
exit 0
