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


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** FAIL
- **Gates:** format ✅ (387 files, 0 changed) · flutter analyze ✅ (0 issues) · flutter test --coverage ✅ (785 passed, 24 skipped on this host; Linux goldens/platform/model-dependent checks are not all executed locally) · coverage check_coverage: 93.2% of 4708 lines in 126 gated files (min 80%) · pytest tools/ci/tests ✅ (66 passed) · native/build.sh host + ctest ✅ (23 registered: 9 executed/pass, 14 explicitly skipped without configured model/backend fixtures) · egress ✅ · recording policy ✅ (source manifests; no local merged Android build) · tasks.py validate ✅ (85 tasks, 0 problems) · CI: [main run 51](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858), same verified SHA, six jobs green; [PR run 50](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574) also green. Shared gates were run once before mutations, as requested; logs under /tmp/vv-verify-a/.
- **Fresh state / review:** Fresh clone of origin/main; local branch `verify/codex-a`. Reviewed task scope, Completion Notes, implementation history/diffs, current source, listed skills and tagged tests. No product/test fixes retained.
- **Acceptance criteria:**
  - AC1: ✅ Host file-DB kill/reopen test asserts persisted chunk-0/checkpoint, resumes chunks 1–2 only and ends with three segments and one export; changed-parameter test restarts all chunks. This is a cooperative worker-dispose simulation, not an actual OS kill/device run.
  - AC2: ✅ Re-extraction with another profile preserves the transcript and STT call count, replaces extraction/profile and keeps one export; invalid/no-transcript reruns fail.
  - AC3: ❌ Tagged state-machine/isolate/orchestrator tests cover normal transitions, failure/backoff, retry/cancel/pause/waiting and late result rollback, but the external model-release-failure probe exposes an unhandled worker failure.
- **Adversarial checks:** Changed the first retry delay from 30 s to 31 s; tagged AC3 transition test failed and passed after git checkout restored job_state_machine.dart. Separately, an unchanged-source probe created a one-chunk job with HeavyModelGate(release: (_) async => throw StateError("release failed")); switching STT→LLM emitted an uncaught StateError and left the job at extracting. Probe is /tmp/vv-verify-a/adversarial_pipeline_test.dart; output in pipeline-adversarial.log. No repository test/source fixes made.
- **Skill/rule compliance:** Persist-before-act, chunk checkpoint transactions, shared DB isolate and late-cancel compare-and-set paths inspected. Model-release failures bypass the specified failure/retry machinery; actual device kill/background scenarios remain unexecuted. AGENTS.md, vv-task-workflow and vv-task-verify followed; no push, PR, GitHub API, tool installation or git-config changes.
- **Issues found:** 
  1. PipelineOrchestrator._process persists the active state, then awaits gate.use(step.model) outside its try/catch. A throwing unload callback terminates _workLoop, strands the active job and prevents later queue work until restart; PipelineIsolateClient drops post-start errors and pending commands can hang. Handle model switching failures through job failure/retry and keep the worker alive; add regression coverage.
- **Acceptance runner:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify FND-05 --run` was invoked; its evidence/dependency checks refused before launching tagged tests. All referenced tagged tests were instead executed in the shared full Dart/pytest suites, then the mutation target was re-run red and green after restoration (QA-05 is artifact-only). Pre-report diagnostic output: `/tmp/vv-verify-a/FND-05-verify.log`.

## Rework
- **Agent:** Claude Code · **Branch:** task/FND-05-rework-1 (from origin/integration/wave-4) · **Date:** 2026-10-14 — answers the Codex FAIL report above (report left unchanged).
- **Issue 1 (model-release exception escapes `_process`, kills the worker, strands the job; isolate drops post-start errors):**
  - Failing tests written first (commit `b5576fb`, red against the unchanged source: the three orchestrator tests
    timed out / saw the job stuck in `extracting` with an uncaught `StateError: release failed`; the isolate tests
    did not compile against the old client), then fixed:
    - `[FND-05/AC3] a failing model release (STT→LLM switch) is retried with backoff; the worker stays alive and runs the next job`
    - `[FND-05/AC3] a release that keeps failing ends in failed(retryable) and the STT model is not considered unloaded`
    - `[FND-05/AC3] a failing release while the queue is idle does not stop the worker`
    - `[FND-05/AC3] an unexpected exception outside a step does not kill the worker loop`
    - `[FND-05/AC3] a command that throws in the worker is answered and the worker keeps serving commands`
    - `[FND-05/AC3] a worker crash after startup fails pending and later commands instead of hanging, and is reported`
    - `[FND-05/AC3] a pending command completes when the worker exits abruptly`
    (`app/test/unit/pipeline/pipeline_orchestrator_test.dart`, `app/test/unit/pipeline/pipeline_isolate_test.dart`).
  - `PipelineOrchestrator._process`: the model switch (`gate.use`) now runs inside its own try/catch after
    persist-before-act; a failure goes through `_onFailure` as `FailureKind.retryable` with the content-free detail
    `ModelSwitchFailure`, so it backs off 30 s → 2 min → 10 min and then `failed(retryable)` like any transient failure.
  - `HeavyModelGate.releaseAll`: if the release throws, the model stays marked loaded and the error is rethrown, so
    the next switch retries the unload and the LLM is never loaded beside a possibly still-resident STT model.
  - `_workLoop`: the idle-queue `releaseAll` is guarded, and every iteration is guarded; an unexpected exception
    parks an active job as `failed(retryable)` (best effort) and pauses 200 ms so a persistent fault cannot spin.
  - `PipelineIsolateClient`: the worker answers every command even when the handler throws (`UnexpectedFailure('command failed')`)
    and keeps its command loop; the client listens to `onError` and `onExit` after startup, completes every pending
    command with `UnexpectedFailure('pipeline worker stopped')`, returns that for later commands, and exposes
    `terminated`; `dispose` no longer waits on a dead worker. `pipelineClientProvider` invalidates itself on
    `terminated`, so a new worker is spawned and startup recovery resumes the interrupted job from its checkpoint.
    Errors stay content-free (not logged).
  - Mutation checks (2026-10-14): the pre-fix source (commit `b5576fb`) fails the three model-release tests
    (`TimeoutException`, uncaught `StateError: release failed`, job left `extracting`); commenting out
    `life.terminate()` in the client's post-start error/exit handler → `a worker crash after startup …` times out
    (`+4 -1`); replacing the work-loop guard with `rethrow` → `an unexpected exception outside a step …` fails
    (`TimeoutException`, `Bad state: canRun bug`). Restored with git checkout → green.
- **Still needed:** unchanged — on-device kill/background runs on the QA-05 matrix.
