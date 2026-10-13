# GATE-01 — Phase 1 Gate: Foundation, CI & Safe Recording

**Workstream:** Milestones | **Phase:** 1 | **Size:** M | **Depends on:** FND-01, FND-02, FND-03, FND-04, FND-06, QA-01, QA-05, SEC-09, AUD-01, AUD-04, AUD-05, AUD-07, AUD-08, EXP-03, EXP-04 | **Source:** §5 Phase 1 + verification strategy
**Status:** todo
**Skills:** vv-task-workflow, vv-task-verify, vv-testing, vv-audio-capture, vv-ci-release

## Goal
Prove, end to end on real devices, that the Phase 1 foundation works together — not just task by task.

## Scope
- [ ] Write the end-to-end scenario script `docs/test-plans/gates/GATE-01.md` (steps below) and an `integration_test` covering the automatable parts.
- [ ] Run it on the oldest and newest device per platform from the device matrix (QA-05).
- [ ] Confirm `tasks.py verify --all-done --run` is green on `main` for every Phase 1 task.

## Acceptance Criteria
- CI on `main` is green, including `tasks.py verify --all-done --run`, and every dependency is `done` with a Verification Report.
- On iPhone 11 + newest iPhone and a 4 GB Android + flagship Android: tap Record → lock the phone 10 min → unlock → stop; WAV chunks are valid 16 kHz mono and the duration matches the timer ± 0.5 s.
- On the same devices: an incoming call during recording stops capture with no call audio in the file, and the recording stays paused until Resume is tapped; tapping Record during a call is refused.
- Force-kill during recording → relaunch → the recording is recovered and playable.
- A vault folder picked on each platform is still writable after reboot.

## Follow-ups
- QA-05: oldest and newest devices are the matrix Low and High roles — iPhone 11 and the 8 GB iPhone (iPhone 16, or an 8 GB substitute), plus the 4 GB Android and the Snapdragon flagship. See `docs/device-matrix.md`. Units are not in the lab yet.
