# Device verification — GATE-02 Phase 2 gate

Full scenario: [../gates/GATE-02.md](../gates/GATE-02.md). One Low and one High device per platform, tier-default models.

Enterprise/MDM (LIC-04) is out of scope and not checked. Every row is ⏳ until a person runs it.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [GATE-02/AC1] | Scenario S1: fresh install, model download, 30 min recording, transcript and JSON | Progress shown; schema-valid JSON; no OOM kill | VV-IOS-11 | current | ⏳ | | |
| [GATE-02/AC1] | Scenario S1 | Same | VV-IOS-16 | current | ⏳ | | |
| [GATE-02/AC1] | Scenario S1 | Same | VV-AND-4G | current | ⏳ | | |
| [GATE-02/AC1] | Scenario S1 | Same | VV-AND-FLG | current | ⏳ | | |
| [GATE-02/AC2] | Scenario S2: force-kill while Transcribing, then while Extracting | Job resumes and completes; no duplicate segments | VV-IOS-11, VV-AND-4G | current | ⏳ | | |
| [GATE-02/AC2] | Scenario S2 | Same | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-02/AC3] | Scenario S3: airplane mode after model download, full run | Pipeline completes; Network activity shows no requests | VV-IOS-11, VV-AND-4G | current | ⏳ | | |
| [GATE-02/AC3] | Scenario S3 | Same | VV-IOS-16, VV-AND-FLG | current | ⏳ | | |
| [GATE-02/AC4] | Scenario S4: WER/RTF, tokens/s and end-to-end time per device | Report committed with WER per model and time per device | all four devices | current | ⏳ | | |

## Notes / evidence

AC5 is a CI and repository check (scenario S5). Evidence goes under `docs/test-plans/device/evidence/GATE-02/`.
