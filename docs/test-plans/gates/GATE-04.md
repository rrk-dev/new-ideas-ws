# GATE-04 — Phase 4 scenario: release candidate

Task: [GATE-04](../../../tasks/13-milestones/GATE-04-release-candidate.md).
Automated half: `app/integration_test/gate_04_release_test.dart` (the release bar is
encoded: stress-plan coverage, budgets, egress allowlist, beta exit). Device and human
rows: [../device/GATE-04.md](../device/GATE-04.md), all ⏳.

Enterprise/MDM (LIC-04) is out of scope for the gates and is not checked here.

## Build under test

The signed release build from REL-01 (`fastlane` release lane; see
[release-checklist.md](../../release-checklist.md)), installed on the matrix devices in
[device-matrix.md](../../device-matrix.md). Not a debug or dev build.

## Steps and expected results

### S1 — Stress plan (AC1)

1. Run every case in [stress.md](../stress.md) on the release build across the matrix.
2. Fill the rows of [../device/QA-04.md](../device/QA-04.md) and file `data-loss` issues.

Expected: all cases pass; zero data-loss failures; zero call-capture failures (D-13 to
D-17 never capture call audio and never auto-resume).

Automated: `[GATE-04/AC1]` (every D-01 to D-25 case is in the plan and has a device row).

### S2 — Performance protocol (AC2)

1. Follow [perf.md](../../perf.md) on one Low and one High tier device, release build.
2. Run `python3 tools/bench/perf/perf_report.py check runs/*.json`.

Expected: exit 0 (budgets in `tools/bench/perf/budgets.json` met), or an ADR-approved
revision is linked.

Automated: `[GATE-04/AC2]` (Low and High budgets exist; critical thermal states forbidden).

### S3 — Egress on the release build (AC3)

1. Follow [../device/SEC-02.md](../device/SEC-02.md): route the device through a capture
   proxy, then run a full session (catalog refresh, model download, one recording).
2. Attach the host list to the task.

Expected: only hosts in `app/lib/core/network/model_hosts.dart` (plus the documented
redirect target) appear. Also run `tools/ci/check_egress.sh` on the release commit.

Automated: `[GATE-04/AC3]` (gateway authorizes only the allowlist).

### S4 — Beta exit (AC4)

1. Collect the beta numbers per [beta.md](../../beta.md).
2. Evaluate them against `tools/release/beta_thresholds.json`.

Expected: crash-free sessions ≥ 99.5 %, no open S1 issues, zero data-loss reports.

Automated: `[GATE-04/AC4]` (the exit rule rejects 99.4 % and any open S1).

### S5 — Repository check by a human (AC5)

1. On the release commit run
   `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify --all-done --run`.
2. Confirm every GATE-04 dependency is `done`.
3. A human, not an agent, writes the Verification Report.

Expected: exit 0; verifier is a human.

## Pass rule

GATE-04 passes when S1 to S5 pass on the signed release build.
