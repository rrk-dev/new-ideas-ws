# FND-10 — macOS Native Library in the App Bundle

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-06, FND-09 | **Source:** User decision 2026-10-14
**Status:** todo
**Skills:** vv-task-workflow, vv-native-build, vv-ffi-bridge, vv-testing

## Goal
The macOS app loads the same `vv_native` bridge as iOS, from inside the app bundle, so speech-to-text and the local model can run on the desktop.

## Scope
- [ ] `native/build.sh macos` builds an arm64 `vv_native` library with the pinned whisper.cpp and llama.cpp (one ggml), Metal allowed.
- [ ] The Flutter macOS runner copies that library into the app bundle and the Dart FFI loader opens it from there.
- [ ] `vv_version()` returns the same version string as the iOS bridge (ABI unchanged).
- [ ] A tagged test covers the load path with the host library when a full macOS bundle build is not required for the assertion.
- [ ] Record the macOS binary size in `native/VERSIONS.md`.

## Acceptance Criteria
- `native/build.sh macos` exits 0 on this Mac and prints the library path and size.
- A macOS dev build calls `vv_version()` and gets the bridge version (device row in `docs/test-plans/device/FND-10.md`).
- `native/VERSIONS.md` lists the macOS arm64 size.

## Notes
Reuse the host/Metal flags from FND-06. Do not fork a second copy of ggml. Android and iOS build scripts stay as they are.
