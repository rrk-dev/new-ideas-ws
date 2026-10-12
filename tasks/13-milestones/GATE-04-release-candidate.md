# GATE-04 — Phase 4 Gate: Release Candidate

**Workstream:** Milestones | **Phase:** 4 | **Size:** M | **Depends on:** GATE-03, FND-07, FND-08, APP-01, APP-03, APP-06, SEC-02, SEC-03, SEC-06, SEC-08, QA-03, QA-04, REL-01, REL-02, REL-03, REL-04 | **Source:** §5 Phase 4 + verification strategy
**Status:** todo
**Skills:** vv-task-workflow, vv-task-verify, vv-testing, vv-ci-release, vv-privacy-security

## Goal
The signed release build is shown — on devices, not just in CI — to be stable, private and within performance budgets.

## Scope
- [ ] Run the full stress plan (QA-04) and performance protocol (QA-03) on the **signed release build** from REL-01.
- [ ] Run the egress test (SEC-02) on the release build and attach the report.
- [ ] Beta exit criteria (REL-04) reviewed.

## Acceptance Criteria
- Stress plan `docs/test-plans/stress.md` fully executed on the release build across the device matrix with zero data-loss and zero call-capture failures.
- Performance budgets from QA-03 met (or ADR-approved revisions) on Low and High tier devices.
- Egress report on the release build shows only allowlisted hosts.
- Beta crash-free sessions ≥ 99.5% and no open S1 issues.
- `tasks.py verify --all-done --run` green on the release commit; all dependencies `done`; verified by a human (not an agent).
