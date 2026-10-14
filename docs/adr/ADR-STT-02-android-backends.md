# ADR-STT-02 — Android whisper.cpp backends: runtime CPU variants, GPU gating, threads

- **Status:** Proposed (host-verified mechanism; no NDK, no Android device — all Android numbers
  pending in `docs/test-plans/device/STT-02.md`)
- **Date:** 2026-10-13
- **Task:** STT-02 (decides the item ADR-FND-06 §3 deferred to "STT-02 / LLM-03 measurements")
- **Deciders:** Claude Code (implementer); pending independent verifier + device run
- **Supersedes:** — (refines ADR-FND-06 §3; that ADR stays valid for the default build)

## Context
Android arm64 devices range from Cortex-A53/A55-only phones (armv8.0/8.2, some without dotprod)
to Snapdragon 8 Gen 3 / Dimensity 9300 (armv9, i8mm, SVE2). FND-06 ships one static
`libvv_native.so` compiled for plain **armv8-a NEON** so it can never SIGILL — but that leaves
dotprod/i8mm kernels unused on every modern phone. GPUs: Adreno (Qualcomm) and Mali (Arm,
Samsung Exynos/Tensor/MediaTek); Vulkan drivers on both have a history of crashes and
miscompiles with ggml compute shaders, OpenCL exists only on Adreno (and some Mali) with a
vendor `libOpenCL.so` that is not part of the NDK. NNAPI is deprecated as of Android 15.
Constraints: no SIGILL on any supported device, no crash at startup on a bad GPU driver,
CPU always available (and mandatory while backgrounded), 16 KB pages, offline.

## Options
**CPU**
1. *Static armv8-a baseline* (FND-06 default) — one `.so`, slowest kernels.
2. *Static `GGML_CPU_ARM_ARCH=armv8.2-a+dotprod`* — one `.so`, faster, **SIGILLs** on any supported
   device without dotprod (needs the whole device matrix to have it).
3. *Runtime variants* — `GGML_BACKEND_DL` + `GGML_CPU_ALL_VARIANTS`: ggml builds
   `libggml-cpu-android_armv8.0_1 / 8.2_1 (dotprod) / 8.2_2 (+fp16) / 8.6_1 (+i8mm) / 9.0_1 (+SVE2) /
   9.2_x (+SME)`; each exports `ggml_backend_score()` that checks the running CPU; the best one is
   loaded. Ships ~7 CPU modules + `libggml.so` + `libggml-base.so` + `libc++_shared.so`.

**GPU** — (a) none; (b) Vulkan (`GGML_VULKAN`); (c) OpenCL with Adreno kernels (`GGML_OPENCL`,
`GGML_OPENCL_USE_ADRENO_KERNELS`); (d) NPU delegates (QNN, LiteRT/NNAPI) — **out of scope for
v1**: NNAPI is deprecated in Android 15, QNN/LiteRT would need a second runtime and model format,
and whisper.cpp has no maintained delegate. Revisit only via a separate spike if device numbers
show the CPU/GPU paths miss the budget. KleidiAI (`GGML_CPU_KLEIDIAI`) is a promising CPU option
but downloads sources at configure time (FetchContent) — needs vendoring before it can be
evaluated reproducibly (follow-up).

## Criteria (weights fixed before measuring)
| Criterion | Weight |
|---|---|
| Never crash / SIGILL on a supported device | 30% |
| RTF on Snapdragon 8 Gen 2/3 and 7-series | 25% |
| Background (CPU) speed | 15% |
| APK/install size | 15% |
| Build/maintenance complexity | 15% |

## Evidence
**Host (indicative)** — Apple M3 Pro, macOS 27.0.1, whisper.cpp v1.9.5 + ggml 0.26.0,
`ggml-base.en-q8_0.bin`, `jfk.wav` tiled to 60 s, greedy, 4 threads, CPU only, no BLAS, 5 runs;
heavily loaded machine (load average 20–110 from parallel agents) → treat as relative only.
Raw: `tools/bench/results/2026-10-13-stt-host-cpu-variants.jsonl`, `…-stt-host-threads.jsonl`.

| Build (CPU path) | `whisper_full` 60 s, median (min–max) | RTF |
|---|---|---|
| static, `GGML_CPU_ARM_ARCH=armv8-a` (= FND-06 Android baseline) | 3.15 s (2.70–3.41) | 0.053 |
| `VV_GGML_BACKEND_DL=ON`, loader picked `ggml-cpu-apple_m2_m3` (dotprod+i8mm) | **2.52 s** (2.01–2.67) | 0.042 |

Thread sweep (static host build, 6 P-cores + 6 E-cores, same model): 1 → 6.36 s, 2 → 5.09 s,
**4 → 2.24 s**, 6 → 3.33 s, 8 → 2.94 s, 12 → 15.9 s (max 514 s: oversubscription with E-cores
and a busy machine). More threads than performance cores is harmful; default
`n_threads = min(perf cores, 4)`, re-tune per device tier on the Android devices.

Mechanism verified on the host (ctest, both `native/build/host` static and
`native/build/host-dl` with `-DVV_GGML_BACKEND_DL=ON`): `vv_backends_cpu-only` (mask 0 → no GPU
module loaded), `vv_backends_gpu` (Metal module loaded only when allowed, idempotent),
`vv_backends_missing-dir` (modules absent → `VV_E_BACKEND`, no crash, retry works),
`stt_backend_cpu/gpu` (jfk keywords) and the Dart FFI test `[STT-02/AC2]`.
Host DL layout sizes: `libvv_native` 140 KB, `libggml-base` 736 KB, `libggml` 59 KB,
3 Apple CPU variants × 889 KB, `libggml-metal.so` 5.3 MB (Android: ⏳).

**Android:** not built (no NDK on the authoring machine), not run on devices. ⏳

## Decision (Proposed)
1. **CPU: Option 3 (runtime variants) for Android**, behind `VV_GGML_BACKEND_DL` (default **OFF**
   until the device rows pass, then flip the Android default in `native/build.sh` /
   `packages/vv_native/android/build.gradle`). The bridge's `vv_backends_load()` probes the variant
   modules by name (compiled-in list from `GGML_AVAILABLE_BACKENDS`) relative to the directory of
   `libvv_native.so` — this also works for APK-embedded (non-extracted) libs, which ggml's own
   directory-scanning `ggml_backend_load_all_from_path()` does not. Static builds (iOS, current
   Android default) keep working unchanged (`vv_backends_load` is a no-op there).
   `VV_ANDROID_CPU_ARCH` and DL are mutually exclusive (CMake error).
2. **GPU: built only as runtime modules, gated by a Dart allowlist** — `VV_GGML_VULKAN` /
   `VV_GGML_OPENCL` refuse to configure without DL, so a GPU driver is never touched unless
   `BackendPolicy` (`app/lib/core/platform/backend_policy.dart`) sets its bit in the
   `vv_backends_load` mask. The shipped allowlist for Android is **empty** (CPU everywhere) until
   the device benchmarks justify an entry; preference order when several are allowed:
   OpenCL (Adreno) → Vulkan. A crash sentinel (`GpuTrialGuard`) disables a backend whose first
   use never completed. Background → CPU always.
3. **Threads:** bridge-internal `vv::perf_cores()` (`native/bridge/vv_threads.h`; cores outside the slowest cluster from
   `cpuinfo_max_freq`; Apple `hw.perflevel0.physicalcpu`) → `defaultThreads()` = min(perf, 4).
4. **NNAPI / QNN / LiteRT: out of scope for v1** (see Options).

To become **Accepted**: Android rows in `docs/test-plans/device/STT-02.md` (8 Gen 2/3, 7-series,
Mali device: RTF per backend, no crash with the shipped allowlist and with GPU forced on).

## Consequences
- Positive: modern phones get dotprod/i8mm kernels without risking SIGILL on old ones; a GPU
  driver bug can at worst disable GPU for that device, not crash the app at startup; one code path
  (`vv_backends_load`) for STT and LLM (llama.cpp needs the same call before `llama_model_load`).
- Negative / risks (with mitigation):
  - More `.so` files (≈ 7 CPU variants ≈ 6–7 MB unstripped estimate on Android, plus
    `libc++_shared.so`) → measure in REL-03; drop rarely-matched variants if size matters.
  - AGP must package the ggml **MODULE** libraries; if `externalNativeBuild` only packages SHARED
    targets, copy them into `jniLibs` from the CMake output (device row checks the APK listing).
  - Multiple `.so` with `c++_static` would duplicate libc++ state → DL builds use
    `ANDROID_STL=c++_shared` (`native/build.sh`); Gradle arguments must match when flipped.
  - Vulkan needs `glslc` + Vulkan headers matching the pin; OpenCL needs Khronos headers and an
    NDK-built `libOpenCL.so` ICD loader at build time (llama.cpp `docs/build.md` → OpenCL/Android);
    the vendor `libOpenCL.so` may be missing on device — the module then fails `dlopen` and the
    loader skips it (CPU fallback).
  - GPU identity on Android (renderer/driver string for the allowlist) needs a platform probe
    (follow-up STT-08 proposal); until then `GpuInfo` is null → CPU.
- Coordination: the parallel LLM-03 branch (`task/LLM-03-llama-android`, ADR-LLM-03) adds
  *static* `VV_ANDROID_VULKAN` / `VV_ANDROID_OPENCL` options, its own Dart backend policy and an
  exported `vv_cpu_perf_cores()`. This ADR keeps perf-core detection bridge-internal (no symbol
  clash) and argues GPU backends must be DL modules (a statically linked OpenCL backend makes
  `libvv_native.so` fail to load on devices without `libOpenCL.so`, and static Vulkan enumerates
  devices on first registry access, before any allowlist). Whichever lands second must reconcile
  the option names and keep one Dart policy for STT and LLM.
- Follow-up tasks: device benchmarks (this task's rows); flip the Android DL default; GPU
  identity probe; KleidiAI vendoring spike; LLM-03 reuses `vv_backends_load`.
