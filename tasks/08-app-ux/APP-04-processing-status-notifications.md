# APP-04 — Processing Status & Local Notifications

**Workstream:** App UX | **Phase:** 2–3 | **Size:** S | **Depends on:** FND-05 | **Source:** Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-pipeline-orchestrator, vv-flutter-architecture, vv-background-execution, vv-testing

## Goal
Users always know where a recording is in the pipeline and when the note is ready.

## Scope
- [ ] Per-recording progress (step, %, ETA based on measured RTF / tok/s).
- [ ] Global queue indicator.
- [ ] Local notifications: "Note ready — Meeting with …" (tap opens result), failures with action.
- [ ] Notification content respects privacy setting (generic text on lock screen by default).

## Acceptance Criteria
- ETA within ±30% on test devices; notifications deep-link correctly on both platforms.
