#!/usr/bin/env bash
# Release build of the prod flavor with Dart obfuscation + split debug info
# (REL-01). Symbols are collected into a PRIVATE directory that CI uploads as a
# workflow artifact only — never to a third-party crash service, never to a
# public GitHub Release.
#
#   tools/release/build_release.sh android     -> app/build/release/android/app-prod-release.aab
#   tools/release/build_release.sh ios <plist> -> app/build/release/ios/*.ipa  (needs Xcode + signing)
#
# Env: VV_BUILD_NAME / VV_BUILD_NUMBER (from tools/release/version.py; both
# required — a release build without an explicit number is refused).
# Output symbols: app/build/release-symbols/<platform>/
#   app.<platform>-arm64.symbols   Dart split debug info (flutter symbolize -d)
#   obfuscation_map.json           Dart identifier map (deobfuscate messages)
#   native/                        unstripped libvv_native.so (ndk-stack) or dSYMs (atos)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$ROOT/app"
if command -v fvm >/dev/null 2>&1; then FLUTTER=(fvm flutter); else FLUTTER=(flutter); fi

PLATFORM="${1:-}"
case "$PLATFORM" in android|ios) ;; *) echo "usage: $0 {android|ios <export-options.plist>}" >&2; exit 64 ;; esac
: "${VV_BUILD_NAME:?set VV_BUILD_NAME (tools/release/version.py github-output)}"
: "${VV_BUILD_NUMBER:?set VV_BUILD_NUMBER (tools/release/version.py build-number)}"

OUT="$APP/build/release/$PLATFORM"
SYM="$APP/build/release-symbols/$PLATFORM"
rm -rf "$OUT" "$SYM"
mkdir -p "$OUT" "$SYM/native"

# Shared flags. --obfuscate requires --split-debug-info (flutter refuses otherwise).
RELEASE_FLAGS=(
  --release --flavor prod -t lib/main_prod.dart
  --obfuscate --split-debug-info="$SYM"
  --extra-gen-snapshot-options=--save-obfuscation-map="$SYM/obfuscation_map.json"
  --build-name="$VV_BUILD_NAME" --build-number="$VV_BUILD_NUMBER"
)

cd "$APP"
if [ "$PLATFORM" = android ]; then
  # Gradle refuses to fall back to debug signing (app/android/signing.gradle).
  export VV_REQUIRE_RELEASE_SIGNING=true
  "${FLUTTER[@]}" build appbundle "${RELEASE_FLAGS[@]}" --target-platform android-arm64
  cp build/app/outputs/bundle/prodRelease/app-prod-release.aab "$OUT/"
  # Unstripped native libs for ndk-stack (the AAB only carries stripped ones).
  find build/app/intermediates -path '*prodRelease*' -name 'libvv_native.so' \
    -not -path '*stripped_native_libs*' -exec cp {} "$SYM/native/" \; -quit || true
else
  PLIST="${2:?usage: $0 ios <export-options.plist>}"
  "${FLUTTER[@]}" build ipa "${RELEASE_FLAGS[@]}" --export-options-plist="$PLIST"
  cp build/ios/ipa/*.ipa "$OUT/"
  if [ -d build/ios/archive/Runner.xcarchive/dSYMs ]; then
    cp -R build/ios/archive/Runner.xcarchive/dSYMs "$SYM/native/"
  fi
fi

# Integrity manifest for the archived symbols and the uploaded binary.
( cd "$APP/build" && find "release/$PLATFORM" "release-symbols/$PLATFORM" -type f \
    ! -name SHA256SUMS -print0 | sort -z | xargs -0 shasum -a 256 ) > "$SYM/SHA256SUMS"
echo "$PLATFORM $VV_BUILD_NAME ($VV_BUILD_NUMBER): binary in $OUT, private symbols in $SYM"
