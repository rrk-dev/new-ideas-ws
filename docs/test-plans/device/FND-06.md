# Device / toolchain verification — FND-06 Native C/C++ Build Infrastructure

Rows below need an NDK, Xcode or a physical device, none of which were available when this was
authored. The host path (macOS, Metal) was built and tested locally.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-06/AC1] | 1. Clean clone: `git clone --recurse-submodules --shallow-submodules <repo>`. 2. With NDK r28+ set: `native/build.sh android`. | Builds `libvv_native.so` (arm64-v8a), prints stripped size, LOAD segments are `2**14` aligned. | macOS/Linux host with NDK r28c | — | | | |
| [FND-06/AC1] | 1. Same clean clone, full Xcode selected. 2. `native/build.sh ios`. | Builds device + simulator frameworks and `vv_native.xcframework`; copy appears in `packages/vv_native/ios/Frameworks`. | macOS host with Xcode | — | | | |
| [FND-06/AC2] | 1. Connect an arm64 Android phone (API 26+). 2. `cd app && fvm flutter test integration_test/native_bridge_test.dart --flavor dev -d <id>`. | Test passes: `vv_version()` = `0.1.0`, ABI 1. | arm64 Android phone | API 26+ | | | |
| [FND-06/AC2] | 1. Connect an iPhone (iOS 16+), pick a signing team. 2. Same command with the iPhone id. | Test passes: `vv_version()` = `0.1.0`, ABI 1. | iPhone | iOS 16+ | | | |
| [FND-06/AC3] | Record the sizes printed by the two builds above in `native/VERSIONS.md`. | Table has Android stripped `.so` and iOS slice sizes. | NDK host / Xcode host | — | | | |

## Notes / evidence
Verified locally on macOS 26 (arm64, Apple clang 21, CMake 4.4.4, Ninja 1.13.2): clean
`native/build.sh host` (ctest: `vv_smoke`, `vv_exports`), `tools/ci/native_host.sh` (adds the Dart FFI test),
`tools/ci/check_bindings.py`. Android/iOS CMake and Gradle/podspec glue are written but never compiled.
