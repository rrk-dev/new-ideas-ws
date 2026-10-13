# ADR-FND-06 — Native build: one ggml, one `vv_native`, FFI plugin packaging

- **Status:** Proposed (host verified; Android/iOS not built or measured on a device yet)
- **Date:** 2026-10-12
- **Task:** FND-06
- **Deciders:** Claude Code (implementer); pending independent verifier and the user (iOS minimum)
- **Supersedes:** —

## Context
whisper.cpp and llama.cpp each embed ggml. Linking both naively gives duplicate symbols / ODR
crashes. Dart may only talk to a small C ABI (`native/bridge`). Constraints: offline/private (no
network code from llama-common), iOS 16+, Android API 26+ arm64, 16 KB pages, memory-conscious,
reproducible from a clean checkout.

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
   pinned, arm64-v8a only, `-O3`, `GGML_NATIVE/OPENMP/LLAMAFILE=OFF`, 16 KB link flags. CPU baseline
   is **plain armv8-a NEON**; `VV_ANDROID_CPU_ARCH` forwards a value like `armv8.2-a+dotprod[+i8mm]`
   to `GGML_CPU_ARM_ARCH`. Raising it needs the device matrix (QA-05) — a SIGILL on a supported
   device is unacceptable. Runtime dispatch (`GGML_CPU_ALL_VARIANTS` + `GGML_BACKEND_DL`, shared
   libs) is the better long-term answer but changes the "one `.so`" layout; to be decided from STT-02 /
   LLM-03 measurements. GPU backends (Vulkan/OpenCL) are not enabled yet (those tasks).
4. **iOS:** CMake Xcode generator → dynamic `vv_native.framework` per SDK → `xcodebuild
   -create-xcframework`; Metal with embedded library (`GGML_METAL_EMBED_LIBRARY=ON`). The native
   minimum defaults to **16.0** (matches the app and AGENTS.md). llama.cpp's own script uses **16.4**.
   Unresolved: either verify 16.0 on a real iOS 16.0–16.3 device, or raise the app minimum to 16.4
   (a product-visible change → the user decides).
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
- Follow-up tasks: iOS minimum decision (user); CPU-variant/dispatch spike and GPU backends
  (STT-02, LLM-03); JSON-schema→GBNF helper lib `vv_jsg` (LLM-05); real engine entry points
  (STT-xx/LLM-xx) behind `vv_bridge.h`.
