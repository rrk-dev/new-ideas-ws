# Device verification — GATE-03 Phase 3 gate

Full scenario: [../gates/GATE-03.md](../gates/GATE-03.md). One iOS and one Android device with Obsidian.

Enterprise/MDM (LIC-04) is out of scope and not checked. Every row is ⏳ until a person runs it.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [GATE-03/AC1] | Scenario S1 for Meeting, Warranty, Engineering and Auto; iOS local vault | Note in folder; front-matter parses in Obsidian; tasks render | iPhone (VV-IOS-16) | current | ⏳ | | |
| [GATE-03/AC1] | Scenario S1 for all four profiles; iOS iCloud vault | Same | iPhone (VV-IOS-16) | current | ⏳ | | |
| [GATE-03/AC1] | Scenario S1 for all four profiles; Android vault | Same | Android (VV-AND-FLG) | current | ⏳ | | |
| [GATE-03/AC2] | Scenario S2: `tools/ci/eval.sh --force` with release-candidate models | Targets met: meeting ≥ 80 %, warranty ≥ 90 %, engineering ≥ 80 %, schema-valid ≥ 99 % | Mac host + bridge | current | ⏳ | | |
| [GATE-03/AC3] | Scenario S3: revoke vault permission, record, re-grant | Exactly one note after re-grant | iPhone (VV-IOS-16) | current | ⏳ | | |
| [GATE-03/AC3] | Scenario S3 | Same | Android (VV-AND-FLG) | current | ⏳ | | |
| [GATE-03/AC4] | Scenario S4: Meeting consent dialog, confirm, open note | No recording without confirmation; `consent_at` in the note | iPhone (VV-IOS-16) | current | ⏳ | | |
| [GATE-03/AC4] | Scenario S4 | Same | Android (VV-AND-FLG) | current | ⏳ | | |

## Notes / evidence

AC5 is a CI and repository check (scenario S5). Attach the PRF-09 report from `build/eval` under `docs/test-plans/device/evidence/GATE-03/`.
