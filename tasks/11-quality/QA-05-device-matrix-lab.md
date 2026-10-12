# QA-05 — Device Test Matrix & Lab

**Workstream:** Quality | **Phase:** 1 (procure) – 4 | **Size:** S | **Depends on:** — | **Source:** §2.1, §5 Phase 4
**Status:** todo
**Skills:** vv-task-workflow, vv-testing, vv-benchmark-eval

## Goal
Test on the hardware the plan targets, from budget to flagship.

## Scope
- [ ] iOS: iPhone 11 (A13, 4 GB), iPhone 13/14 (6 GB), iPhone 15 Pro / 16 (8 GB, A17 Pro/A18); one iPad.
- [ ] Android: Snapdragon 8 Gen 3/4 flagship, Snapdragon 7-series mid-range, one MediaTek/Mali device, one 4 GB RAM device, one Samsung (OEM battery management), Pixel (reference).
- [ ] Decide cloud device farm (Firebase Test Lab / BrowserStack) usage for non-content smoke tests only — no real user audio uploaded.
- [ ] Track device inventory and OS versions.

## Acceptance Criteria
- iOS/Android parity checklist (`docs/parity.md`: every feature × platform, known differences such as iOS Ogg/Opus import) reviewed before beta.
- Matrix documented; devices available to the team by end of Phase 1.
