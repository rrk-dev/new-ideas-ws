# STT-01 — whisper.cpp iOS Build (Metal / Core ML)

**Workstream:** STT | **Phase:** 2 (Weeks 4–7) | **Size:** M | **Depends on:** FND-06 | **Source:** §4.2, §5 Phase 2
**Status:** in-progress
**Skills:** vv-task-workflow, vv-native-build, vv-whisper-stt, vv-benchmark-eval, vv-decision-records, vv-testing

## Goal
whisper.cpp runs on iOS with GPU acceleration.

## Scope
- [ ] Build whisper.cpp into the shared xcframework with `GGML_METAL=ON`.
- [ ] Evaluate Core ML encoder (`WHISPER_COREML=ON`, ANE) vs Metal-only: speed, first-run compile time, extra model download size (`-encoder.mlmodelc`).
- [ ] Metal shader library embedded; verify on A13 (iPhone 11) through A18.
- [ ] Note in the ADR that master plan §3.1.2's ONNX/ExecuTorch STT alternatives were considered and why whisper.cpp was kept (or spike them if Core ML/Metal results are poor).
- [ ] CPU-only fallback path (needed for background — FND-08).

## Acceptance Criteria
- `whisper-base.en` Q8 transcribes 60 s of audio in < 6 s on iPhone 13 (Metal); numbers recorded for iPhone 11.
- Decision on Core ML encoder documented with benchmark data.
