#!/usr/bin/env bash
# Capture store screenshots (REL-05) via the Flutter integration test.
#
# Does not compile an IPA/APK. Needs a booted simulator / emulator listed
# in tools/release/store_screenshot_sizes.json. Exit 2 when none is present
# so CI and laptops without devices skip rather than compiling.
#
#   bash tools/release/capture_store_screenshots.sh ios
#   bash tools/release/capture_store_screenshots.sh android
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$ROOT/app"
PLATFORM="${1:-}"
case "$PLATFORM" in
  ios|android) ;;
  *)
    echo "usage: capture_store_screenshots.sh ios|android" >&2
    exit 2
    ;;
esac

if ! command -v fvm >/dev/null 2>&1; then
  echo "capture_store_screenshots: fvm not on PATH" >&2
  exit 2
fi

devices="$(cd "$APP" && fvm flutter devices --machine 2>/dev/null || true)"
if [ -z "$devices" ] || [ "$devices" = "[]" ]; then
  echo "capture_store_screenshots: no Flutter device for $PLATFORM (skip)" >&2
  exit 2
fi

# Integration test writes PNGs via takeScreenshot. Copy them into the
# fastlane metadata trees (Snapfile / Screengrabfile). Not executed on
# the authoring machine.
cd "$APP"
exec fvm flutter test integration_test/store_screenshots_test.dart \
  --flavor prod \
  --dart-define=VV_STORE_SCREENSHOTS=true \
  --dart-define=VV_STORE_SCREENSHOT_PLATFORM="$PLATFORM"
