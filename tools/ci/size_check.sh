#!/usr/bin/env bash
# REL-03 size gate: measures the release artifacts that exist and compares them
# with tools/ci/size-budget.json (absolute budget + max 10 % growth over the
# recorded baseline; no model weights in any binary or in app/assets).
#
# Usage: size_check.sh [--update-baseline] [extra size_check.py args]
# Picks up, when present (first match wins):
#   app/build/release/android/*.aab, app/build/app/outputs/bundle/prodRelease/*.aab
#                                     (tools/release/build_release.sh android)
#   app/build/release/ios/*.ipa, app/build/ios/ipa/*.ipa
#                                     (tools/release/build_release.sh ios)
#   native/build/host/libvv_native.{dylib,so}         (native/build.sh host)
# Without any artifact it still checks app/assets for bundled models.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARGS=()
first() { for f in "$@"; do [ -e "$f" ] && { echo "$f"; return 0; }; done; return 0; }
AAB="$(first "$ROOT"/app/build/release/android/*.aab "$ROOT"/app/build/app/outputs/bundle/prodRelease/*.aab)"
IPA="$(first "$ROOT"/app/build/release/ios/*.ipa "$ROOT"/app/build/ios/ipa/*.ipa)"
LIB="$(first "$ROOT"/native/build/host/libvv_native.dylib "$ROOT"/native/build/host/libvv_native.so)"
[ -n "$AAB" ] && ARGS+=(--android-aab "$AAB")
[ -n "$IPA" ] && ARGS+=(--ios-ipa "$IPA")
[ -n "$LIB" ] && ARGS+=(--host-lib "$LIB")
exec python3 "$ROOT/tools/ci/size_check.py" ${ARGS[@]+"${ARGS[@]}"} "$@"
