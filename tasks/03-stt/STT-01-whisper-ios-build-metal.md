# STT-01 — whisper.cpp iOS Build (Metal / Core ML)

**Workstream:** STT | **Phase:** 2 (Weeks 4–7) | **Size:** M | **Depends on:** FND-06 | **Source:** §4.2, §5 Phase 2
**Status:** in-progress
**Skills:** vv-task-workflow, vv-native-build, vv-whisper-stt, vv-benchmark-eval, vv-decision-records, vv-testing

## Goal
whisper.cpp runs on iOS with GPU acceleration.

## Scope
- [x] Build whisper.cpp into the shared xcframework with `GGML_METAL=ON`. (config in `native/build.sh ios` / `native/CMakeLists.txt`; compile needs Xcode → device rows)
- [x] Evaluate Core ML encoder (`WHISPER_COREML=ON`, ANE) vs Metal-only: speed, first-run compile time, extra model download size (`-encoder.mlmodelc`). (host measured; iPhone rows ⏳)
- [x] Metal shader library embedded; verify on A13 (iPhone 11) through A18. (`GGML_METAL_EMBED_LIBRARY=ON`, host ctest `stt_backend_gpu`; A13–A18 runs ⏳ device rows)
- [x] Note in the ADR that master plan §3.1.2's ONNX/ExecuTorch STT alternatives were considered and why whisper.cpp was kept (or spike them if Core ML/Metal results are poor).
- [x] CPU-only fallback path (needed for background — FND-08). (`use_gpu=false`; host ctest `stt_backend_cpu`; exposed to Dart in STT-03)

## Acceptance Criteria
- `whisper-base.en` Q8 transcribes 60 s of audio in < 6 s on iPhone 13 (Metal); numbers recorded for iPhone 11.
- Decision on Core ML encoder documented with benchmark data.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/STT-01-whisper-ios · **Date:** 2026-10-13
- **Summary:** iOS whisper build configuration on the FND-06 superproject: Metal with embedded
  shaders (`native/build.sh ios`), new opt-in `VV_WHISPER_COREML` CMake option (→
  `WHISPER_COREML` + `WHISPER_COREML_ALLOW_FALLBACK`, forwarded by `VV_WHISPER_COREML=ON
  native/build.sh ios`), CPU-only path via `use_gpu=false`. Host tool
  `native/tests/stt_backends.cpp` (ctests `stt_backend_cpu`, `stt_backend_gpu`,
  `stt_backend_coreml-fallback`; skipped without `VV_TEST_MODELS_DIR`) + bench
  `tools/bench/stt_host_bench.sh` (raw: `tools/bench/results/2026-10-13-stt-host-backends.jsonl`).
  Shared internal WAV reader `native/bridge/vv_wav.h`. Static config tests
  `tools/ci/tests/test_stt_native_build.py`. No Xcode/iPhone was available: the iOS build and all
  iPhone numbers are device rows.
- **Host numbers (M3 Pro, base.en q8_0, 60 s, greedy, 4 threads, 5 runs median):** Metal 1.03 s
  (RTF 0.017), Core ML enc + Metal 1.10 s, CPU-only 4.98 s, Core ML enc + CPU 1.97 s; cold first
  load Metal 5.7 s, Core ML 10.6 s; Core ML companion +39 MB (base.en); dylib +7.6 KB.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/STT-01.md
  - AC2: ⏳ artifact: docs/adr/ADR-STT-01-ios-coreml-vs-metal.md; test: [STT-01/AC2]; device: docs/test-plans/device/STT-01.md
- **Decisions:** ADR-STT-01-ios-coreml-vs-metal (Proposed: Metal-only for v1).
- **Follow-ups:** CI native-host job should run `tools/ci/fetch_test_models.sh ggml-tiny.en.bin jfk.wav`
  and export `VV_TEST_MODELS_DIR` so the `stt_backend_*` ctests run instead of skipping (CI owner);
  iOS 16.0 vs 16.4 minimum (ADR-FND-06, user).
