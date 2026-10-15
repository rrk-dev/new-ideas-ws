# Device verification — FND-10 macOS native library in the app bundle

The host loader test (`[FND-10/AC1]` in `packages/vv_native/test/macos_bundle_host_test.dart`)
does not need a Flutter macOS app. This row checks the dev app bundle.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-10/AC2] | 1. Accept the Xcode license if `xcrun --show-sdk-path --sdk macosx` fails (`sudo xcodebuild -license` in Terminal). 2. `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. 3. `native/build.sh macos` (must print an arm64 framework path and a byte size). 4. With the FND-09 runner present: `cd app && fvm flutter test integration_test/native_bridge_test.dart --flavor dev -d macos`. | Test passes: `vv_version()` is `0.1.0`, ABI is 1. The built `.app` contains `Contents/Frameworks/vv_native.framework/vv_native`. | Apple silicon Mac | macOS 27.0.1 | PASS (`vv_version()` 0.1.0; `vv_native.framework` in `Contents/Frameworks`) | 2026-10-15 | Copilot CLI |

## Notes / evidence
`app/macos` is produced by FND-09. Until that runner exists, this row cannot be executed.
On 2026-10-14, `native/build.sh macos` also stopped before a compile: Xcode 27.0 license is not accepted (`xcrun` exit 69; last agreed license is Xcode 26.2).
