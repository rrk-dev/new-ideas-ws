# APP-05 — Extraction Result Review & Edit Before Export

**Workstream:** App UX | **Phase:** 3 | **Size:** M | **Depends on:** LLM-05, EXP-01 | **Source:** Gap (small local models make mistakes; users need a check step)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-extraction-profiles, vv-markdown-vault-export, vv-pipeline-orchestrator, vv-whisper-stt, vv-testing

## Goal
Optionally review and correct extracted fields before the note is written to the vault.

## Scope
- [ ] Setting: auto-export vs review-first (per profile).
- [ ] Form view generated from profile schema (edit attendees, tasks, owners, dates).
- [ ] Each item links to its source timestamp in the transcript (from LLM-05 evidence fields).
- [ ] Rendered Markdown preview; "Export" commits.

## Acceptance Criteria
- Edits are reflected in exported Markdown; source-link jumps to correct audio position.
