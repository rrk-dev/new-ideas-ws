# VOX-03 — Tap-to-talk questions with spoken answers

**Workstream:** Product Phase 3 | **Phase:** 6 | **Size:** L | **Depends on:** VOX-02, ASK-04, STT-03, SEC-09 | **Source:** User request 2026-10-18 (Phase 3, not started)
**Status:** todo
**Skills:** vv-task-workflow, vv-audio-capture, vv-whisper-stt, vv-llm-inference, vv-flutter-architecture, vv-privacy-security, vv-testing

## Goal
The user taps a button, asks "does it have any action items?" or "give me the summary", and Lumen answers aloud from the processed recording.

## Scope
- [ ] Tap-to-talk capture of one short utterance (explicit tap, visible indicator, no wake word, no always-listening); recording policy per SEC-09.
- [ ] Transcribe the utterance with the loaded Whisper model, then unload it before any LLM is loaded (one model in memory at a time).
- [ ] Deterministic intent router: "action items", "summary", "key points" read the saved extraction directly, with no LLM; works on every device tier.
- [ ] Any other question goes to Ask (High tier only); otherwise a spoken and written "not available" message.
- [ ] Spoken answer through VOX-02; a typed question with a spoken answer works too.
- [ ] Stop speaking when the user taps the mic again; no speaker-to-mic feedback loop.

## Acceptance Criteria
- Saying "action items" on a recording with action items reads them; on one without, the answer is "none found".
- The router intents run without loading the LLM (test asserts no LLM load).
- Whisper and the LLM are never resident together during a voice question.
- The mic starts only after an explicit tap and shows a visible indicator.
- Latency per tier (first audio) is measured and recorded on a device.

## Notes
Do not implement yet. Phase 3 backlog. English only.
