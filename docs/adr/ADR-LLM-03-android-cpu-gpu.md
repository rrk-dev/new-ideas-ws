# ADR-LLM-03 — Android llama.cpp: CPU kernel variant, GPU backends, threads

- **Status:** Proposed (no NDK, no Android device available; host-verified parts only)
- **Date:** 2026-10-13
- **Task:** LLM-03
- **Deciders:** Claude Code (implementer); pending verifier, device matrix (QA-05) and the user (minimum supported CPU)
- **Supersedes:** — (refines ADR-FND-06 §3, which deferred the CPU-variant decision to STT-02/LLM-03)

## Context
ADR-FND-06 ships one static `libvv_native.so` (ggml + whisper + llama) with a plain **armv8-a**
CPU baseline and a `VV_ANDROID_CPU_ARCH` knob, and leaves Vulkan/OpenCL off. LLM-03 needs
≥ 10 tok/s decode for Llama-3.2-3B Q4 on Snapdragon 8 Gen 3, no crash across the QA-05 matrix,
and failing GPU backends disabled automatically. Constraints: arm64-v8a, API 26+, never SIGILL
on a supported device, offline, Google Play 16 KB pages.

Verified at the pin (llama.cpp v0.6.0 / ggml 0.26.0, `ggml/src/ggml-cpu/ggml-cpu.c`):
`ggml_cpu_has_dotprod()`, `ggml_cpu_has_matmul_int8()`, `ggml_cpu_has_sve()` are **compile-time**
(`__ARM_FEATURE_*`). The Q4_0/IQ4_NL ARM repack paths (`repack.cpp`) and the int8 dot kernels are
only selected when those return 1. So the FND-06 armv8-a baseline runs **no** dotprod/i8mm kernels
and **no** Q4_0 repacking — the main Android CPU speed-ups are compiled out.

## Options
1. **Keep armv8-a baseline** — runs on every arm64 CPU (incl. Cortex-A53), slowest kernels.
2. **Static `armv8.2-a+dotprod` baseline** (`VV_ANDROID_CPU_ARCH`, forwarded to `GGML_CPU_ARM_ARCH`)
   + a runtime guard that refuses to start engines on CPUs without dotprod — one `.so`, keeps the
   FND-06 layout and its "exports only `vv_*`" property. Drops Cortex-A53/A35-only phones.
3. **Runtime dispatch**: `BUILD_SHARED_LIBS=ON` + `GGML_BACKEND_DL=ON` + `GGML_CPU_ALL_VARIANTS=ON`
   — ships `libggml*.so` + one `libggml-cpu-android_armv*.so` per variant, bridge calls
   `ggml_backend_load_all_from_path(nativeLibraryDir)`. Runs everywhere at best speed, but changes
   the FND-06 packaging (Gradle jniLibs, loader, exported symbols, whisper/STT-02 too).
4. `+i8mm` baseline — excludes Cortex-A78/X1-era SoCs (e.g. Snapdragon 7 Gen 1/7+ Gen 2 class).

## Criteria (weights fixed before deciding)
| Criterion | Weight |
|---|---|
| Decode speed on the target SoCs (dotprod/i8mm kernels, Q4_0 repack) | 35% |
| Never SIGILL / crash on a supported device | 30% |
| Packaging/integration churn (FND-06 layout, STT-02, Gradle owned by CI) | 20% |
| Binary size | 15% |

## Evidence
- Code at the pin (above): baseline armv8-a ⇒ no dotprod/i8mm/repack kernels.
- QA-05 matrix (`docs/device-matrix.md`): every Android role (SD 8 Gen 3/8 Elite, SD 7-series,
  Tensor, 4 GB MediaTek+Mali) uses Cortex-A55-or-newer cores ⇒ **dotprod present** on all matrix
  devices (A55/A75/A76/A78/X-series implement Armv8.2 dotprod). i8mm is not universal
  (Armv8.6; A710/A715/X2+). Expected, to be confirmed by the matrix "Dotprod" column (⏳).
- Host: `native/tests/cpu_test.c` checks the HWCAP mapping (`HWCAP_ASIMDDP` bit 20,
  `HWCAP2_I8MM` bit 13, `HWCAP_SVE` bit 22), the guard logic (dotprod build on a NEON-only CPU ⇒
  refused) and the big.LITTLE detection on SD 8 Gen 3 / SD 7 Gen 3 / Tensor G3 cpufreq layouts.
  The bridge's Linux code compiles (`g++ -fsyntax-only`, Linux x86_64 container); the Android build
  itself is ⏳ (no NDK).
- Speed on devices: ⏳ `docs/test-plans/device/LLM-03.md` (baseline vs dotprod build, Q4_0 vs
  Q4_K_M, CPU vs Vulkan/OpenCL).

## Decision
1. **CPU: Option 2** — the Android release build sets `VV_ANDROID_CPU_ARCH=armv8.2-a+dotprod`
   **once the QA-05 "Dotprod" cells and the LLM-03 device rows confirm it**; until then the
   FND-06 default (armv8-a) stays and the device rows compare both builds. The bridge exports
   `vv_cpu_features()` / `vv_cpu_supported()` (runtime HWCAP vs compiled-in ggml features; calling
   them executes no optional instruction) and Dart (`DeviceCapabilities.cpuSupported`,
   `chooseAndroidBackend`) refuses to start STT/LLM on an unsupported CPU — a clear
   "device not supported" instead of SIGILL. `+i8mm` is **not** in the baseline (Option 4
   rejected). Option 3 is the fallback if the product must support A53-only phones
   (**PRODUCT-DECISION**: minimum supported CPU class) — follow-up LLM-10.
2. **Quant for CPU-only Android**: benchmark Q4_0 (repacked to interleaved layouts at load on
   dotprod/i8mm) against Q4_K_M on VV-AND-FLG / VV-AND-7; LLM-08 picks per tier from those rows.
3. **GPU backends optional and off by default**: `VV_ANDROID_VULKAN` / `VV_ANDROID_OPENCL` CMake
   options (→ `GGML_VULKAN` / `GGML_OPENCL`). At runtime the Dart allowlist
   (`kAndroidGpuAllowlist`, shipped **empty**) decides; entries are added only with a passing
   device row. `GpuBackendGuard` writes a durable "pending" marker before a GPU run and clears it
   after; a crash leaves it behind and the next start denylists that backend+GPU; a bridge GPU→CPU
   fallback denylists it too. NNAPI stays out of scope (deprecated).
4. **Threads**: `n_threads = vv_cpu_perf_cores()` — cores faster than the slowest cpufreq
   cluster — and llama.cpp's ggml threadpool is created with a cpumask of exactly those cores
   (non-strict placement), so work stays off the LITTLE cores.
5. **Memory**: mmap loading (`LLAMA_LOAD_MODE_MMAP`). Note from LLM-01: on the CPU path the
   repacked weights live in anonymous memory (3B Q4_K_M peak ≈ 2.3 GiB on the host), so the LMK
   budget check (LLM-07, `ActivityManager.MemoryInfo`) must use the full model size, not the
   Metal-style mmap footprint.

## Consequences
- Positive: the speed-critical kernels become available without changing the FND-06 single-`.so`
  layout; no SIGILL path; GPU backends cannot crash users repeatedly; threads stay on big cores.
- Negative / risks: Cortex-A53/A35-only phones (API 26+ budget devices) would be refused by the
  dotprod build → product decision; GPU backends unmeasured; Linux/Android code paths compiled only
  for x86_64 on the host. `native/build.sh android` does not forward `VV_ANDROID_VULKAN/OPENCL`
  yet (build.sh is owned by the CI/FND agent) — pass them via Gradle `arguments` or extend build.sh.
- Follow-up tasks: LLM-10 (proposed) GGML_BACKEND_DL + CPU_ALL_VARIANTS if A53 support is
  required; CI: forward the GPU options in `native/build.sh android` and add a Vulkan build job.
