#!/usr/bin/env bash
# Host build of the native bridge + C smoke/export tests (ctest) + Dart FFI
# test against the freshly built library (FND-06). Uses ccache if present.
source "$(dirname "$0")/lib.sh"
"$ROOT/native/build.sh" host
cd "$ROOT/packages/vv_native"
"${FLUTTER[@]}" pub get
VV_NATIVE_LIB="$(ls "$ROOT"/native/build/host/libvv_native.* | head -1)" \
  "${FLUTTER[@]}" test
