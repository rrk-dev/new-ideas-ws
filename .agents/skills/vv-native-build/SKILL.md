---
name: vv-native-build
description: "Building whisper.cpp and llama.cpp with one shared ggml: submodule pinning, CMake superproject, Android NDK arm64 (CPU variants, Vulkan/OpenCL, 16 KB pages), iOS xcframework with Metal, host builds, native binary size. Use for any native build change."
---

# Native Build (whisper.cpp + llama.cpp + ggml)

## Golden rules
- Submodules pinned to exact commits: `native/whisper.cpp`, `native/llama.cpp`. Record commit
  + date in `native/VERSIONS.md` with the reason for every bump.
- **One ggml.** Both projects vendor ggml; linking both copies causes duplicate symbols / ODR
  crashes. Build a single ggml and let both projects use it. Both CMake projects skip their own
  ggml when a `ggml` target already exists (`if (NOT TARGET ggml …) add_subdirectory(ggml)` —
  verified: llama.cpp `if (NOT TARGET ggml AND NOT LLAMA_USE_SYSTEM_GGML)`, whisper.cpp
  `if (NOT TARGET ggml)` — re-check at the pinned commits). Choose commits whose ggml **trees**
  match closely: `diff -rq native/llama.cpp/ggml native/whisper.cpp/ggml` directly —
  each repo's `native/*/scripts/sync-ggml.last` can be identical while the trees differ. Build both against the single
  ggml (llama.cpp's is usually newer) and run whisper's smoke test.
- All CMake options are version-sensitive. Read `CMakeLists.txt` / `ggml/CMakeLists.txt` at the
  pinned commit; do not copy flags from memory or old blog posts.

## Superproject `native/CMakeLists.txt` (sketch — verify option names at pinned commits)
```cmake
cmake_minimum_required(VERSION 3.22)
project(vv_native C CXX)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)   # whisper.cpp uses cmake_minimum_required(3.5): without this
                                        # its option() calls silently drop our set() overrides
set(BUILD_SHARED_LIBS OFF)              # static ggml/whisper/llama, one shared vv_native
set(LLAMA_BUILD_COMMON OFF)             # llama-common pulls in cpp-httplib download code (egress!)
set(LLAMA_BUILD_TESTS OFF)
set(LLAMA_BUILD_TOOLS OFF)
set(LLAMA_BUILD_EXAMPLES OFF)
set(LLAMA_BUILD_SERVER OFF)
set(LLAMA_BUILD_APP OFF)
set(LLAMA_OPENSSL OFF)                  # LLAMA_CURL is deprecated/ignored at current master
set(WHISPER_BUILD_TESTS OFF)
set(WHISPER_BUILD_EXAMPLES OFF)
set(WHISPER_BUILD_SERVER OFF)
set(GGML_NATIVE OFF)                    # never -march=native (cross builds + reproducibility)
set(GGML_OPENMP OFF)                    # per llama.cpp docs/android.md and build-xcframework.sh
set(GGML_LLAMAFILE OFF)
add_subdirectory(llama.cpp/ggml ggml)   # the single ggml (or whisper's — pick one, document)
add_subdirectory(llama.cpp llama)
add_subdirectory(whisper.cpp whisper)
add_library(vv_native SHARED bridge/vv_bridge.cpp bridge/vv_whisper.cpp bridge/vv_llama.cpp)
target_link_libraries(vv_native PRIVATE whisper llama ggml)
# export only vv_* symbols: -fvisibility=hidden + VV_API macro on public functions
```
This sketch was configured and linked on a macOS host against llama.cpp/whisper.cpp master
(2026-10-12) — still re-verify option names at your pinned commits.

**JSON-schema→GBNF converter (LLM-05):** add a small static lib `vv_jsg` with
`common/json-schema-to-grammar.cpp`, `json-schema.cpp`, `json.cpp`, `trie.cpp`, `unicode.cpp`
(include dirs `common/`, `vendor/`, `include/`, `ggml/include`), link `ggml`, and provide
`string_join` / `string_split` / `string_repeat` (copy from `common.cpp` into a tiny shim).
**Do not** link the whole `llama-common` target (network code). API at current master:
`json_schema_to_grammar(const common_json & schema, bool force_gbnf = false)` with
`common_json::parse(str)` — re-check the include list and signature at the pinned commit.

## Android (STT-02, LLM-03)
- Gradle `externalNativeBuild { cmake { path "../../native/CMakeLists.txt" } }`, pin
  `ndkVersion` and CMake version in `build.gradle`; `abiFilters 'arm64-v8a'`.
- Pass `-DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DGGML_LLAMAFILE=OFF` (as in llama.cpp
  `docs/android.md`; OpenMP can't be packaged as a CMake dependency on Android).
- **16 KB page size** (required by Google Play for apps targeting Android 15+): use NDK r28+
  (aligned by default) or add `-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384`;
  AGP ≥ 8.5.1 for zip alignment of uncompressed libs. Verify with
  `llvm-objdump -p libvv_native.so | grep LOAD` (align `2**14`) and `zipalign -v -c -P 16 4 app.apk`.
- CPU: baseline `armv8-a` must run on the oldest matrix device. Faster kernels via either
  (a) `BUILD_SHARED_LIBS=ON` + `GGML_BACKEND_DL=ON` + `GGML_CPU_ALL_VARIANTS=ON` (ggml *requires*
  shared libs for this): ships `libggml.so`, `libggml-base.so`, `libggml-cpu-android_armv8.*.so`…,
  and the bridge must call `ggml_backend_load_all_from_path(<nativeLibraryDir>)` — this replaces
  the "static ggml + one vv_native.so" layout; or (b) one static build with
  `-DGGML_CPU_ARM_ARCH=armv8.2-a+dotprod` (not a global `-march`) **only if** every supported
  device has dotprod (check device matrix). `GGML_CPU_ALL_VARIANTS` and `GGML_CPU_ARM_ARCH` are
  mutually exclusive. Decide in FND-06 ADR; never ship an instruction set
  that SIGILLs on a supported device.
- GPU: `GGML_VULKAN=ON` (needs `glslc` from NDK shader-tools + Vulkan headers matching
  the pinned commit) and/or `GGML_OPENCL=ON` (Adreno; needs the Khronos OpenCL headers in the
  NDK sysroot and an NDK-built `libOpenCL.so` ICD loader — see llama.cpp `docs/build.md` →
  OpenCL → Android). GPU backends must be runtime-optional:
  try init, fall back to CPU, and keep an allowlist/denylist by GPU vendor+driver in Dart
  (`DeviceCapabilities`). NNAPI is deprecated — out of scope unless an ADR says otherwise.
- `-O3`, `-DNDEBUG`, `-ffunction-sections -fdata-sections`, link `-Wl,--gc-sections`, strip.
- Threads: pin to performance cores count (read `/sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq`
  via bridge helper), default `n_threads = perf_cores`.

## iOS (STT-01, LLM-02)
- Build static libs for `ios-arm64` and `ios-arm64-simulator` (+ x86_64 sim only if needed)
  with CMake `-DCMAKE_SYSTEM_NAME=iOS`, `GGML_METAL=ON`, `GGML_METAL_EMBED_LIBRARY=ON` (default
  when Metal is on; no separate .metallib), `GGML_OPENMP=OFF`, `GGML_NATIVE=OFF`,
  `GGML_METAL_TARGET_OS=ios`, `LLAMA_OPENSSL=OFF` — mirror llama.cpp's `build-xcframework.sh` at
  the pinned commit. That script targets iOS **16.4**; either verify the build on an iOS 16.0
  device or raise the app minimum to 16.4 (record in the FND-06 ADR).
- Package `vv_native.xcframework` (dynamic framework recommended so Dart can
  `DynamicLibrary.open('vv_native.framework/vv_native')`; if static, use `DynamicLibrary.process()`
  and prevent dead-stripping of `vv_*` symbols with `-force_load` / `-exported_symbols_list`).
- Core ML encoder (STT-01 spike): `WHISPER_COREML=ON` (+ `WHISPER_COREML_ALLOW_FALLBACK=ON` so
  init doesn't fail when the encoder is absent) loads `<model path minus .bin and -qX_Y>-encoder.mlmodelc`
  from the model's directory — quantized variants share the unquantized encoder (e.g.
  `ggml-small.en-q5_1.bin` → `ggml-small.en-encoder.mlmodelc`). HF ships it as `.mlmodelc.zip`:
  unzip at install (model catalog `companions`). First run compiles for ANE (slow); measure warm
  and cold. Decide in ADR.
- Simulator has no Metal performance parity — benchmarks only on device.
- Entitlement `com.apple.developer.kernel.increased-memory-limit` for large models (LLM-07).

## Packaging (`packages/vv_native`)
Created from `flutter create --template=plugin_ffi vv_native` (or Flutter native-assets build
hooks if the pinned Flutter has them stable — record choice in FND-06 ADR). Android uses the
CMake above; iOS podspec vends the prebuilt xcframework (`s.vendored_frameworks`). Build script
`native/build.sh {android|ios|host}` must work from a clean checkout:
`git submodule update --init --recursive && native/build.sh ios`.

## Host build (for tests, benches, evals)
`native/build.sh host` builds the same bridge for macOS/Linux (Metal on macOS) so
`tools/bench` and CI smoke tests use identical code.

## Verification checklist
- [ ] Clean checkout builds android + ios + host with one command each.
- [ ] `nm -D libvv_native.so | grep ' T '` shows only `vv_*` (+ required runtime) symbols.
- [ ] No duplicate ggml symbols (`nm` both libs before linking / link map).
- [ ] 16 KB alignment verified on Android.
- [ ] Sizes recorded in `native/VERSIONS.md` (input to REL-03 budget).
- [ ] Runs on the oldest device in the matrix (no SIGILL) and with GPU backend disabled.
