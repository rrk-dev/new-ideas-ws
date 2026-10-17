# GATE-05 — Product Phase 2 gate: quick capture, templates, ask, mind maps, task export

**Workstream:** Milestones | **Phase:** 5 | **Size:** M | **Depends on:** GATE-04, QCP-02, QCP-03, TPL-04, ASK-04, MAP-02, TSK-02, LIC-05, SEC-11, UIX-01 | **Source:** Verification
**Status:** todo
**Skills:** vv-task-workflow, vv-task-verify, vv-testing, vv-ci-release, vv-privacy-security, vv-benchmark-eval

## Goal
The Phase 2 features are shown, on real devices and the release build, to work together without breaking privacy, recording safety or performance.

## Scope
- [ ] Write `docs/test-plans/gates/GATE-05.md`: one end-to-end script per area (start recording from each quick-capture entry point; each new profile through to a vault note; ask a cited question across a seeded library; open and export a mind map; push action items to Reminders).
- [ ] Automatable parts in `app/integration_test/gate_05_test.dart` with fakes for hardware, following GATE-04.
- [ ] Rerun the stress plan items touched by Phase 2 (QA-04): recording interruption by a call from each entry point, low memory while asking, app kill during mind-map generation, revoked Reminders permission.
- [ ] Rerun the performance protocol (QA-03) with the 3B model on Mid and High tier devices: memory, thermal, battery for an ask session and for automatic mind-map generation.
- [ ] Rerun the egress test on the release build.

## Acceptance Criteria
- Every scenario in `docs/test-plans/gates/GATE-05.md` passes on the device matrix rows marked required, with zero call-capture failures and zero data loss.
- Quick capture never starts a recording from an app launch, expired token or automation (device rows).
- Ask and mind-map budgets (time, RAM, thermal) written into ASK-03 and MAP-01 are met on Mid and High tier devices or an ADR-approved revision exists.
- Egress report on the release build lists only the existing allowlisted model hosts (no integration hosts).
- `tasks.py verify --all-done --run` is green on the release commit and a human (not an agent) signs the gate.
