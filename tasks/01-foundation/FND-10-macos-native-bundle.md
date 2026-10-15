# FND-10 — macOS Native Library in the App Bundle

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-06, FND-09 | **Source:** User decision 2026-10-14
**Status:** review
**Skills:** vv-task-workflow, vv-native-build, vv-ffi-bridge, vv-testing

## Goal
The macOS app loads the same `vv_native` bridge as iOS, from inside the app bundle, so speech-to-text and the local model can run on the desktop.

## Scope
- [x] `native/build.sh macos` builds an arm64 `vv_native` library with the pinned whisper.cpp and llama.cpp (one ggml), Metal allowed.
- [x] The Flutter macOS runner copies that library into the app bundle and the Dart FFI loader opens it from there.
- [x] `vv_version()` returns the same version string as the iOS bridge (ABI unchanged).
- [x] A tagged test covers the load path with the host library when a full macOS bundle build is not required for the assertion.
- [x] Record the macOS binary size in `native/VERSIONS.md`.

## Acceptance Criteria
- `native/build.sh macos` exits 0 on this Mac and prints the library path and size.
- A macOS dev build calls `vv_version()` and gets the bridge version (device row in `docs/test-plans/device/FND-10.md`).
- `native/VERSIONS.md` lists the macOS arm64 size.

## Notes
Reuse the host/Metal flags from FND-06. Do not fork a second copy of ggml. Android and iOS build scripts stay as they are.

`native/build.sh macos` configures an arm64 Ninja build (one ggml, `GGML_METAL=ON`, embedded metallib, deployment target 13.0) and, on success, copies `vv_native.framework` to `packages/vv_native/macos/Frameworks` and prints `macos: <path> <bytes> bytes`. On 2026-10-14 that command exited 2: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (Xcode 27.0) and `xcrun` exits 69 because the license was last accepted for Xcode 26.2. The script does not run sudo. After `sudo xcodebuild -license`, re-run it and replace the macOS size cell in `native/VERSIONS.md`. `[FND-10/AC1]` passed against the existing host dylib (`vv_version` `0.1.0`, arm64). That dylib is not the macOS framework this target builds.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/FND-10-macos-native-bundle · **Date:** 2026-10-15
- **Summary:** `native/build.sh macos` now exits 0 (Xcode 27.0, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`) and prints the framework path and 10,282,600 B. Fixed `size_of` in `native/build.sh` to follow symlinks (it printed 26 B for the framework symlink). `app/macos/Podfile` platform raised to 13.0 to match `vv_native.podspec`; CocoaPods embeds `vv_native.framework` into `Contents/Frameworks`. `integration_test/native_bridge_test.dart` passed on `-d macos --flavor dev` (`vv_version()` `0.1.0`). macOS size recorded in `native/VERSIONS.md`.
- **Acceptance evidence:**
  - AC1: ✅ test: [FND-10/AC1]
  - AC2: ✅ device: docs/test-plans/device/FND-10.md
  - AC3: ✅ test: [FND-10/AC3]
- **Decisions:** none
- **Follow-ups:** none
