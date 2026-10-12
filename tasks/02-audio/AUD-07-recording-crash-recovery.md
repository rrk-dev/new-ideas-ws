# AUD-07 — In-Progress Recording Crash Recovery

**Workstream:** Audio | **Phase:** 1 | **Size:** S | **Depends on:** AUD-01, FND-04 | **Source:** Gap
**Status:** todo
**Skills:** vv-task-workflow, vv-audio-capture, vv-local-database, vv-testing

## Goal
A crash, OS kill or battery death during recording never loses the captured audio.

## Scope
- [ ] Mark recording as `in_progress` in DB at start; flush audio buffers frequently (≤ 1 s).
- [ ] On launch, detect orphaned `in_progress` recordings and repair WAV headers (RIFF/data sizes) from file length.
- [ ] Prompt user: "Recovered recording from <time> — process now?"

## Acceptance Criteria
- Force-killing the app at random points during 10 test recordings yields 10 recoverable, playable files losing ≤ 1 s of audio.
