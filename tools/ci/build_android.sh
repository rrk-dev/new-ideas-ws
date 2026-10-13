#!/usr/bin/env bash
# Debug dev-flavor APK incl. libvv_native.so (built by Gradle externalNativeBuild
# from native/CMakeLists.txt with the pinned NDK).
source "$(dirname "$0")/lib.sh"
cd "$APP"
"${FLUTTER[@]}" build apk --flavor dev -t lib/main_dev.dart --debug \
  --target-platform android-arm64
bash "$ROOT/tools/ci/check_apk_native.sh" build/app/outputs/flutter-apk/app-dev-debug.apk
ls -l build/app/outputs/flutter-apk/*.apk
