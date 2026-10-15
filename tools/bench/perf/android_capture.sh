#!/usr/bin/env bash
# QA-03: capture Android battery and thermal evidence around a processing run.
# Usage: android_capture.sh <out-dir> start|stop [adb-serial]
# start: resets batterystats and records the thermal baseline.
# stop:  dumps batterystats, thermalservice and the battery level.
# Needs adb on PATH and a device with USB debugging; does not install anything.
set -euo pipefail
OUT="${1:?out dir}"; ACTION="${2:?start|stop}"; SERIAL="${3:-}"
command -v adb >/dev/null || { echo "adb not found" >&2; exit 2; }
ADB=(adb); [ -n "$SERIAL" ] && ADB=(adb -s "$SERIAL")
mkdir -p "$OUT"
case "$ACTION" in
  start)
    "${ADB[@]}" shell dumpsys batterystats --enable full-wake-history >/dev/null
    "${ADB[@]}" shell dumpsys batterystats --reset >/dev/null
    "${ADB[@]}" shell dumpsys battery | grep -E "level|temperature" >"$OUT/battery-start.txt"
    "${ADB[@]}" shell dumpsys thermalservice >"$OUT/thermal-start.txt"
    echo "reset; unplug the cable now (adb over Wi-Fi) and start the run";;
  stop)
    "${ADB[@]}" shell dumpsys battery | grep -E "level|temperature" >"$OUT/battery-end.txt"
    "${ADB[@]}" shell dumpsys thermalservice >"$OUT/thermal-end.txt"
    "${ADB[@]}" shell dumpsys batterystats >"$OUT/batterystats.txt"
    "${ADB[@]}" bugreport "$OUT/bugreport.zip" >/dev/null
    echo "saved to $OUT (open bugreport.zip in Battery Historian)";;
  *) echo "usage: $0 <out-dir> start|stop [serial]" >&2; exit 2;;
esac
