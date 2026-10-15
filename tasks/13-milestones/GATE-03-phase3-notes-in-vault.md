# GATE-03 — Phase 3 Gate: Full Pipeline to the Vault

**Workstream:** Milestones | **Phase:** 3 | **Size:** M | **Depends on:** GATE-02, PRF-03, PRF-04, PRF-05, PRF-06, EXP-01, EXP-02, EXP-05, EXP-06, APP-02, APP-04, APP-05, SEC-01, SEC-04, SEC-07, STT-05, STT-06 | **Source:** §5 Phase 3 + verification strategy
**Status:** review
**Skills:** vv-task-workflow, vv-task-verify, vv-testing, vv-benchmark-eval, vv-markdown-vault-export

## Goal
Every built-in profile turns a real recording into a correct Markdown note in the user's Obsidian vault on both platforms.

## Scope
- [x] Scenario script `docs/test-plans/gates/GATE-03.md` covering Meeting, Warranty, Engineering and Auto profiles.
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-03.md): Run on one iOS and one Android device with Obsidian installed (local + iCloud vault on iOS).
- [~] deferred → device/human run (rows ⏳ in docs/test-plans/device/GATE-03.md): Attach the PRF-09 eval report for the release candidate models/prompts.

## Acceptance Criteria
- For each built-in profile and Auto: record → note appears in the chosen Obsidian vault folder on iOS (local and iCloud vault) and Android, front-matter parses and tasks render in Obsidian.
- PRF-09 eval targets met for every built-in profile (meeting action-item recall/precision ≥ 80%, warranty field accuracy ≥ 90%, engineering TODO recall ≥ 80%, schema-valid ≥ 99%).
- Revoke the vault permission → record → re-grant → exactly one note is written (outbox).
- Consent confirmation is required before a Meeting recording starts; consent appears in the note.
- `tasks.py verify --all-done --run` green on `main`; all dependencies `done`.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** fix/gates · **Date:** 2026-10-15
- **Summary:** Scenario script `docs/test-plans/gates/GATE-03.md`, automatable `app/integration_test/gate_03_vault_test.dart` (fakes for hardware; compiles under analyze, logic also run on the host), and device rows in `docs/test-plans/device/GATE-03.md` (all ⏳). Enterprise/MDM (LIC-04) is out of scope and dropped from this gate. Dependencies are still in `review`, so the gate cannot become `done` yet.
- **Acceptance evidence:**
  - AC1: ⏳ test: [GATE-03/AC1]; device: docs/test-plans/device/GATE-03.md
  - AC2: ⏳ test: [GATE-03/AC2]; device: docs/test-plans/device/GATE-03.md
  - AC3: ⏳ test: [GATE-03/AC3]; device: docs/test-plans/device/GATE-03.md
  - AC4: ⏳ test: [GATE-03/AC4]; device: docs/test-plans/device/GATE-03.md
  - AC5: ⏳ ci: tasks.py verify --all-done --run on main (human)
- **Decisions:** none.
- **Follow-ups:**
  - Human: run the device rows on the QA-05 matrix; a different tool or a human verifies after all dependencies are `done`.
