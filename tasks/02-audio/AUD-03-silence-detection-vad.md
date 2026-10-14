# AUD-03 — Dynamic Silence Detection / Voice Activity Detection

**Workstream:** Audio | **Phase:** 1–2 | **Size:** M | **Depends on:** AUD-01, STT-03, QA-02 | **Source:** §3.1.1
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-whisper-stt, vv-decision-records, vv-benchmark-eval, vv-ffi-bridge, vv-native-build, vv-model-delivery, vv-local-database, vv-testing

## Goal
Detect speech vs silence to (a) trim/skip silence, (b) segment audio for chunked STT, (c) optionally auto-pause.

## Scope
- [ ] Choose VAD: Silero VAD (ONNX, small) vs WebRTC VAD vs whisper.cpp built-in VAD. Record decision.
- [ ] Produce speech segment timeline (start/end ms) stored with the recording.
- [ ] Optional "auto-stop after N minutes of silence" setting (and optional auto-pause). VAD must **never start or resume** a recording — no voice-activated recording (SEC-09).
- [ ] Silence removal before STT to reduce compute (and Whisper hallucinations on silence).
- [ ] Keep original timestamps mapped so transcript times match the original audio.

## Acceptance Criteria
- On QA corpus, VAD trimming reduces STT time by ≥ 20% on meeting audio with no WER regression > 1 pt.
- Whisper "hallucinated text on silence" cases eliminated on the silence test set.
