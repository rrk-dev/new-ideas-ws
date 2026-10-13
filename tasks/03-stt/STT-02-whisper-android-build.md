# STT-02 — whisper.cpp Android Build (NDK / Vulkan)

**Workstream:** STT | **Phase:** 2 | **Size:** M | **Depends on:** FND-06 | **Source:** §4.2, §5 Phase 2
**Status:** in-progress
**Skills:** vv-task-workflow, vv-native-build, vv-whisper-stt, vv-benchmark-eval, vv-testing

## Goal
whisper.cpp runs on Android with the fastest available backend per device.

## Scope
- [ ] arm64-v8a build with NEON + dotprod (+ i8mm where available), runtime CPU feature detection (multiple variants or `GGML_CPU_ALL_VARIANTS`).
- [ ] Evaluate Vulkan backend on Adreno/Mali — known driver issues; gate behind an allowlist if unstable.
- [ ] Evaluate OpenCL (Adreno) backend.
- [ ] NNAPI note: NNAPI is deprecated in Android 15; document that NPU delegates (QNN/LiteRT) are out of scope for v1 unless spike proves value.
- [ ] Thread count tuning (big cores only).

## Acceptance Criteria
- Benchmarks on Snapdragon 8 Gen 2/3 and a Snapdragon 7-series device recorded (RTF per backend).
- Backend auto-selection with safe CPU fallback; no crashes on Mali test device.
