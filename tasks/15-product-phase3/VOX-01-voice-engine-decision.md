# VOX-01 — Text-to-speech engine decision (OS voices vs Piper vs Kokoro)

**Workstream:** Product Phase 3 | **Phase:** 6 | **Size:** M | **Depends on:** ASK-03, SEC-02 | **Source:** User request 2026-10-18 (talk to the processed notes; Phase 3, not started)
**Status:** todo
**Skills:** vv-task-workflow, vv-decision-records, vv-privacy-security, vv-native-build, vv-benchmark-eval

## Goal
Record which text-to-speech engine Lumen uses to read summaries, action items and answers aloud, backed by measured size, latency, memory and licence evidence.

## Scope
- [ ] Options framed: OS voices (AVSpeechSynthesizer, Android `TextToSpeech`), Piper (ONNX voices), Kokoro-82M via sherpa-onnx.
- [ ] Licence review of each engine, its phonemizer (espeak-ng is GPL: verify) and each candidate voice; distribution compatibility with a closed-source app.
- [ ] Measurements on a real iPhone, a Mac and an Android device: time to first audio, real-time factor, RAM, battery per minute of speech, binary and model size.
- [ ] Offline guarantee: Android must use voices that need no network; document how it is enforced.
- [ ] Decide the staged plan (default: OS voices first, optional better-voice pack later) and record version-sensitive facts verified against official docs.

## Acceptance Criteria
- ADR-VOX-01 is Proposed with weighted criteria and the measured evidence for every option.
- The licence review names the licence of every shipped component and voice, and flags any GPL dependency.
- The ADR states the offline guarantee per platform and how SEC-02 keeps proving it.

## Notes
Do not implement here. Planning only; added 2026-10-18 and deliberately deferred because voice adds CPU, RAM and size.
