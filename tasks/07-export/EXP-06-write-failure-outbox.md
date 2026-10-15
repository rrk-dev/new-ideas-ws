# EXP-06 — Write Failure Handling & Export Outbox

**Workstream:** Export | **Phase:** 3 | **Size:** S | **Depends on:** EXP-05, FND-05 | **Source:** Gap
**Status:** review
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-pipeline-orchestrator, vv-local-database, vv-flutter-architecture, vv-testing

## Goal
No generated note is ever lost because a destination was temporarily unavailable.

## Scope
- [x] Always save rendered Markdown in app-private storage first; destination write is a separate retryable step.
- [x] Outbox with retry on: permission revoked, iCloud unavailable, SD card removed, disk full.
- [x] User-visible "pending exports" list with re-grant / change destination actions.
- [x] Idempotent: retries never create duplicates (EXP-02 stable identity).

## Acceptance Criteria
- Revoking folder permission, then re-granting, results in exactly one note per recording.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/EXP-06-write-failure-outbox (stacked on
  task/EXP-05-vault-writer-routing — needs its `VaultExporter`) · **Date:** 2026-10-14
- **Summary:** The rendered note is always saved first (`rendered/<id>.md`, RenderStep); the
  vault write is the separate, retryable WriteStep. EXP-05's `VaultExporter` keeps one `exports`
  row per recording × target (`writing` before the write, `written` after, `failed` with the last
  confirmed hash on error) and returns needs-destination (revoked / no folder →
  `waiting(destination)`) or a retryable failure (unavailable / SD removed / disk full →
  orchestrator backoff). New `ExportOutbox` (`export/data/export_outbox.dart`) derives the pending
  list (`buildPendingExports`, pure) from jobs + outbox rows, and offers re-grant (picker
  pre-selects the old folder, handle updated in place), choose another folder (releases the old
  grant), choose a folder / "Save on this device" (app-local target) when none is configured,
  retry (resolve waiting / retry failed / re-run write of a finished job), and `recheck()` of
  reachable folders on app resume (`ProcessingServicesHost`). UI: Settings › Pending exports
  (`/settings/pending-exports`, accessibility row added).
- **Acceptance evidence:**
  - AC1: ⏳ test: [EXP-06/AC1]; device: docs/test-plans/device/EXP-06.md
- **Decisions:** PRODUCT-DECISION: with no vault folder the note waits (pending list offers
  "Choose a folder" / "Save on this device") instead of silently going to the app folder.
- **Follow-ups:** FND-11 wiring (engines `vaultResolver`, Pigeon from the worker isolate).

