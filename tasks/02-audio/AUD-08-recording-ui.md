# AUD-08 — Recording Screen UI

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** AUD-01, AUD-02, SEC-09 | **Source:** §3 (UX)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-testing, vv-extraction-profiles, vv-markdown-vault-export

## Goal
One-tap recording with clear state, live feedback and profile pre-selection.

## Scope
- [ ] Big record/pause/stop controls, elapsed timer, live waveform/level meter.
- [ ] Pre-select extraction profile (or "Auto" — PRF-06) and destination before or after recording.
- [ ] Add bookmarks/markers during recording ("important moment") stored as timestamps, surfaced to the LLM prompt.
- [ ] Title/tags entry post-recording.
- [ ] Quick-start entry points (nice-to-have): home-screen widget, Android quick-settings tile, iOS Control Center control — each must be a deliberate user tap. **No** Shortcuts/App Intents that can run unattended in automations, no scheduled/timer/location starts (SEC-09).
- [ ] Consent confirmation step before recording (SEC-07) and "Recording unavailable during calls" state (SEC-09).
- [ ] Do not open the microphone before the user taps Record (no pre-capture).

## Acceptance Criteria
- Recording starts within 300 ms of tap (measured from tap, after any consent step) — without opening the mic before the tap.
- Markers persisted with correct `at_ms` and `kind = user` (unit test); their display in the transcript view is verified in STT-06.
- Widget tests cover all recorder states.
