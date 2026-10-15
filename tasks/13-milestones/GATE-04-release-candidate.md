# GATE-04 — Phase 4 Gate: Release Candidate

**Workstream:** Milestones | **Phase:** 4 | **Size:** M | **Depends on:** GATE-03, FND-07, FND-08, APP-01, APP-03, APP-06, SEC-02, SEC-03, SEC-06, SEC-08, QA-03, QA-04, REL-01, REL-02, REL-03, REL-04 | **Source:** §5 Phase 4 + verification strategy
**Status:** review
**Skills:** vv-task-workflow, vv-task-verify, vv-testing, vv-ci-release, vv-privacy-security

## Goal
The signed release build is shown — on devices, not just in CI — to be stable, private and within performance budgets.

## Scope
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-04.md): Run the full stress plan (QA-04) and performance protocol (QA-03) on the **signed release build** from REL-01.
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-04.md): Run the egress test (SEC-02) on the release build and attach the report.
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-04.md): Beta exit criteria (REL-04) reviewed.

## Acceptance Criteria
- Stress plan `docs/test-plans/stress.md` fully executed on the release build across the device matrix with zero data-loss and zero call-capture failures.
- Performance budgets from QA-03 met (or ADR-approved revisions) on Low and High tier devices.
- Egress report on the release build shows only allowlisted hosts.
- Beta crash-free sessions ≥ 99.5% and no open S1 issues.
- `tasks.py verify --all-done --run` green on the release commit; all dependencies `done`; verified by a human (not an agent).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/gates · **Date:** 2026-10-15
- **Summary:** Scenario script `docs/test-plans/gates/GATE-04.md`, automatable `app/integration_test/gate_04_release_test.dart` (fakes for hardware; compiles under analyze, logic also run on the host), and device rows in `docs/test-plans/device/GATE-04.md` (all ⏳). Enterprise/MDM (LIC-04) is out of scope and dropped from this gate. Dependencies are still in `review`, so the gate cannot become `done` yet.
- **Acceptance evidence:**
  - AC1: ⏳ test: [GATE-04/AC1]; device: docs/test-plans/device/GATE-04.md
  - AC2: ⏳ test: [GATE-04/AC2]; device: docs/test-plans/device/GATE-04.md
  - AC3: ⏳ test: [GATE-04/AC3]; device: docs/test-plans/device/GATE-04.md
  - AC4: ⏳ test: [GATE-04/AC4]; device: docs/test-plans/device/GATE-04.md
  - AC5: ⏳ ci: tasks.py verify --all-done --run on main (human)
- **Decisions:** none.
- **Follow-ups:**
  - Human: run the device rows on the QA-05 matrix; a different tool or a human verifies after all dependencies are `done`.
