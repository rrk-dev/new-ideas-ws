# STT-03 — Whisper Dart FFI Binding & Engine Service

**Workstream:** STT | **Phase:** 2 | **Size:** M | **Depends on:** STT-01, STT-02 | **Source:** §4.2 (FFI / C++ bridge)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-ffi-bridge, vv-whisper-stt, vv-testing, vv-local-database, vv-pipeline-orchestrator

## Goal
A Dart `SttEngine` implementation that transcribes audio with progress, cancellation and timestamps, without blocking the UI.

## Scope
- [x] C bridge per `vv-ffi-bridge` → Required bridge functions: `vv_stt_create`, `vv_stt_transcribe_async(wav_path…)` / `vv_stt_transcribe_ranges`, `vv_stt_cancel`, `vv_stt_destroy` (paths, not PCM buffers). (`native/bridge/vv_whisper.{h,cpp}`)
- [x] Run on a native worker thread; marshal progress + segment callbacks via `NativeCallable.listener` / ports. (`packages/vv_native/lib/src/whisper.dart`; model load/destroy on a helper isolate)
- [x] Parameters: language, translate off, beam size, temperature fallback, initial prompt (vocabulary hints), `no_context`, token timestamps. (`vv_stt_params` / `VvSttParams` / `SttOptions`)
- [x] Output segments with start/end ms and confidence → `transcript_segments` table. (`TranscribeStep` stores `avg_logprob` + `tokens_json`)
- [~] deferred → PRF-01 Custom vocabulary / initial prompt per profile (e.g., product names, team names). Engine side done (`SttOptions.initialPrompt`, `carry_initial_prompt` in every window); the per-profile value comes from PRF-01's "STT hints" field, then `TranscribeStep` passes it.
- [x] Memory: free model after job unless another STT job queued. (`WhisperSttEngine`: kept across consecutive calls, idle unload, `unload()` for `HeavyModelGate.release`)

## Acceptance Criteria
- Transcribing a 10-min file shows live progress and segments in the UI; cancel stops within 1 s.
- No UI frame drops > 16 ms during transcription (DevTools trace).
- Integration test runs on device in CI device lab (QA-05) or manually documented.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/STT-03-whisper-ffi-engine (stacked on task/STT-02-whisper-android) · **Date:** 2026-10-13
- **Summary:** C ABI `native/bridge/vv_whisper.{h,cpp}` (included by `vv_bridge.h`):
  `vv_stt_create/transcribe_async/transcribe_ranges/cancel/destroy/free_segment/last_error`,
  struct-sized params, one native worker thread per job (`VV_E_BUSY` for a second job), atomic
  cancel checked by whisper's `abort_callback` + `encoder_begin_callback`, heap-owned segment
  payloads freed by the callee, range concatenation with per-range time mapping (STT-04 ready),
  English-only models skip language auto-detection. Dart: `VvWhisper` (ffigen bindings regenerated,
  `NativeCallable.listener` per job, model load/destroy via `Isolate.run`, stream waits for all
  segments using `n_segments` from `on_done`). App: `SttEngine` extended (`onSegment`,
  `SttOptions`, segment confidence/tokens — fakes updated), `WhisperSttEngine`
  (`app/lib/features/transcription/data/`), `failureFromVvCode` (`app/lib/core/errors/native_failures.dart`),
  `TranscribeStep` persists confidence/tokens and passes the language. Tests: ctests `vv_stt_*`
  (also clean under ASan+UBSan: `native/tests/sanitize.sh`), `packages/vv_native/test/whisper_host_test.dart`,
  `app/test/native/whisper_stt_engine_test.dart`, `app/test/unit/transcription/`,
  device test `app/integration_test/stt_engine_test.dart`.
- **Host numbers (M3 Pro, macOS 27.0.1):** jfk 11 s with tiny.en in 85 ms (Metal); cancel →
  `VV_E_CANCELLED` 17 ms Metal / 224 ms CPU (tiny.en), 53 ms / 336 ms (base.en-q8_0); RSS flat
  over 15 load/dispose cycles (< 64 MB growth); ASan/UBSan: 0 reports (Metal + CPU runs).
- **Acceptance evidence:**
  - AC1: ⏳ test: [STT-03/AC1]; device: docs/test-plans/device/STT-03.md
  - AC2: ⏳ test: [STT-03/AC2]; device: docs/test-plans/device/STT-03.md
  - AC3: ⏳ test: [STT-03/AC3]; device: docs/test-plans/device/STT-03.md
- **Decisions:** none new (follows vv-ffi-bridge; backend choice per ADR-STT-01/02).
- **Follow-ups:** wire `WhisperSttEngine` into the worker's `PipelineEnginesFactory` with the
  installed model path (MDL-02) and `HeavyModelGate(release: … stt.unload())` (owner of pipeline
  bootstrap / APP-04 live job view); per-profile vocabulary from PRF-01; CI native-host job:
  fetch tiny.en + jfk and run `native/tests/sanitize.sh` (CI owner); live segment list UI (STT-06).
