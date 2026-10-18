# GATE-05 — Product Phase 2 gate: quick capture, templates, ask, mind maps, task export

**Workstream:** Milestones | **Phase:** 5 | **Size:** M | **Depends on:** GATE-04, QCP-02, QCP-03, TPL-04, ASK-04, MAP-02, TSK-02, LIC-05, SEC-11, UIX-01 | **Source:** Verification
**Status:** review
**Skills:** vv-task-workflow, vv-task-verify, vv-testing, vv-ci-release, vv-privacy-security, vv-benchmark-eval

## Goal
The Phase 2 features are shown, on real devices and the release build, to work together without breaking privacy, recording safety or performance.

## Scope
- [x] Write `docs/test-plans/gates/GATE-05.md`: one end-to-end script per area (start recording from each quick-capture entry point; each new profile through to a vault note; ask a cited question across a seeded library; open and export a mind map; push action items to Reminders).
- [x] Automatable parts in `app/integration_test/gate_05_test.dart` with fakes for hardware, following GATE-04.
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-05.md): rerun the stress plan items touched by Phase 2 (QA-04): recording interruption by a call from each entry point, low memory while asking, app kill during mind-map generation, revoked Reminders permission.
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-05.md): rerun the performance protocol (QA-03) with the 3B model on Mid and High tier devices: memory, thermal, battery for an ask session and for automatic mind-map generation.
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-05.md): rerun the egress test on the release build.

## Acceptance Criteria
- Every scenario in `docs/test-plans/gates/GATE-05.md` passes on the device matrix rows marked required, with zero call-capture failures and zero data loss.
- Quick capture never starts a recording from an app launch, expired token or automation (device rows).
- Ask and mind-map budgets (time, RAM, thermal) written into ASK-03 and MAP-01 are met on Mid and High tier devices or an ADR-approved revision exists.
- Egress report on the release build lists only the existing allowlisted model hosts (no integration hosts).
- `tasks.py verify --all-done --run` is green on the release commit and a human (not an agent) signs the gate.

## Open Decisions
- PRODUCT-DECISION (pending, product owner): ASK-03 and ASK-05 quality gates are unmet; Ask is behind `ask.enabled`, off by default. The gate sign-off must state whether this is accepted for the release.
- PRODUCT-DECISION (human-approved, ADR-ASK-02): Ask is High tier only. The scope text "3B on Mid and High" is superseded; on Mid/Low the Ask check is the "not available" screen. Mind-map budgets on Mid/Low use the extraction model.
- Live Activity (AUD-13) is a separate task and is not covered by this gate.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/GATE-05-product-phase2-gate · **Date:** 2026-10-18
- **Summary:** Scenario script `docs/test-plans/gates/GATE-05.md` (S1 to S9, with the Ask quality and AUD-13 caveats), host-runnable `app/integration_test/gate_05_test.dart` (9 tests pass with `flutter test -d flutter-tester`: every quick-capture entry only navigates and a call stops a recording without auto-resume; expired, replayed and malformed taps are dropped; Ask cited answer, refusal, invented citation and Mid/Low unavailability; mind-map export; Reminders created once and revoked permission; budgets match the task files; the gateway rejects integration hosts), stress cases D-26 to D-32 in `docs/test-plans/stress.md`, Phase 2 workloads in `docs/perf.md` and `tools/bench/perf/budgets.json` (`perf_report.py` does not evaluate them; compare by hand), and device rows in `docs/test-plans/device/GATE-05.md` (all ⏳). No device, release-build or egress-proxy run was performed. Dependencies are still in `review`, so the gate cannot become `done`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [GATE-05/AC1]; device: docs/test-plans/device/GATE-05.md
  - AC2: ⏳ test: [GATE-05/AC2]; device: docs/test-plans/device/GATE-05.md
  - AC3: ⏳ test: [GATE-05/AC3]; device: docs/test-plans/device/GATE-05.md
  - AC4: ⏳ test: [GATE-05/AC4]; device: docs/test-plans/device/GATE-05.md
  - AC5: ⏳ ci: tasks.py verify --all-done --run on main (human)
- **Decisions:** see Open Decisions.
- **Follow-ups:**
  - Human: run the device rows on the QA-05 matrix; a human verifies after all dependencies are `done` and the Ask quality decision is made.
