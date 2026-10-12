# FND-05 — Processing Pipeline Orchestrator (Job Queue / State Machine)

**Workstream:** Foundation | **Phase:** 1–2 | **Size:** L | **Depends on:** FND-04 | **Source:** Gap (§4.2 diagram implies a pipeline but none is specified)
**Status:** todo
**Skills:** vv-task-workflow, vv-pipeline-orchestrator, vv-local-database, vv-testing

## Goal
A persistent, resumable pipeline that moves each recording through the canonical states defined in the `vv-pipeline-orchestrator` skill: `queued → transcribing → transcribed → diarizing? → classifying? → extracting → extracted → rendering → rendered → writing → done` (plus `failed`, `cancelled`, `paused`).

## Scope
- [ ] Job model persisted in DB with step, progress, attempt count, error, timestamps.
- [ ] Single-worker queue (only one heavy model in memory at a time — see LLM-07); priority for user-initiated jobs.
- [ ] Resume after app kill / OS termination from last completed step (idempotent steps, intermediate artifacts on disk).
- [ ] Cancellation and retry (manual + automatic with backoff for transient failures).
- [ ] Run heavy work off the UI isolate (long-lived background isolate or native threads).
- [ ] Events stream for UI progress (APP-04) and notifications.
- [ ] Re-run individual steps (e.g., re-extract with a different profile without re-transcribing).

## Acceptance Criteria
- Killing the app mid-transcription and relaunching resumes the job without data loss.
- Re-running extraction on an existing transcript does not re-run STT.
- Unit tests cover all state transitions including failure/retry/cancel.
