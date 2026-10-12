# FND-06 — Native C/C++ Build Infrastructure

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** §4.2, §5 Phase 2
**Status:** todo
**Skills:** vv-task-workflow, vv-native-build, vv-ffi-bridge, vv-decision-records, vv-testing

## Goal
Reproducible builds of `whisper.cpp` and `llama.cpp` (shared `ggml`) for both platforms, consumed by Flutter via FFI.

## Scope
- [ ] Vendor `whisper.cpp` and `llama.cpp` as git submodules pinned to specific commits; document upgrade procedure.
- [ ] Resolve duplicate `ggml` symbols (both projects embed ggml) — build a single shared ggml or namespace them.
- [ ] Android: CMake via Gradle `externalNativeBuild`, NDK version pinned, arm64-v8a, `-O3`, NEON/dotprod/i8mm flags.
- [ ] iOS: build script producing `.xcframework` (device + simulator), Metal shaders embedded (`GGML_METAL_EMBED_LIBRARY`).
- [ ] Thin C wrapper (`vv_bridge.h`) exposing a stable C ABI for Dart FFI; generate Dart bindings with `ffigen`.
- [ ] Packaged as an internal Flutter FFI plugin (`packages/vv_native`).
- [ ] Extend CI (FND-03): NDK-pinned native build in the Android job (APK contains `libvv_native.so`), `vv_native.xcframework` in the iOS job, `ci/native_host.sh` host build + C smoke tests with ccache.

## Acceptance Criteria
- Clean checkout → single command builds both platform libraries.
- A Dart test calls a trivial bridge function (`vv_version()`) on device for both platforms.
- Binary size of native libs recorded (input to REL-03).
