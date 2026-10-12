# SEC-04 — Data Retention Policies & Secure Deletion

**Workstream:** Security & Privacy | **Phase:** 3 | **Size:** S | **Depends on:** FND-04, SEC-01 | **Source:** Gap
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-local-database, vv-testing

## Goal
Users (and enterprises) control how long raw audio and transcripts are kept.

## Scope
- [ ] Policies: delete audio after successful export / after N days / never; same for transcripts.
- [ ] Deletion removes files, DB rows, FTS index entries, temp/chunk files and cached prompts.
- [ ] Crypto-shredding for encrypted files (discard per-file key).
- [ ] "Delete all data" in settings.

## Acceptance Criteria
- After deletion, no residual files for that recording in app container (automated check).
