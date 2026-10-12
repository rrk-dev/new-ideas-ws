# STT-03 — Whisper Dart FFI Binding & Engine Service

**Workstream:** STT | **Phase:** 2 | **Size:** M | **Depends on:** STT-01, STT-02 | **Source:** §4.2 (FFI / C++ bridge)
**Status:** todo
**Skills:** vv-task-workflow, vv-ffi-bridge, vv-whisper-stt, vv-testing, vv-local-database, vv-pipeline-orchestrator

## Goal
A Dart `SttEngine` implementation that transcribes audio with progress, cancellation and timestamps, without blocking the UI.

## Scope
- [ ] C bridge per `vv-ffi-bridge` → Required bridge functions: `vv_stt_create`, `vv_stt_transcribe_async(wav_path…)` / `vv_stt_transcribe_ranges`, `vv_stt_cancel`, `vv_stt_destroy` (paths, not PCM buffers).
- [ ] Run on a native worker thread; marshal progress + segment callbacks via `NativeCallable.listener` / ports.
- [ ] Parameters: language, translate off, beam size, temperature fallback, initial prompt (vocabulary hints), `no_context`, token timestamps.
- [ ] Output segments with start/end ms and confidence → `transcript_segments` table.
- [ ] Custom vocabulary / initial prompt per profile (e.g., product names, team names).
- [ ] Memory: free model after job unless another STT job queued.

## Acceptance Criteria
- Transcribing a 10-min file shows live progress and segments in the UI; cancel stops within 1 s.
- No UI frame drops > 16 ms during transcription (DevTools trace).
- Integration test runs on device in CI device lab (QA-05) or manually documented.
