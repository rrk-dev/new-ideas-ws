#!/usr/bin/env bash
# Debug dev-flavor APK. FND-06 adds libvv_native.so (and the 16 KB page check).
source "$(dirname "$0")/lib.sh"
cd "$APP"
"${FLUTTER[@]}" build apk --flavor dev -t lib/main_dev.dart --debug
ls -l build/app/outputs/flutter-apk/*.apk
