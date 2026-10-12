#!/usr/bin/env bash
# Unsigned dev-flavor build (macOS runner). FND-06 adds vv_native.xcframework.
source "$(dirname "$0")/lib.sh"
cd "$APP"
"${FLUTTER[@]}" build ios --flavor dev -t lib/main_dev.dart --debug --no-codesign
rm -f build/ios/Runner-dev.app.zip
ditto -c -k --sequesterRsrc --keepParent \
  build/ios/iphoneos/Runner.app build/ios/Runner-dev.app.zip
ls -l build/ios/Runner-dev.app.zip
