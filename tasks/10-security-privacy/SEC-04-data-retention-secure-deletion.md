# SEC-04 — Data Retention Policies & Secure Deletion

**Workstream:** Security & Privacy | **Phase:** 3 | **Size:** S | **Depends on:** FND-04, SEC-01 | **Source:** Gap
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-local-database, vv-testing

## Goal
Users (and enterprises) control how long raw audio and transcripts are kept.

## Scope
- [x] Policies: delete audio after successful export / after N days / never; same for transcripts.
- [x] Deletion removes files, DB rows, FTS index entries, temp/chunk files and cached prompts.
- [x] Crypto-shredding for encrypted files (discard per-file key). ADR-SEC-01 uses no per-file keys (OS file encryption), so the shredded key is the database key ("Delete all data" rekeys the DB and destroys the old key); per-file shredding comes with `vvenc` → SEC-10.
- [x] "Delete all data" in settings.

## Acceptance Criteria
- After deletion, no residual files for that recording in app container (automated check).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/SEC-04-data-retention-secure-deletion (stacked on
  task/SEC-01-encryption-at-rest: uses its KeyVault/sqlite3mc cipher) · **Date:** 2026-10-14
- **Summary:**
  - `PRAGMA secure_delete = ON` on every connection (`app/lib/core/db/connection.dart`).
  - `RecordingPurger` (`app/lib/features/retention/data/recording_purger.dart`): one transaction
    deletes the recording's rows (FK cascade over every child table) **and** its FTS rows
    (`search_index`, cleaned when APP-02 creates it), then WAL truncation, then files: chunk
    files + `audio/<id>/`, `work/<jobId>/` (cached prompts / intermediates), `rendered/<id>.md`.
    Scopes `all` / `audio` / `transcripts`; refuses while a pipeline step runs; never deletes
    outside `vv/` (crafted relative paths); `sweepOrphans()` removes files left by a crash.
  - Retention (`retention_policy.dart`, `retention_sweeper.dart`, `retention_providers.dart`):
    APP-03's "Keep audio" / "Keep transcripts and notes" (forever / after export / N days),
    effective value managed › user › default; skips recordings being captured or with an
    unfinished job; both due → whole recording. `RetentionScheduler` runs at start + hourly via
    `RetentionHost` in `bootstrap.dart`, and completes a pending key rotation.
  - "Delete all data" (`secure_data_wiper.dart`, wired into APP-03's `dataWiperProvider`):
    releases SAF grants, deletes every row (+FTS) except installed models in one transaction,
    WAL truncate + `VACUUM`, crypto-shreds the DB key (`app/lib/core/security/database_key_rotation.dart`:
    rekey to `db.next`, destroy `db.v1`; next launch rekeys back with `Sqlite3mcCipher`'s
    fallback key), deletes every file under `vv/` except `db/`, `models/` and the pre-opened
    native crash file, plus the app temp dir. Settings shows success / failure truthfully.
- **Acceptance evidence:**
  - AC1: ✅ test: [SEC-04/AC1]
- **Decisions:** PRODUCT-DECISIONs: (1) when audio and transcript are both due the recording row
  is deleted too; (2) "Delete all data" keeps downloaded models (no user data, large); (3)
  retention runs at app start + hourly while open (no background task).
- **Follow-ups:** APP-02 should call `recordingPurgerProvider` for per-recording delete in the
  library; SEC-10 (per-file crypto-shredding with `vvenc`).
