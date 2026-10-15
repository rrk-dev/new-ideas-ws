# AUD-07 — In-Progress Recording Crash Recovery

**Workstream:** Audio | **Phase:** 1 | **Size:** S | **Depends on:** AUD-01, FND-04 | **Source:** Gap
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-local-database, vv-testing

## Goal
A crash, OS kill or battery death during recording never loses the captured audio.

## Scope
- [x] Mark recording as `in_progress` in DB at start; flush audio buffers frequently (≤ 1 s). — AUD-01 `RecordCaptureBackend`: row `recording` (mic open) / `inProgress` (paused) until stop; every ≤ 1 s flush patches the WAV sizes + syncs and updates `audio_chunks`/`duration_ms`.
- [x] On launch, detect orphaned `in_progress` recordings and repair WAV headers (RIFF/data sizes) from file length. — `RecordingRecovery` (via `AudioChunkCodec.recover`, so a SEC-01 `vvenc` codec truncates to the last frame instead) rebuilds chunk rows from disk; runs once per process in `recoveredRecordingsProvider`, skipping the recording open in this process.
- [x] Prompt user: "Recovered recording from <time> — process now?" — `RecoveredRecordingsPrompt` on the launch (Record) screen; Process now → `PipelineClient.enqueue(userInitiated: true)`.

## Acceptance Criteria
- Force-killing the app at random points during 10 test recordings yields 10 recoverable, playable files losing ≤ 1 s of audio.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/AUD-07-recording-crash-recovery · **Date:** 2026-10-13
- **Summary:** `RecordingRecovery` (`app/lib/features/recording/data/recording_recovery.dart`)
  repairs recordings left `recording`/`inProgress`: each `audio/<id>/chunk_NNNN.wav` is fixed by
  `AudioChunkCodec.recover` (`WavChunkCodec`: header rewritten from the file length, torn trailing
  half-sample dropped, torn header rebuilt), `audio_chunks` rows rebuilt from disk (contiguous ms
  from sample counts; files without rows added, rows without files/empty chunks dropped), row set
  `recorded` + `recovered = true` + `duration_ms`. Empty orphans are deleted. Launch prompt
  `RecoveredRecordingsPrompt` (Process now / Later) mounted on the Record screen (the initial route).
- **Acceptance evidence:**
  - AC1: ⏳ test: [AUD-07/AC1]; device: docs/test-plans/device/AUD-07.md
- **Decisions:** no ADR (follows `vv-audio-capture` → Crash recovery and ADR-AUD-01). PRODUCT-
  DECISIONs: a recording killed before any audio is removed silently; the prompt is asked once per
  process (Later = it stays in the Library as `recovered`); stop reason left empty for recovered
  recordings.
- **Stacking:** branched from task/AUD-01-recording-service (AUD-01 in `review`), which is based on
  origin/main. AUD-05 and AUD-04 are stacked on this branch.
- **Follow-ups:** none.

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (0 changed) · analyze ✅ (no issues) · tests ✅ (785 passed, 24 skipped, coverage 93.2% of 4708 gated lines, min 80%) · native smoke ✅ (host ctest 9 passed / 14 skipped / 0 failed, includes `vv_crash`) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51, success, `67b6fcf`) and https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574 (run 50, success)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[AUD-07/AC1]`. Ten seeded runs kill the backend without finalizing, append a torn trailing byte, then `recoverOrphans` repairs headers, rebuilds chunk rows, sets `recovered`, and loses ≤ 1 s (and never negative). Checked it fails when the recovered flag is written `false`. Device rows (10 force-kills plus battery death, Pixel/Samsung/iPhone) are blank.
- **Adversarial checks:** Empty orphan (torn header, no PCM) is deleted. Finished recordings and the open recording (`skip`) are left alone. Odd cut lengths round down to a whole sample and the header is rewritten to the contract format. No content logged. `tasks.py verify AUD-07 --run` short-circuits on pending evidence; the tagged test passed in the full suite.
- **Skill/rule compliance:** Recovery uses `AudioChunkCodec.recover` (WAV header from file length). Prompt is `RecoveredRecordingsPrompt` on the Record screen; Process now enqueues with `userInitiated: true`. Matches the crash-recovery section of `vv-audio-capture`.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/AUD-07.md has no PASS result with a date; dependency AUD-01 is not done; dependency FND-04 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
- Codex review 2026-10-15 (open): tagged crash test drains all queued writes before the simulated kill (recording_recovery_test.dart): simulate abrupt loss of pending writes, reopen persisted state, and verify disabling periodic flushes fails
