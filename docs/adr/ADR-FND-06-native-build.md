# ADR-FND-06 — Native build: one ggml, one `vv_native`, FFI plugin packaging

- **Status:** Accepted — product owner decisions 2026-10-14: **iOS 16.4 minimum** (§4) and
  **ARMv8.2-A + dotprod Android CPU minimum, no Cortex-A53/A35** (§3). Host verified; the
  Android/iOS builds themselves are still unverified until the CI jobs / device rows run.
- **Date:** 2026-10-12 (amended 2026-10-14)
- **Task:** FND-06
- **Deciders:** Claude Code (implementer); product owner (iOS minimum, CPU minimum, 2026-10-14)
- **Supersedes:** —

## Context
whisper.cpp and llama.cpp each embed ggml. Linking both naively gives duplicate symbols / ODR
crashes. Dart may only talk to a small C ABI (`native/bridge`). Constraints: offline/private (no
network code from llama-common), iOS 16+, Android API 26+ arm64, 16 KB pages, memory-conscious,
reproducible from a clean checkout. (Minimums as decided 2026-10-14: iOS 16.4, Android arm64
ARMv8.2-A + dotprod.)

## Decisions
1. **One ggml, static, one shared library.** `native/CMakeLists.txt` builds llama.cpp's `ggml/` once;
   whisper.cpp and llama.cpp skip theirs (`if (NOT TARGET ggml …)`, verified at the pins). All three
   link statically into `vv_native`, which exports **only** `vv_*` (macOS `-exported_symbols_list`,
   others `--version-script` + `--exclude-libs,ALL`). Evidence: host `nm -gU libvv_native.dylib`
   lists exactly the six `vv_*` symbols; the `vv_exports` ctest enforces it; the link of both
   libraries succeeds without duplicate symbols. The ggml trees of the two pins are identical.
2. **Pins:** whisper.cpp v1.9.5, llama.cpp v0.6.0 as shallow submodules (`native/VERSIONS.md`).
   `LLAMA_BUILD_COMMON=OFF` and `LLAMA_OPENSSL=OFF` keep download/HTTP code out (egress policy).
3. **Android:** CMake through Gradle `externalNativeBuild` (`packages/vv_native/android`), NDK r28c
   pinned, arm64-v8a only, `-O3`, `GGML_NATIVE/OPENMP/LLAMAFILE=OFF`, 16 KB link flags.
   **CPU minimum (product owner, 2026-10-14): ARMv8.2-A + dotprod — Cortex-A53/A35-only phones are
   not supported.** The static build's baseline is therefore `armv8.2-a+dotprod`
   (`VV_ANDROID_CPU_MIN_ARCH`; `VV_ANDROID_CPU_ARCH` empty = that minimum, `armv8-a` only for
   non-shipped comparison builds, never `+i8mm` — A55/A76-class devices lack it). The runtime-variant
   build (ADR-STT-02, `VV_GGML_BACKEND_DL`) keeps the dotprod/fp16/i8mm/SVE variants but excludes
   the `android_armv8.0_1` variant from the default build and the loader's probe list. Every Android
   build makes `vv_cpu_supported()` require NEON + dotprod, and the app shows
   "This device isn't supported" at launch below it (ADR-LLM-03 §1) instead of risking SIGILL.
   *Superseded text (2026-10-12):* "CPU baseline is plain armv8-a NEON; raising it needs the device
   matrix" — the product decision replaces that gate. GPU backends: ADR-STT-02.
4. **iOS:** CMake Xcode generator → dynamic `vv_native.framework` per SDK → `xcodebuild
   -create-xcframework`; Metal with embedded library (`GGML_METAL_EMBED_LIBRARY=ON`).
   **Minimum iOS 16.4 (product owner decision 2026-10-14)** — the same as llama.cpp's own
   `build-xcframework.sh` at the pin, so the 16.0–16.3 Metal question is moot. Applied to
   `IOS_MIN_OS` (`native/build.sh`), every `IPHONEOS_DEPLOYMENT_TARGET` in
   `app/ios/Runner.xcodeproj`, the `vv_native` podspec, AGENTS.md and CONTRIBUTING.md (pinned by
   `tools/ci/tests/test_product_decisions.py` and `app/test/unit/repo_standards_test.dart`).
   The Whisper Core ML encoder is on in the iOS build (ADR-STT-01, Accepted 2026-10-14).
5. **Packaging:** Flutter FFI plugin `packages/vv_native` (Android: Gradle→CMake; iOS: podspec vending
   the prebuilt xcframework), bindings by `ffigen` from `vv_bridge.h` and an ABI-version handshake
   (`VV_ABI_VERSION` ↔ `expectedAbiVersion`). Flutter native-assets build hooks were **not**
   evaluated; revisit if they become the recommended path.

## Evidence
| Check | Result |
|---|---|
| Host clean build + ctest (`native/build.sh host`) | pass, ~22 s with 12 cores, 6.5 MB dylib |
| Exports only `vv_*` | pass (`nm -gU`, `vv_exports` ctest) |
| Dart FFI `vv_version()` on host | pass (`[FND-06/AC2]` host test) |
| Android build, 16 KB alignment, APK contents | **not run** (no NDK) — CI Android job |
| iOS xcframework build | **not run** (no Xcode) — CI iOS job |
| On-device `vv_version()` | **not run** — `docs/test-plans/device/FND-06.md` |

## Consequences
- Positive: one ggml, minimal exported surface, one command per target, same code on host/CI.
- Negative / risks: Android/iOS paths are unverified until CI/devices run; CocoaPods plugin needs
  `native/build.sh ios` before `pod install`; the static single-`.so` layout cannot do runtime CPU
  dispatch.
- Follow-up tasks: ~~iOS minimum decision (user)~~ decided 16.4 (2026-10-14); CPU-variant/dispatch spike and GPU backends
  (STT-02, LLM-03); JSON-schema→GBNF helper lib `vv_jsg` (LLM-05); real engine entry points
  (STT-xx/LLM-xx) behind `vv_bridge.h`.
