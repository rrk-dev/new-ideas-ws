# FND-08 — Background Processing Guardrails (iOS & Android)

**Workstream:** Foundation | **Phase:** 4 (design in Phase 2) | **Size:** L | **Depends on:** FND-05, STT-03, LLM-04 | **Source:** §5 Phase 4
**Status:** todo
**Skills:** vv-task-workflow, vv-background-execution, vv-pipeline-orchestrator, vv-flutter-architecture, vv-whisper-stt, vv-llm-inference, vv-testing

## Goal
Transcription/extraction continue or safely pause when the app is backgrounded, within each OS's rules.

## Scope
- [ ] iOS: `beginBackgroundTask` for short continuation; `BGProcessingTask` (requires-external-power option) for long jobs; checkpoint before expiration handler fires.
- [ ] iOS: evaluate keeping processing alive while an audio session is active (only legitimate during recording).
- [ ] iOS: GPU (Metal) work is not permitted in background — fall back to CPU or pause and resume on foreground.
- [ ] Android: foreground service (type `dataSync` (API ≤ 34) / `mediaProcessing` (API 35+), 6 h/24 h limit with `onTimeout`) with progress notification; WorkManager for deferred jobs.
- [ ] Thermal state & low-power mode awareness: throttle or defer.
- [ ] User setting: "Process only while charging" / "Process now".

## Acceptance Criteria
- iOS: backgrounding during a 30-min transcription never crashes; job resumes or completes.
- Android: processing survives screen-off for 60 min on a test device with notification visible.
- No Metal GPU usage while backgrounded (verified in Instruments).
