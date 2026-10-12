---
name: vv-pipeline-orchestrator
description: "Persistent job state machine for recordings (transcribe, diarize, extract, render, write): single worker queue, checkpoints, resume after app kill, retry/cancel, re-run a step, progress/ETA, notifications. Use when adding or changing a processing step."
---

# Processing Pipeline Orchestrator

## States
```
queued → transcribing → transcribed → diarizing? → classifying? → extracting → extracted
       → rendering → rendered → writing → done
(`?` = only when enabled: diarization per profile, classification when profile = Auto)
any → failed(retryable | permanent) · any → cancelled · any active → paused (background/thermal)
any → waiting(reason) — reason ∈ model_missing | profile_choice | review | destination
```
`waiting` is not a failure: the job resumes automatically when the reason clears (model
installed — APP-01/MDL-02; user picked a profile — PRF-06 low confidence; user approved the
result — APP-05 review-before-export; vault access re-granted — EXP-06).
Each step is a `PipelineStep` with: `id`, `canRun(job)`, `run(job, ctx) → Stream<Progress>` ending
in `StepResult`, `isIdempotent = true` (required), `checkpoint(job)`. Steps:
`TranscribeStep` (STT-03/04), `DiarizeStep` (STT-05, optional), `ClassifyStep` (PRF-06, when
profile = auto), `ExtractStep` (LLM-05/06), `RenderStep` (EXP-01/02), `WriteStep` (EXP-05/06).

## Invariants
1. **Persist before act**: write the new step/status to `jobs` before starting work; write
   results + next step in one transaction after.
2. **Idempotent steps**: outputs written to `work/<job_id>/` or DB keyed by (job, step, chunk);
   re-running overwrites, never appends duplicates.
3. **Chunk checkpoints**: long steps (STT chunks, map-reduce chunks) persist each finished chunk;
   `checkpoint` JSON stores `{nextChunk, modelId, paramsHash}`. Resume skips finished chunks only
   if `paramsHash` matches.
4. **One heavy worker**: a single queue worker; STT and LLM never loaded together
   (unload STT before Extract — `vv-llm-inference` memory rules).
5. **UI isolate never blocks**: worker runs in a long-lived background isolate or native threads;
   UI subscribes to a `Stream<JobEvent>` (drift stream on `jobs` is fine).
6. **Startup recovery**: on launch, jobs in active states → `queued` with same checkpoint;
   recordings `in_progress` → AUD-07 recovery first.

## Retry policy
- Retryable failures (OOM after unload, transient IO, destination unavailable): exponential
  backoff 30 s → 2 m → 10 m, max 3 automatic attempts, then `failed(retryable)` with a user action.
- Model missing ⇒ `waiting(model_missing)` (not failed). Permanent (model corrupt, invalid
  audio): no auto-retry; show actionable error.
- `OutOfMemoryFailure` on LLM ⇒ retry once with smaller context / map-reduce forced, then
  suggest smaller model.

## Isolates & native callbacks
The worker isolate owns the engines (`SttEngine`/`LlmEngine`) and their `NativeCallable`s —
create and close callables in the isolate that registered them. DB access from the worker uses
the shared drift connection (`vv-local-database` → Isolates). The UI isolate only sends commands
(start/cancel/rerun) via a `SendPort` and observes `jobs` through drift streams.

## Re-run a step
`rerun(jobId, fromStep)` clears downstream outputs and requeues from that step
(e.g. edit transcript → re-extract; change profile → re-extract; change template → re-render).
Transcripts are never discarded by a re-run of later steps.

## Priority & scheduling
User-initiated "Process now" jumps queue. Respect settings: auto-process after recording,
charge-only, Wi-Fi independent (all local). Background constraints: `vv-background-execution`.

## Progress & ETA (APP-04)
Progress = (finished chunks / total). ETA from measured throughput of this device (store rolling
average of STT real-time factor and LLM tokens/s in `settings`). Show step name + % + ETA.
Local notifications on done/failure; lock-screen text generic by default ("Your note is ready").

## Tests (must exist)
- Every transition incl. failure/retry/cancel/pause.
- Kill/resume: run job with fakes, dispose container mid-chunk, recreate on same DB → finishes,
  no duplicate segments/exports.
- Re-run from Extract does not invoke `SttEngine`.
