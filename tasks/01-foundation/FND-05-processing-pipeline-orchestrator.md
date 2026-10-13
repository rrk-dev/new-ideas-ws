# FND-05 — Processing Pipeline Orchestrator (Job Queue / State Machine)

**Workstream:** Foundation | **Phase:** 1–2 | **Size:** L | **Depends on:** FND-04 | **Source:** Gap (§4.2 diagram implies a pipeline but none is specified)
**Status:** review
**Skills:** vv-task-workflow, vv-pipeline-orchestrator, vv-local-database, vv-testing

## Goal
A persistent, resumable pipeline that moves each recording through the canonical states defined in the `vv-pipeline-orchestrator` skill: `queued → transcribing → transcribed → diarizing? → classifying? → extracting → extracted → rendering → rendered → writing → done` (plus `failed`, `cancelled`, `paused`).

## Scope
- [x] Job model persisted in DB with step, progress, attempt count, error, timestamps.
- [x] Single-worker queue (only one heavy model in memory at a time — see LLM-07); priority for user-initiated jobs.
- [x] Resume after app kill / OS termination from last completed step (idempotent steps, intermediate artifacts on disk).
- [x] Cancellation and retry (manual + automatic with backoff for transient failures).
- [x] Run heavy work off the UI isolate (long-lived background isolate or native threads).
- [x] Events stream for UI progress (APP-04) and notifications.
- [x] Re-run individual steps (e.g., re-extract with a different profile without re-transcribing).

## Acceptance Criteria
- Killing the app mid-transcription and relaunching resumes the job without data loss.
- Re-running extraction on an existing transcript does not re-run STT.
- Unit tests cover all state transitions including failure/retry/cancel.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-05-pipeline-orchestrator (stacked on task/FND-04-local-database) · **Date:** 2026-10-13
- **Summary:**
  - Domain (`app/lib/features/pipeline/domain/`): `JobState`/`PipelineStepId`/`WaitingReason` vocabulary
    (`job_state.dart`); pure `JobStateMachine` + `RetryPolicy` (30 s → 2 min → 10 min, then `failed(retryable)`);
    `PipelineStep`/`StepContext`/`StepResult` contract and `classifyFailure` (OOM/IO/network retryable, model
    missing → `waiting(modelMissing)`, permission → `waiting(destination)`, rest permanent); `PipelineClient` +
    content-free `JobEvent`; `HeavyModelGate` (STT and LLM never loaded together; release hook for LLM-07).
  - Data (`app/lib/features/pipeline/data/`): `PipelineOrchestrator` — single worker loop over `jobs`
    (priority, then age; honours `notBefore`), persist-before-act, compare-and-set writes on `jobs.status` so a
    concurrent cancel/pause always wins and late step outputs are discarded, step commit + next step in one
    transaction, startup recovery of active jobs from their checkpoint. Steps: `TranscribeStep` (per-chunk
    checkpoint `{nextChunk, modelId, paramsHash}`, segments + checkpoint in one transaction, restart if params
    changed), `ExtractStep`, `RenderStep` (atomic `rendered/<id>.md`, action items), `WriteStep` (first vault
    target, export row per recording × target, skips unchanged content; no target → `waiting(destination)`).
    Output ids are job-keyed so re-runs overwrite. `PipelineIsolateClient` runs orchestrator + engines on a
    long-lived `vv-pipeline` isolate over the shared drift connection (`serializableConnection()`); engines are
    built inside the worker via a sendable `PipelineEnginesFactory`. Riverpod: `pipelineClientProvider`,
    `pipelineJobsProvider`, `recordingJobsProvider(id)`, `pipelineEnginesFactoryProvider` (no default).
  - `app/lib/core/utils/ids.dart` (UUID v4, FNV-1a params hash).
- **Acceptance evidence:**
  - AC1: ✅ test: [FND-05/AC1]
    - kill mid-transcription resumes without data loss (`app/test/unit/pipeline/pipeline_orchestrator_test.dart` — file DB, worker stopped while chunk 1 runs, DB
    reopened, new orchestrator resumes at chunk 1; STT called only for chunks 1–2, 3 segments, 1 export, no dupes;
    plus restart-on-changed-params case). Host test with fakes; on-device kill (OS termination) not yet run.
  - AC2: ✅ test: [FND-05/AC2]
    - re-extract does not re-run STT (rerun from extract with another profile: STT
    call count unchanged, transcript kept, extraction/profile replaced; rerun guards).
  - AC3: ✅ test: [FND-05/AC3]
    - all transitions incl. failure/retry/cancel (`job_state_machine_test.dart`, orchestrator and `pipeline_isolate_test.dart`).
- **Decisions:** worker = long-lived Dart isolate (skill invariant 5 option 1); no ADR (no library choice).
  PRODUCT-DECISION in `pipeline_engines.dart`: recordings without a profile are extracted with the built-in
  Meeting profile until PRF-06. Placeholder prompt (PRF-02) and renderer (EXP-01/02) are clearly marked seams.
- **Gates (host, macOS):** build_runner clean · `dart format --set-exit-if-changed` clean · `flutter analyze` and
  `dart analyze --fatal-infos` 0 issues · `flutter test --coverage` all passed · coverage 98.1 % of gated lines ·
  `check_egress.sh` OK · `tasks.py validate` OK.
- **Follow-ups:** LLM-07 (real model unload via `HeavyModelGate.release`; OOM → retry once with smaller context);
  STT-05 / PRF-06 (diarize/classify steps — vocabulary and skip logic already in place); APP-04 (ETA from rolling
  RTF / tok/s in `settings`, notifications — consume `JobEvent`s / `pipelineJobsProvider`); AUD-07 (recover
  `in_progress` recordings before job recovery); EXP-05/06 (routing rules, outbox); BG tasks (auto-process,
  charge-only, OS background scheduling); on-device kill/resume run on the device matrix (QA-05).
