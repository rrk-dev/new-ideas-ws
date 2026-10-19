# VOX-02 — Read aloud: summary and action items

**Workstream:** Product Phase 3 | **Phase:** 6 | **Size:** M | **Depends on:** VOX-01, APP-05, FND-09 | **Source:** User request 2026-10-18 (Phase 3, not started)
**Status:** todo
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-ffi-bridge, vv-privacy-security, vv-testing

## Goal
A user can tap a button on a processed recording to have the summary or the action items read aloud, with play, pause and stop.

## Scope
- [ ] `TtsEngine` domain interface and a fake, per `vv-flutter-architecture`; the engine chosen in VOX-01 behind it.
- [ ] Platform implementations (Pigeon channels) for iOS, macOS and Android using only offline voices.
- [ ] Read-aloud controls on the recording detail (summary, action items) with progress and a visible speaking indicator.
- [ ] Audio session handling: stop on a phone/VoIP call, on the mic starting, and on interruptions; never auto-resume a recording.
- [ ] Spoken text is never logged; settings for voice and speed; accessibility checked against screen readers.

## Acceptance Criteria
- Tapping Read aloud speaks the saved summary or action items, and Stop ends it within one second.
- No network request is made while speaking (SEC-02 proxy test).
- A call or the mic starting stops speech, and speech never resumes by itself.
- Spoken text appears in no log at INFO or above.

## Notes
Do not implement yet. Phase 3 backlog.
