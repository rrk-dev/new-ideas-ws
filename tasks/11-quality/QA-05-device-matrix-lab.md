# QA-05 — Device Test Matrix & Lab

**Workstream:** Quality | **Phase:** 1 (procure) – 4 | **Size:** S | **Depends on:** — | **Source:** §2.1, §5 Phase 4
**Status:** review
**Skills:** vv-task-workflow, vv-testing, vv-benchmark-eval

## Goal
Test on the hardware the plan targets, from budget to flagship.

## Scope
- [x] iOS: iPhone 11 (A13, 4 GB), iPhone 13/14 (6 GB), iPhone 15 Pro / 16 (8 GB, A17 Pro/A18); one iPad.
- [x] Android: Snapdragon 8 Gen 3/4 flagship, Snapdragon 7-series mid-range, one MediaTek/Mali device, one 4 GB RAM device, one Samsung (OEM battery management), Pixel (reference).
- [x] Decide cloud device farm (Firebase Test Lab / BrowserStack) usage for non-content smoke tests only — no real user audio uploaded.
- [x] Track device inventory and OS versions.

## Acceptance Criteria
- iOS/Android parity checklist (`docs/parity.md`: every feature × platform, known differences such as iOS Ogg/Opus import) reviewed before beta.
- Matrix documented; devices available to the team by end of Phase 1.

## Completion Notes
- **Agent:** Cursor · **Branch:** task/QA-05-device-matrix-lab · **Date:** 2026-10-12
- **Summary:** Device matrix, lab rules, and inventory table in `docs/device-matrix.md` (eight roles, all `To procure`). Parity checklist in `docs/parity.md`, including iOS rejecting Ogg/Opus. Cloud farms rejected in favor of the physical lab; ADR is Proposed until a person accepts the spend. No unit has been measured.
- **Acceptance evidence:**
  - AC1: ✅ artifact: docs/parity.md
  - AC2: ⏳ device: docs/test-plans/device/QA-05.md
- **Decisions:** ADR-QA-05-device-lab (Proposed — physical lab only)
- **Follow-ups:** QA-06 proposed below; notes on FND-03, FND-06, REL-04, GATE-01

## Follow-ups
- QA-06 (proposed, not filed): a physical Android 8.0 (API 26) arm64 phone if a bug is specific to the OS floor. The required matrix has no API 26 unit, and emulators are not valid for ggml.
