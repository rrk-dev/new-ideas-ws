# Device verification — GATE-01 Phase 1 gate

Full scenario: [../gates/GATE-01.md](../gates/GATE-01.md). Oldest and newest device per platform.

Enterprise/MDM (LIC-04) is out of scope and not checked. Every row is ⏳ until a person runs it.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [GATE-01/AC2] | Scenario S2: Record, lock 10 min, unlock, Stop; inspect chunks | Valid 16 kHz mono WAV chunks; duration equals timer ± 0.5 s | VV-IOS-11 | current | ⏳ | | |
| [GATE-01/AC2] | Scenario S2 | Same | VV-IOS-16 | current | ⏳ | | |
| [GATE-01/AC2] | Scenario S2 | Same | VV-AND-4G | current | ⏳ | | |
| [GATE-01/AC2] | Scenario S2 | Same | VV-AND-FLG | current | ⏳ | | |
| [GATE-01/AC3] | Scenario S3: ring, answer and hang up during recording; then Record during a call | Capture stops, no call audio, stays paused until Resume tap; Record refused in a call | VV-IOS-11 | current | ⏳ | | |
| [GATE-01/AC3] | Scenario S3 | Same | VV-IOS-16 | current | ⏳ | | |
| [GATE-01/AC3] | Scenario S3 | Same | VV-AND-4G | current | ⏳ | | |
| [GATE-01/AC3] | Scenario S3 | Same | VV-AND-FLG | current | ⏳ | | |
| [GATE-01/AC4] | Scenario S4: force-kill while recording, relaunch | Recording recovered and playable; loss ≤ 1 s | VV-IOS-11 | current | ⏳ | | |
| [GATE-01/AC4] | Scenario S4 | Same | VV-IOS-16 | current | ⏳ | | |
| [GATE-01/AC4] | Scenario S4 | Same | VV-AND-4G | current | ⏳ | | |
| [GATE-01/AC4] | Scenario S4 | Same | VV-AND-FLG | current | ⏳ | | |
| [GATE-01/AC5] | Scenario S5: pick vault folder, reboot, write a note | Folder still writable, no re-pick | VV-IOS-11 (or VV-IOS-16) | current | ⏳ | | |
| [GATE-01/AC5] | Scenario S5 | Folder still writable, no re-pick | VV-AND-4G (or VV-AND-FLG) | current | ⏳ | | |

## Notes / evidence

AC1 is a CI and repository check (scenario S1), not a device row. Evidence goes under `docs/test-plans/device/evidence/GATE-01/`.
