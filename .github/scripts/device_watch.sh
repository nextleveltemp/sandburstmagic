#!/usr/bin/env bash
# Companion for integration_test/device_check_test.dart on an emulator.
#  * "SBMSHOT <name>" in the Flutter log  -> screenshot ci-out/shots/<prefix><name>.png
#  * "SBMAD begin <kind>" ... "SBMAD end" -> acts like a player on the
#    full-screen ad: waits until the ad can be closed (35 s for rewarded,
#    so the reward is earned), then taps its close button. If the ad asks
#    "close and lose the reward?", it taps "Resume" instead.
# Usage: device_watch.sh <prefix> <test-output-file>   (runs until killed)
set -u
PREFIX="${1:-}"
SOURCE="${2:?test output file}"
OUT="${OUT:-ci-out}"
mkdir -p "$OUT/shots" "$OUT/addumps"
STATE="$OUT/.adstate"
rm -f "$STATE"

center_of() {  # reads a uiautomator XML node line on stdin, prints "x y"
  sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/' |
    awk '{ printf "%d %d\n", ($1+$3)/2, ($2+$4)/2 }'
}

ad_closer() {
  local last_tap=0 last_check=0 last_ad_check=0
  while true; do
    if [ ! -f "$STATE" ]; then
      # A full-screen ad the test did not announce (e.g. an interstitial on
      # "Home" between games) is closed the same way.
      now=$(date +%s)
      if [ $((now - last_ad_check)) -ge 3 ]; then
        last_ad_check=$now
        if adb shell dumpsys activity activities < /dev/null 2>/dev/null | grep -m1 -E 'topResumedActivity|mResumedActivity' | grep -q AdActivity; then
          echo "auto $now" > "$STATE"
          echo "$(date +%T) unannounced full-screen ad on top" >> "$OUT/ad-actions.txt"
          continue
        fi
      fi
      # Outside ads (only when IDLE_DISMISS=1): answer Android's own "isn't
      # responding" dialogs (the busy emulator's launcher/system UI) with
      # "Wait" so they don't cover the game. Reading the screen this way
      # switches Flutter's accessibility on, which short tests flag, so
      # it is used for the long play session only.
      now=$(date +%s)
      if [ "${IDLE_DISMISS:-0}" = "1" ] && [ $((now - last_check)) -ge 8 ]; then
        last_check=$now
        adb shell rm -f /sdcard/idle.xml < /dev/null > /dev/null 2>&1
        adb shell uiautomator dump /sdcard/idle.xml < /dev/null > /dev/null 2>&1
        idle="$(adb shell cat /sdcard/idle.xml < /dev/null 2>/dev/null | tr '>' '\n')"
        if echo "$idle" | grep -qiE "isn.t responding"; then
          w="$(echo "$idle" | grep -E 'text="Wait"' | head -n1)"
          if [ -n "$w" ]; then
            who="$(echo "$idle" | grep -oiE 'text="[^"]*isn.t responding[^"]*"' | head -n1)"
            adb shell input tap $(echo "$w" | center_of) < /dev/null
            echo "$(date +%T) dismissed a system 'not responding' dialog: $who" >> "$OUT/ad-actions.txt"
          fi
        fi
      fi
      sleep 1
      continue
    fi
    read -r kind since < "$STATE" || { sleep 1; continue; }
    now=$(date +%s); el=$((now - since))
    min=6; [ "$kind" = rewarded ] && min=35
    if [ "$el" -lt "$min" ] || [ $((now - last_tap)) -lt 4 ]; then sleep 1; continue; fi
    dump="$OUT/addumps/${PREFIX}${kind}-${el}s.xml"
    adb shell rm -f /sdcard/ad.xml < /dev/null > /dev/null 2>&1
    adb shell uiautomator dump /sdcard/ad.xml < /dev/null > /dev/null 2>&1
    adb shell cat /sdcard/ad.xml < /dev/null > "$dump" 2>/dev/null
    nodes="$(tr '>' '\n' < "$dump" | grep 'bounds=' || true)"
    top="$(adb shell dumpsys activity activities < /dev/null | grep -m1 -E 'topResumedActivity|mResumedActivity')"
    # A tap that landed on the ad itself opens the advertiser's page in
    # another app (usually Chrome): go back to the game first.
    if [ -n "$top" ] && ! echo "$top" | grep -q "com.sandburstmagic/"; then
      echo "$(date +%T) $kind t=${el}s ad click-through, back to the game :: $top" >> "$OUT/ad-actions.txt"
      adb shell input keyevent KEYCODE_BACK < /dev/null
      sleep 2
      top="$(adb shell dumpsys activity activities < /dev/null | grep -m1 -E 'topResumedActivity|mResumedActivity')"
      if ! echo "$top" | grep -q "com.sandburstmagic/"; then
        adb shell am start -n com.sandburstmagic/.MainActivity < /dev/null > /dev/null 2>&1
        sleep 2
      fi
      last_tap=$now
      continue
    fi
    if [ "$kind" = auto ] && ! echo "$top" | grep -q AdActivity; then
      rm -f "$STATE"
      echo "$(date +%T) unannounced ad closed" >> "$OUT/ad-actions.txt"
      continue
    fi
    target=""
    if echo "$nodes" | grep -qiE "isn.t responding"; then
      # Android's "app isn't responding" dialog (slow emulator): keep waiting.
      target="$(echo "$nodes" | grep -E 'text="Wait"' | head -n1)"
    elif echo "$top" | grep -q "AdActivity"; then
      adb exec-out screencap -p < /dev/null > "$OUT/shots/${PREFIX}ad-${kind}-${el}s.png" 2>/dev/null
      target="$(echo "$nodes" | grep -iE '(text|content-desc)="[^"]*resume[^"]*"' | head -n1)"
      [ -z "$target" ] && target="$(echo "$nodes" | grep -E '(text|content-desc)="Close"' | head -n1)"
      [ -z "$target" ] && target="$(echo "$nodes" | grep -iE '(text|content-desc)="[^"]*(close|skip|dismiss)[^"]*"' | grep -viE 'close app' | head -n1)"
      if [ -z "$target" ] && [ "$el" -gt 75 ]; then
        echo "$(date +%T) $kind t=${el}s ad has no close button, pressing BACK" >> "$OUT/ad-actions.txt"
        adb shell input keyevent KEYCODE_BACK < /dev/null
        last_tap=$now
      fi
    fi
    if [ -n "$target" ]; then
      xy="$(echo "$target" | center_of)"
      echo "$(date +%T) $kind t=${el}s tap $xy :: $(echo "$target" | grep -oE '(text|content-desc)="[^"]*"' | tr '\n' ' ')" >> "$OUT/ad-actions.txt"
      adb shell input tap $xy < /dev/null
      last_tap=$now
    fi
    sleep 2
  done
}

ad_closer &
CLOSER=$!
trap 'kill $CLOSER 2>/dev/null' EXIT

# Follow the test's console output (it contains the SBM markers).
tail -n +1 -F "$SOURCE" 2>/dev/null | while IFS= read -r line; do
  case "$line" in
    *SBMSHOT*)
      name="$(echo "${line##*SBMSHOT }" | tr -cd 'A-Za-z0-9_-')"
      # An Android "isn't responding" dialog (busy emulator) would cover the
      # screenshot: answer it with "Wait" first. Only then is the screen read.
      for try in 1 2 3; do
        adb shell dumpsys window < /dev/null 2>/dev/null | grep -m1 mCurrentFocus | grep -qi "not responding" || break
        adb shell uiautomator dump /sdcard/anr.xml < /dev/null > /dev/null 2>&1
        w="$(adb shell cat /sdcard/anr.xml < /dev/null 2>/dev/null | tr '>' '\n' | grep -E 'text="Wait"' | head -n1)"
        [ -n "$w" ] && adb shell input tap $(echo "$w" | center_of) < /dev/null
        echo "$(date +%T) answered 'not responding' before shot $name" >> "$OUT/${PREFIX}watch.txt"
        sleep 2
      done
      adb exec-out screencap -p > "$OUT/shots/${PREFIX}${name}.png" 2>/dev/null < /dev/null
      # Tell the test the picture is taken (it waits for this file), so the
      # screen never changes before the capture.
      adb shell "run-as com.sandburstmagic sh -c 'mkdir -p files && touch files/sbm-shot-$name'" < /dev/null > /dev/null 2>&1
      echo "$(date +%T) shot $name" >> "$OUT/${PREFIX}watch.txt" ;;
    *"SBMAD begin"*)
      kind="$(echo "${line##*SBMAD begin }" | tr -cd 'a-z')"
      echo "$kind $(date +%s)" > "$STATE"
      echo "$(date +%T) ad begin $kind" >> "$OUT/${PREFIX}watch.txt" ;;
    *SBMBACK*)
      # Close a system sheet (share chooser) with BACK, but only if it is on
      # top: BACK in the game itself would leave the screen.
      sleep 1
      top="$(adb shell dumpsys activity activities < /dev/null | grep -m1 -E 'topResumedActivity|mResumedActivity')"
      echo "$(date +%T) back requested, top: $top" >> "$OUT/${PREFIX}watch.txt"
      # A busy emulator may ignore the first BACK: retry until the game is
      # on top again (at most 4 times).
      for i in 1 2 3 4; do
        # Stop as soon as anything of ours is on top: the game, or an ad
        # (BACK would close the ad or leave the puzzle screen).
        if echo "$top" | grep -q "com.sandburstmagic/"; then break; fi
        adb shell input keyevent KEYCODE_BACK < /dev/null
        echo "$(date +%T) pressed BACK" >> "$OUT/${PREFIX}watch.txt"
        sleep 2
        top="$(adb shell dumpsys activity activities < /dev/null | grep -m1 -E 'topResumedActivity|mResumedActivity')"
      done
      echo "$(date +%T) after back, top: $top" >> "$OUT/${PREFIX}watch.txt" ;;
    *SBMALLOW*)
      # Answer Android's runtime permission dialog with "Allow".
      for i in $(seq 1 20); do
        sleep 1
        adb shell rm -f /sdcard/perm.xml < /dev/null > /dev/null 2>&1
        adb shell uiautomator dump /sdcard/perm.xml < /dev/null > /dev/null 2>&1
        perm="$(adb shell cat /sdcard/perm.xml < /dev/null 2>/dev/null | tr '>' '\n')"
        # A system "isn't responding" dialog may sit on top: answer "Wait".
        if echo "$perm" | grep -qiE "isn.t responding"; then
          w="$(echo "$perm" | grep -E 'text="Wait"' | head -n1)"
          [ -n "$w" ] && adb shell input tap $(echo "$w" | center_of) < /dev/null
          continue
        fi
        node="$(echo "$perm" | grep -E 'permission_allow_button|text="Allow"' | head -n1)"
        if [ -n "$node" ]; then
          adb exec-out screencap -p < /dev/null > "$OUT/shots/${PREFIX}permission-dialog.png" 2>/dev/null
          adb shell input tap $(echo "$node" | center_of) < /dev/null
          echo "$(date +%T) allowed permission" >> "$OUT/${PREFIX}watch.txt"
          break
        fi
      done ;;
    *SBMSHADE*)
      # Screenshot the notification shade, then close it.
      adb shell cmd statusbar expand-notifications < /dev/null
      sleep 2
      adb exec-out screencap -p < /dev/null > "$OUT/shots/${PREFIX}notification-shade.png" 2>/dev/null
      adb shell cmd statusbar collapse < /dev/null
      echo "$(date +%T) shade shot" >> "$OUT/${PREFIX}watch.txt" ;;
    *"SBMAD end"*)
      rm -f "$STATE"
      echo "$(date +%T) ad end" >> "$OUT/${PREFIX}watch.txt" ;;
  esac
done
