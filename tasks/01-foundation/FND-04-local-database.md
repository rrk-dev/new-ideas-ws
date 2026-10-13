# FND-04 — Local Database (Decision + Schema + Migrations)

**Workstream:** Foundation | **Phase:** 1 | **Size:** M | **Depends on:** FND-02 | **Source:** §4.1 (Isar or SQLite — open decision)
**Status:** review
**Skills:** vv-task-workflow, vv-local-database, vv-decision-records, vv-testing, vv-flutter-architecture

## Goal
Pick and implement the metadata store for recordings, transcripts, jobs, profiles, routing rules and settings.

## Scope
- [x] Decision spike: Isar vs SQLite. **Recommendation: SQLite via `drift`** (Isar maintenance has stalled; SQLite gives FTS5 for search and SQLCipher for encryption — see APP-02, SEC-01). Record as ADR-FND-04.
- [x] Schema v1 tables: `recordings`, `audio_chunks`, `transcripts`, `transcript_segments` (start/end ms, speaker, text), `jobs`, `profiles`, `templates`, `routing_rules`, `vault_targets`, `exports`, `settings`, `models_installed`.
- [x] Migration framework with schema version tests.
- [x] Repository layer exposing streams for Riverpod.
- [x] DB file located in app-private storage (not exported, not backed up to cloud unless user opts in — see SEC-01). `<appSupport>/vv/db/vaultvoice.sqlite`; Android backup/device-transfer disabled in the manifest. iOS `isExcludedFromBackup` on `vv/` stays with SEC-01 (its scope: "Exclude app data from cloud backups by default").

## Acceptance Criteria
- Migration tests pass from v1 → future v2 fixture.
- CRUD + stream tests for every repository.
- ADR-FND-04 committed.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/FND-04-local-database · **Date:** 2026-10-12
- **Summary:** drift 2.35.2 on SQLite (`sqlite3` 3.7.0 build hooks; no `sqlite3_flutter_libs`). Schema v1 with
  all 17 `vv-local-database` tables in `app/lib/core/db/tables/` (UTC epoch-ms timestamps, JSON/list converters,
  `textEnum`s, cascading FKs, idempotency unique keys). `VaultVoiceDatabase` (`app/lib/core/db/database.dart`),
  migration policy `buildMigrationStrategy` (`migrations.dart`: step registry, transaction, downgrade refused,
  FK check), `openDatabaseFile` on a drift background isolate with the `DatabaseCipher` hook that SEC-01 swaps for
  sqlite3mc (`connection.dart`), `StoragePaths` (`<appSupport>/vv/…`, relative paths), 8 repositories (drift DAOs)
  with `Result<T>` writes and `Stream` watchers (`repositories/`), Riverpod providers (`db_providers.dart`).
  `app/build.yaml` configures `drift_dev` (databases, schema_dir, test_dir, fts5). Frozen schema
  `app/drift_schemas/vaultvoice/drift_schema_v1.json` + helpers in `app/test/db/migrations/vaultvoice/generated/`;
  v2 test fixture `app/test/db/fixtures/v2_fixture_database.dart`. Android `allowBackup=false` + extraction rules.
- **Acceptance evidence:**
  - AC1: ✅ test: [FND-04/AC1]
  - AC2: ✅ test: [FND-04/AC2]
  - AC3: ✅ artifact: docs/adr/ADR-FND-04-database.md
- **Decisions:** ADR-FND-04-database (Proposed: no on-device measurement possible here). Deviations from the skill
  table (documented in the ADR, skill updated): segment/action-item text column is `body`; enum values stored by
  Dart name (`imported`, `inProgress`); `jobs` adds `priority`, `waiting_reason`, `not_before` for FND-05.
- **Gates (host, macOS):** `fvm dart format --set-exit-if-changed .` clean · `fvm flutter analyze` + `fvm dart analyze
  --fatal-infos` 0 issues · `fvm flutter test` all passed · coverage 97.4 % of gated lines · `tasks.py validate` OK.
- **Follow-ups:** SEC-01 (cipher implementation + iOS backup exclusion, sqlite3mc license in docs/licenses.md);
  SEC-04 (file deletion; rows already cascade); APP-02 (FTS5 `search_index`); CI: optional `url_pattern` mirror for
  the sqlite3 build-hook download if builds must be hermetic.
