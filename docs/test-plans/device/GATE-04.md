# Device verification — GATE-04 Phase 4 gate

Full scenario: [../gates/GATE-04.md](../gates/GATE-04.md). Signed release build from REL-01.

Enterprise/MDM (LIC-04) is out of scope and not checked. Every row is ⏳ until a person runs it.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [GATE-04/AC1] | Scenario S1: run all of docs/test-plans/stress.md on the release build | All cases pass; zero data-loss; zero call-capture failures | all lab devices | current | ⏳ | | |
| [GATE-04/AC2] | Scenario S2: performance protocol, `perf_report.py check` | Budgets met on Low and High tiers (or ADR-approved revision) | VV-IOS-11, VV-AND-4G (Low) | current | ⏳ | | |
| [GATE-04/AC2] | Scenario S2 | Same | VV-IOS-16, VV-AND-FLG (High) | current | ⏳ | | |
| [GATE-04/AC3] | Scenario S3: proxy capture of a full session on the release build | Only allowlisted hosts | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-04/AC4] | Scenario S4: beta numbers vs `tools/release/beta_thresholds.json` | Crash-free ≥ 99.5 %; no open S1 | beta cohort | current | ⏳ | | |

## Notes / evidence

AC5 is a CI and human verification step (scenario S5). Evidence goes under `docs/test-plans/device/evidence/GATE-04/`.
