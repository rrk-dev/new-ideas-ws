#!/usr/bin/env bash
# CI bootstrap: FVM (pinned) -> pinned Flutter SDK (.fvmrc) -> pub get.
# Expects a Dart SDK on PATH (dart-lang/setup-dart) when fvm is not installed.
source "$(dirname "$0")/lib.sh"
FVM_VERSION="${FVM_VERSION:-4.3.1}"
if ! command -v fvm >/dev/null 2>&1; then
  dart pub global activate fvm "$FVM_VERSION"
  export PATH="$PATH:$HOME/.pub-cache/bin"
  [ -n "${GITHUB_PATH:-}" ] && echo "$HOME/.pub-cache/bin" >> "$GITHUB_PATH"
fi
cd "$ROOT"
fvm install
cd "$APP"
fvm flutter pub get
