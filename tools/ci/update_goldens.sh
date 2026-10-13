#!/usr/bin/env bash
# Regenerates golden images on Linux, the reference host (docs/testing.md →
# "Golden tests"). On Linux it runs the FVM/Flutter on PATH; elsewhere it runs
# the Flutter version pinned in .fvmrc inside a podman Linux container (the
# SDK is cached in the podman volume vv-flutter-<version>).
#
# Usage: update_goldens.sh [flutter test args…]   (default: --tags golden)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARGS=("$@")
[ ${#ARGS[@]} -eq 0 ] && ARGS=(--tags golden)

if [ "$(uname -s)" = "Linux" ]; then
  source "$ROOT/tools/ci/lib.sh"
  cd "$APP"
  exec "${FLUTTER[@]}" test --update-goldens "${ARGS[@]}"
fi

command -v podman >/dev/null 2>&1 || {
  echo "update_goldens: podman is required on $(uname -s) (goldens are rendered on Linux)" >&2
  exit 1
}
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flutter"])' "$ROOT/.fvmrc")"
IMAGE="docker.io/library/debian:trixie-slim"
# The app is copied into the container (host .dart_tool/build stay untouched);
# only the regenerated `goldens/*.png` are copied back.
podman run --rm \
  -v "vv-flutter-$VERSION:/opt/flutter" \
  -v "$ROOT/app:/src/app" -v "$ROOT/packages:/src/packages:ro" \
  -e "FLUTTER_VERSION=$VERSION" "$IMAGE" bash -euo pipefail -c '
    if ! command -v git >/dev/null; then
      apt-get update -qq && apt-get install -y -qq git curl unzip xz-utils ca-certificates >/dev/null
    fi
    if [ ! -x /opt/flutter/bin/flutter ]; then
      git clone -q --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git /opt/flutter
    fi
    git config --global --add safe.directory "*"
    export PATH=/opt/flutter/bin:$PATH PUB_CACHE=/opt/flutter/.pub-cache
    mkdir -p /w/app && cp -r /src/packages /w/packages
    (cd /src/app && tar --exclude=./.dart_tool --exclude=./build --exclude=./ios \
      --exclude=./android -cf - .) | (cd /w/app && tar -xf -)
    cd /w/app
    flutter pub get >/dev/null
    flutter test --update-goldens "$@"
    find test -path "*/goldens/*.png" | tar -cf - -T - | (cd /src/app && tar -xf -)
  ' _ "${ARGS[@]}"
