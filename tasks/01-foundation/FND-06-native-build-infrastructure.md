# FND-06 — Native C/C++ Build Infrastructure

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-01 | **Source:** §4.2, §5 Phase 2
**Status:** in-progress
**Skills:** vv-task-workflow, vv-native-build, vv-ffi-bridge, vv-decision-records, vv-testing

## Goal
Reproducible builds of `whisper.cpp` and `llama.cpp` (shared `ggml`) for both platforms, consumed by Flutter via FFI.

## Scope
- [x] Vendor `whisper.cpp` and `llama.cpp` as git submodules pinned to specific commits; document upgrade procedure.
- [x] Resolve duplicate `ggml` symbols (both projects embed ggml) — build a single shared ggml or namespace them.
- [x] Android: CMake via Gradle `externalNativeBuild`, NDK version pinned, arm64-v8a, `-O3`, NEON/dotprod/i8mm flags.
- [x] iOS: build script producing `.xcframework` (device + simulator), Metal shaders embedded (`GGML_METAL_EMBED_LIBRARY`).
- [x] Thin C wrapper (`vv_bridge.h`) exposing a stable C ABI for Dart FFI; generate Dart bindings with `ffigen`.
- [x] Packaged as an internal Flutter FFI plugin (`packages/vv_native`).
- [x] Extend CI (FND-03): NDK-pinned native build in the Android job (APK contains `libvv_native.so`), `vv_native.xcframework` in the iOS job, `ci/native_host.sh` host build + C smoke tests with ccache.

## Acceptance Criteria
- Clean checkout → single command builds both platform libraries.
- A Dart test calls a trivial bridge function (`vv_version()`) on device for both platforms.
- Binary size of native libs recorded (input to REL-03).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-06-native-build (stacked on FND-03 → FND-02 → FND-01) · **Date:** 2026-10-12
- **Summary:** Submodules `native/whisper.cpp` (v1.9.5) and `native/llama.cpp` (v0.6.0) pinned (`native/VERSIONS.md`, upgrade
  procedure included). `native/CMakeLists.txt` builds ONE ggml (their trees are identical at the pins) linked statically into
  one `vv_native` shared library exporting only `vv_*`; Android knobs (NDK r28c, arm64, `-O3`, 16 KB link flags,
  `VV_ANDROID_CPU_ARCH`) and iOS framework packaging. `native/build.sh {host|android|ios|all}`. C ABI `native/bridge/vv_bridge.h`
  (`vv_abi_version`, `vv_version`, whisper/ggml versions, system info). `packages/vv_native`: ffigen bindings, loader with ABI
  handshake, Gradle→CMake (Android), podspec vending the xcframework (iOS), host Dart test; on-device test
  `app/integration_test/native_bridge_test.dart`. CI: `native_host.sh`, APK `libvv_native.so` check, xcframework before the iOS
  build, ccache keyed on pins. ADR-FND-06 (Proposed).
  **Verified locally (macOS, host only):** clean `native/build.sh host` + ctest (`vv_smoke`, `vv_exports`), Dart FFI host test,
  bindings drift check. **Not verified:** Android build/16 KB alignment/APK contents (no NDK), iOS xcframework (no Xcode), on-device
  `vv_version()`, mobile binary sizes; the Gradle/podspec glue has never been compiled.
- **Acceptance evidence:**
  - AC1: ⏳ test: [FND-06/AC1]; device: docs/test-plans/device/FND-06.md
  - AC2: ⏳ test: [FND-06/AC2]; device: docs/test-plans/device/FND-06.md
  - AC3: ⏳ artifact: native/VERSIONS.md; device: docs/test-plans/device/FND-06.md
- **Decisions:** ADR-FND-06-native-build (Proposed: iOS min 16.0 vs 16.4, Android CPU baseline, packaging)
- **Follow-ups:** user decision on iOS minimum (16.0 vs 16.4); CPU-variant dispatch + GPU backends (STT-02/LLM-03); `vv_jsg` (LLM-05); apply `native-host`/`android`/`ios` as required checks

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-13 · **Commit:** 87963175263cf3aba56fc55cca584d490ce26a6d
- **Verdict:** FAIL
- **Gates:** format ✅ · analyze ✅ (no issues) · flutter tests ✅ (21 passed, coverage 94.4%) · native host smoke ✅ (`native/build.sh host`, ctest `vv_smoke` and `vv_exports` passed, `libvv_native.dylib` 6507968 bytes) after `git submodule update --init` · egress ✅ · recording policy n/a · CI run: local fresh worktree. Android and iOS builds not run (no NDK, no Xcode).
- **Acceptance criteria:**
  - AC1: ❌ `[FND-06/AC1]` fails on a checkout without submodules. `native/build.sh bogus` exits 2 because `check_submodules` runs before the usage case, so the test expects exit 64 and does not get it. The same three pytest tests pass once submodules are present. `task-gate` checks out without `submodules: recursive` and runs `pytest tools/ci/tests`, so this fails that job.
  - AC2: ⏳ host Dart/C smoke passed. On-device `vv_version()` rows in `docs/test-plans/device/FND-06.md` have no PASS. Not re-run (no phone, no SDK).
  - AC3: ⏳ host size was printed. Android stripped `.so` and iOS slice sizes are not filled in. Not measured here.
- **Adversarial checks:** fresh worktree, no submodules, `pytest tools/ci/tests/test_native_build.py` → the usage test failed (exit 2 vs 64). After submodule init, host build and the same tests passed. Did not upload audio or open a network client.
- **Skill/rule compliance:** one shared library, `vv_*` ABI, pins recorded in `native/VERSIONS.md`. ADR-FND-06 is still Proposed (iOS 16.0 vs 16.4, CPU baseline). That matches the notes; it is not this FAIL.
- **Issues found:**
  1. Parse the target before `check_submodules` (or otherwise make `native/build.sh bogus` exit 64 without a populated submodule), and make `task-gate` able to run `tools/ci/tests` on its current checkout. Today that job fails.
