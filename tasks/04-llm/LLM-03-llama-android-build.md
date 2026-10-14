# LLM-03 — llama.cpp Android Build (CPU / Vulkan / OpenCL)

**Workstream:** LLM | **Phase:** 2 | **Size:** M | **Depends on:** LLM-01, FND-06 | **Source:** §4.2
**Status:** review
**Skills:** vv-task-workflow, vv-native-build, vv-llm-inference, vv-benchmark-eval, vv-testing

## Goal
llama.cpp runs on Android with the best stable backend per SoC.

## Scope
- [x] arm64-v8a with dotprod/i8mm CPU kernels; use Q4_0 repacked layouts where faster on ARM. ADR-LLM-03: at the pin these kernels and the Q4_0 repack are compile-time gated, so the release build moves to `VV_ANDROID_CPU_ARCH=armv8.2-a+dotprod` once the matrix confirms dotprod; `vv_cpu_features/vv_cpu_supported` + Dart `cpuSupported` refuse to start on CPUs without the compiled-in features (no SIGILL). Q4_0 vs Q4_K_M and B0 vs B1 speed: ⏳ device rows.
- [x] Evaluate Vulkan and Adreno OpenCL backends; allowlist by GPU family; CPU fallback. CMake `VV_ANDROID_VULKAN` / `VV_ANDROID_OPENCL` (off by default); GPU devices exposed via `vv_llm_gpu_device_info` → Dart `DeviceCapabilities`; `GpuAllowlist` (shipped empty = CPU everywhere), `GpuBackendGuard` crash marker + fallback denylist, `chooseAndroidBackend`; bridge falls back GPU → CPU. On-device evaluation: ⏳ device rows (no NDK/devices).
- [x] Thread affinity to performance cores; handle big.LITTLE. `vv_cpu_perf_cores()` reads cpufreq clusters (cores faster than the slowest cluster); llama.cpp gets a ggml threadpool with exactly that cpumask (non-strict) on Linux/Android.
- [~] Respect Android memory class / low-memory killer; mmap loading. mmap done (`LLAMA_LOAD_MODE_MMAP`); the pre-load RAM budget check against `ActivityManager.MemoryInfo` deferred → LLM-07 (memory tiering owns it; ADR-LLM-03 notes the CPU path needs the full model size in anonymous memory).

## Acceptance Criteria
- Llama-3.2-3B Q4: ≥ 10 tok/s decode on Snapdragon 8 Gen 3; Snapdragon 7-series numbers recorded.
- No crash across the device matrix (QA-05) — failing backends auto-disabled.

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/LLM-03-llama-android · **Date:** 2026-10-13
- **Summary:** Builds on LLM-02's `vv_llama` bridge (merged into this branch). Native: `native/bridge/vv_cpu.{h,c}` (cpufreq big.LITTLE detection, HWCAP/sysctl feature detection, guard), `vv_cpu_features` / `vv_cpu_supported` exports, perf-core threadpool affinity in `vv_llama.cpp`, CMake `VV_ANDROID_VULKAN` / `VV_ANDROID_OPENCL`; ctest `vv_cpu` (`native/tests/cpu_test.c`). Dart: `app/lib/core/platform/device_capabilities.dart` (interface + `GpuDevice`), `features/extraction/data/native_device_capabilities.dart`, `features/extraction/domain/gpu_backend_guard.dart` (allowlist, crash guard, `chooseAndroidBackend`), `features/extraction/data/file_backend_health_store.dart`, `test/fakes/fake_device_capabilities.dart`; device tests `app/integration_test/llm_android_test.dart`. Decision: ADR-LLM-03.
- **Acceptance evidence:**
  - AC1: ⏳ test: [LLM-03/AC1]; device: docs/test-plans/device/LLM-03.md
  - AC2: ⏳ test: [LLM-03/AC2]; device: docs/test-plans/device/LLM-03.md
- **Decisions:** ADR-LLM-03-android-cpu-gpu (Proposed)
- **Follow-ups:** see below

## Follow-ups
- LLM-10 (proposed, not filed): `GGML_BACKEND_DL` + `GGML_CPU_ALL_VARIANTS` runtime CPU dispatch if the product must support Cortex-A53/A35-only phones (changes the FND-06 single-`.so` packaging, also affects STT-02). PRODUCT-DECISION: minimum supported Android CPU class.
- CI / FND-06 owner: forward `VV_ANDROID_VULKAN` / `VV_ANDROID_OPENCL` in `native/build.sh android` and add an NDK build of the Vulkan variant (needs `glslc` + Vulkan-Headers); OpenCL needs the Khronos headers + ICD loader.
- QA-05: fill the device-matrix "Dotprod" column from the `[LLM-03/AC2]` B1 rows before switching the release build to `armv8.2-a+dotprod`.
- LLM-07: Android pre-load RAM check (memory class / `availMem`) using the CPU-path footprint (≈ full model size).
- Integration wave 2 (ADR-INT-W2): GPU options unified onto STT-02's runtime-loaded modules (`VV_ANDROID_VULKAN/OPENCL` are deprecated aliases of `VV_GGML_VULKAN/OPENCL`); `GpuBackendGuard`/`FileBackendHealthStore`/`GpuAllowlist`/`chooseAndroidBackend` replaced by the shared `core/platform/backend_policy.dart` + `chooseLlmBackend`; the `[LLM-03/AC2]` unit tests now live in `app/test/unit/extraction/llm_backend_choice_test.dart`.
