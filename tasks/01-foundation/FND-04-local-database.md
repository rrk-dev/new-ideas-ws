# FND-04 — Local Database (Decision + Schema + Migrations)

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-02 | **Source:** §4.1 (Isar or SQLite — open decision)
**Status:** todo
**Skills:** vv-task-workflow, vv-local-database, vv-decision-records, vv-testing, vv-flutter-architecture

## Goal
Pick and implement the metadata store for recordings, transcripts, jobs, profiles, routing rules and settings.

## Scope
- [ ] Decision spike: Isar vs SQLite. **Recommendation: SQLite via `drift`** (Isar maintenance has stalled; SQLite gives FTS5 for search and SQLCipher for encryption — see APP-02, SEC-01). Record as ADR-FND-04.
- [ ] Schema v1 tables: `recordings`, `audio_chunks`, `transcripts`, `transcript_segments` (start/end ms, speaker, text), `jobs`, `profiles`, `templates`, `routing_rules`, `vault_targets`, `exports`, `settings`, `models_installed`.
- [ ] Migration framework with schema version tests.
- [ ] Repository layer exposing streams for Riverpod.
- [ ] DB file located in app-private storage (not exported, not backed up to cloud unless user opts in — see SEC-01).

## Acceptance Criteria
- Migration tests pass from v1 → future v2 fixture.
- CRUD + stream tests for every repository.
- ADR-FND-04 committed.
