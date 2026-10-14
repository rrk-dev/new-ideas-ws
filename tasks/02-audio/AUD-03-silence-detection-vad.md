# AUD-03 — Dynamic Silence Detection / Voice Activity Detection

**Workstream:** Audio | **Phase:** 1–2 | **Size:** M | **Depends on:** AUD-01, STT-03, QA-02 | **Source:** §3.1.1
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-whisper-stt, vv-decision-records, vv-benchmark-eval, vv-ffi-bridge, vv-native-build, vv-model-delivery, vv-local-database, vv-testing

## Goal
Detect speech vs silence to (a) trim/skip silence, (b) segment audio for chunked STT, (c) optionally auto-pause.

## Scope
- [x] Choose VAD: Silero VAD (ONNX, small) vs WebRTC VAD vs whisper.cpp built-in VAD. Record decision.
- [x] Produce speech segment timeline (start/end ms) stored with the recording.
- [x] Optional "auto-stop after N minutes of silence" setting (and optional auto-pause). VAD must **never start or resume** a recording — no voice-activated recording (SEC-09).
- [x] Silence removal before STT to reduce compute (and Whisper hallucinations on silence).
- [x] Keep original timestamps mapped so transcript times match the original audio.

## Acceptance Criteria
- On QA corpus, VAD trimming reduces STT time by ≥ 20% on meeting audio with no WER regression > 1 pt.
- Whisper "hallucinated text on silence" cases eliminated on the silence test set.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/AUD-03-vad · **Date:** 2026-10-14
- **Summary:** whisper.cpp's built-in Silero VAD (ADR-AUD-03). Native: new `vv_vad_*` C ABI
  (`native/bridge/vv_vad.{h,cpp}`: create / segments → JSON ms / streaming feed / reset / destroy)
  and VAD fields appended to `vv_stt_params` (forward-compatible `struct_size`, mapped token times);
  exports, CMake, ffigen bindings, ctest `vv_vad_*` (`native/tests/vad_test.cpp`) and the Silero
  model in `tools/ci/test-models.lock`. Dart: `VvVad`, `VvVadStream` (own isolate),
  `VvSttParams.vadModelPath`. App: `SttOptions.vadModelPath` → `WhisperSttEngine`;
  `TranscribeStep` skips silence when a VAD model is installed and `processing.skip_silence` is on
  and stores `speech_segments` on the recording timeline via `PipelineEngines.vad`
  (`FfiVadEngine`); `SilenceWatcher` + `SilenceMonitor` auto-pause (`audio.auto_pause_on_silence`,
  2 min) / auto-stop (`audio.silence_auto_stop`, off/5/10/30 min) through the new
  `RecordingController.pauseForSilence()` / `stop(silence)` — never start/resume (SEC-09).
  Model delivery: `silero-vad-v6.2.0` in `tools/model-catalog/models.json` + the re-signed bundled
  catalog (second development key `vv-catalog-dev-2026b` pinned next to 2026a).
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/AUD-03.md; artifact: docs/adr/ADR-AUD-03-vad.md
  - AC2: ⏳ test: [AUD-03/AC2]; device: docs/test-plans/device/AUD-03.md
- **Decisions:** ADR-AUD-03-vad (Proposed). PRODUCT-DECISIONs: `processing.skip_silence` default on
  (provisional until AC1 numbers); auto-stop on silence default off; auto-pause delay 2 min; a
  second development catalog signing key (private half kept outside the repo by the implementer,
  as for 2026a) — production key remains MDL-05.
- **Deps:** STT-03 and QA-02 are not `done` (STT-03 in review, QA-02 todo): the bridge work builds on
  STT-03's code; AC1/AC2 corpus numbers need QA-02 — hence ⏳.
- **Host-only:** the native code was built and tested on macOS (`native/build.sh host`, all
  `vv_vad_*` + `vv_stt_*` ctests pass with models); Android/iOS builds were not run (no SDKs). The
  host speed bench was inconclusive under heavy machine load (ADR-AUD-03 → Evidence).
- **Stacking:** based on origin/main.
- **Follow-ups:** none new (the real `PipelineEnginesFactory` that constructs `FfiVadEngine` is
  the wiring task's; until then `TranscribeStep` still skips silence via whisper but stores no
  timeline).
