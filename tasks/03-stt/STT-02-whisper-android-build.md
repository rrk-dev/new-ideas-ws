# STT-02 — whisper.cpp Android Build (NDK / Vulkan)

**Workstream:** STT | **Phase:** 2 | **Size:** M | **Depends on:** FND-06 | **Source:** §4.2, §5 Phase 2
**Status:** review
**Skills:** vv-task-workflow, vv-native-build, vv-whisper-stt, vv-benchmark-eval, vv-testing

## Goal
whisper.cpp runs on Android with the fastest available backend per device.

## Scope
- [x] arm64-v8a build with NEON + dotprod (+ i8mm where available), runtime CPU feature detection (multiple variants or `GGML_CPU_ALL_VARIANTS`). (`VV_GGML_BACKEND_DL` + bridge loader `vv_backends_load`; host-verified, Android default flip after device rows)
- [x] Evaluate Vulkan backend on Adreno/Mali — known driver issues; gate behind an allowlist if unstable. (`VV_GGML_VULKAN` module + `BackendPolicy` allowlist/denylist + crash sentinel; device numbers ⏳)
- [x] Evaluate OpenCL (Adreno) backend. (`VV_GGML_OPENCL` module with Adreno kernels, preferred over Vulkan when allowed; device numbers ⏳)
- [x] NNAPI note: NNAPI is deprecated in Android 15; document that NPU delegates (QNN/LiteRT) are out of scope for v1 unless spike proves value. (ADR-STT-02)
- [x] Thread count tuning (big cores only). (bridge `vv::perf_cores()` in `vv_threads.h` as the `n_threads <= 0` default + Dart `defaultThreads`; host sweep; per-device sweep ⏳)

## Acceptance Criteria
- Benchmarks on Snapdragon 8 Gen 2/3 and a Snapdragon 7-series device recorded (RTF per backend).
- Backend auto-selection with safe CPU fallback; no crashes on Mali test device.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/STT-02-whisper-android (stacked on task/STT-01-whisper-ios) · **Date:** 2026-10-13
- **Summary:** Runtime backend selection for Android on the FND-06 superproject:
  `VV_GGML_BACKEND_DL` (ggml shared + `GGML_CPU_ALL_VARIANTS` modules, 16 KB flags on every .so,
  `c++_shared` in `native/build.sh android`), `VV_GGML_VULKAN` / `VV_GGML_OPENCL` (only as DL
  modules). Bridge `native/bridge/vv_backend.cpp`: `vv_backends_load(lib_dir, gpu_mask)` (probes
  CPU variants by `ggml_backend_score`, loads GPU modules only when allowed; works with
  APK-embedded libs), `vv_backends_describe`, `vv_backends_dynamic`
  (+ `vv_error.h`, internal `vv_threads.h`). Dart: `VvNative.loadBackends/describeBackends` (ffigen
  regenerated), `app/lib/core/platform/backend_policy.dart` (allow/deny rules, background → CPU,
  crash sentinel `GpuTrialGuard`, `defaultThreads`). Tests: ctests `vv_backends_*`, Dart
  `[STT-02/AC2]`, pytest `test_stt_native_build.py`. No NDK/devices: Android builds and numbers are
  device rows.
- **Host numbers (M3 Pro, base.en q8_0, 60 s, CPU, 4 threads, loaded machine):** armv8-a baseline
  3.15 s vs runtime-picked dotprod+i8mm variant 2.52 s (−20 %); thread sweep best at 4 (2.24 s),
  12 threads 15.9 s median.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/STT-02.md
  - AC2: ⏳ test: [STT-02/AC2]; device: docs/test-plans/device/STT-02.md
- **Decisions:** ADR-STT-02-android-backends (Proposed).
- **Follow-ups:** STT-08 (proposed) GPU identity probe for `GpuInfo` (Android renderer/driver via
  Pigeon; iOS `MTLDevice.name`); flip Android default to `VV_GGML_BACKEND_DL=ON` + Gradle
  `c++_shared` and verify AGP packages the MODULE libs (after device rows); KleidiAI vendoring spike;
  CI: fetch `ggml-tiny.en.bin`/`jfk.wav` in the native-host job and add a `-DVV_GGML_BACKEND_DL=ON`
  host ctest run (CI owner).


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (387 files, 0 changed) · analyze ✅ (zero issues) · Flutter tests ✅ (785 passed, 24 skipped; coverage 93.3%, gate 80%) · pytest ✅ (66 passed) · native host ✅ (fresh native/build.sh host; model-backed ctest 21 passed, 2 explicitly skipped) · egress ✅ · recording policy ✅ · tasks validate ✅ (85 tasks, 0 problems) · CI run: local. No Xcode/NDK/mobile SDKs; no mobile/device reruns.
- **Acceptance criteria:**
  - AC1: ⏳ Snapdragon 8 Gen 2, 8 Gen 3 and 7-series backend RTF/thread measurements have documented rows; none has a result.
  - AC2: ✅ `[STT-02/AC2]` policy and host FFI tests exercise OpenCL/Vulkan preference, denylist, unknown GPU, missing module, background/forced CPU and crash persistence. Native backend ctests passed; Mali and Android APK/16 KB/oldest CPU checks remain ⏳.
- **Mutation sanity check:** Removed the CMake runtime-optional GPU guard diagnostic: tagged `test_STT_02_gpu_backends_only_as_runtime_modules` failed (1 failed); restored with git checkout.
- **Adversarial checks:** Empty shipped Android allowlist selects CPU. Crash sentinel disables an interrupted first trial; CPU remains available. Reviewed optional module loader, pins and mutually exclusive fixed-arch/runtime-variant flags. Independently built native/build/host-dl with VV_GGML_BACKEND_DL=ON: 22/23 ctests passed; only the non-Core-ML configuration skipped its Core ML test. Missing module directory returned VV_E_BACKEND and retry succeeded.
- **Device evidence:** Reviewed every row in `docs/test-plans/device/STT-02.md`. Result/date/tester cells are unfilled; no physical run is represented as PASS. The user explicitly permits a provisional verifier PASS with these rows pending.
- **Skill/rule compliance:** Read AGENTS.md, verifier prompt, workflow/verification skills and all task-listed skills; reviewed the merged implementation at main (no unmerged task diff). Pins checked against local headers. RTK.md is referenced by the supplied instructions but absent. Product code/tests unchanged after temporary mutations; no criteria weakened, GitHub API/gh, pushes, git config edits or model commits.
- **Issues found:** none in the verified host implementation; physical acceptance remains pending.
- **Pending for done:** STT-02: FAIL AC1: still pending (⏳) — cannot be done | STT-02: FAIL AC1: device row in docs/test-plans/device/STT-02.md has no PASS result with a date | STT-02: FAIL AC2: still pending (⏳) — cannot be done | STT-02: FAIL AC2: device row in docs/test-plans/device/STT-02.md has no PASS result with a date | STT-02: FAIL dependency FND-06 is not done | STT-02: FAIL FND-03 (CI / test framework) must be done before any non-bootstrap task | STT-02: FAIL QA-01 (CI / test framework) must be done before any non-bootstrap task | refusing to set STT-02 to done: 7 problem(s) (see vv-task-verify)
