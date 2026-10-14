# EXP-06 — Write Failure Handling & Export Outbox

**Workstream:** Export | **Phase:** 3 | **Size:** S | **Depends on:** EXP-05, FND-05 | **Source:** Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-pipeline-orchestrator, vv-local-database, vv-flutter-architecture, vv-testing

## Goal
No generated note is ever lost because a destination was temporarily unavailable.

## Scope
- [ ] Always save rendered Markdown in app-private storage first; destination write is a separate retryable step.
- [ ] Outbox with retry on: permission revoked, iCloud unavailable, SD card removed, disk full.
- [ ] User-visible "pending exports" list with re-grant / change destination actions.
- [ ] Idempotent: retries never create duplicates (EXP-02 stable identity).

## Acceptance Criteria
- Revoking folder permission, then re-granting, results in exactly one note per recording.
