# ADR-FND-04 — Local database: drift on SQLite (sqlite3 v3 build hooks)

- **Status:** Proposed (host-verified; no on-device measurement yet — see Evidence)
- **Date:** 2026-10-12
- **Task:** FND-04
- **Deciders:** Claude Code (implementer); pending independent verifier + human
- **Supersedes:** —

## Context
VaultVoice needs one on-device metadata store for recordings, audio chunks, transcripts and
segments, pipeline jobs, profiles, templates, extractions, vault targets, routing rules, exports,
installed models and settings. Constraints (AGENTS.md): fully offline, no telemetry, iOS 16+ /
Android 26+ arm64, reactive streams for Riverpod UI, safe schema migrations, full-text search
later (APP-02), encryption at rest later (SEC-01), access from a background pipeline isolate
(FND-05) without opening a second connection, permissive license for commercial redistribution.

## Options
1. **drift on SQLite** (`drift` + `drift_dev`, SQLite bundled by `package:sqlite3` v3 build hooks)
   — recommended in `tasks/README.md` → Open Decisions.
2. **Isar** — embedded NoSQL with codegen and watchers.
3. **Raw `sqlite3` / `sqflite`** — SQL by hand, no codegen, no typed streams.
4. **ObjectBox** — embedded object store with Flutter bindings.

## Criteria (weights fixed before evaluating)
| Criterion | Weight |
|---|---|
| Maintenance health (releases, bus factor, Dart 3.13 / Flutter 3.47 support) | 25% |
| Migration safety (versioned schema, generated tests) | 20% |
| Search (FTS5) + encryption path (SQLCipher / SQLite3MultipleCiphers) | 20% |
| Reactive streams + isolate sharing | 15% |
| License & privacy (no network at runtime) | 10% |
| Integration effort / testability on host | 10% |

## Evidence
Environment: macOS host (arm64), Flutter 3.47.7 via FVM, `drift` 2.35.2, `drift_dev` 2.35.1,
`sqlite3` 3.7.0 (build hooks), `path_provider` 2.1.6. No physical device was available.

| Check | Result |
|---|---|
| SQLite bundled by `sqlite3` 3.7.0 hooks on host | `sqlite_version()` = 3.53.4, `sqlite_compileoption_used('ENABLE_FTS5')` = 1 |
| Encryption build available without code change | `hooks: user_defines: sqlite3: source: sqlite3mc` (or `sqlcipher`) — documented in `sqlite3` 3.7.0 `doc/hook.md`; not enabled here (SEC-01) |
| Schema snapshot + migration test tooling | `drift_dev make-migrations` → `app/drift_schemas/vaultvoice/drift_schema_v1.json`; `drift_dev schema generate` → `app/test/db/migrations/vaultvoice/generated/` |
| v1 → v2 fixture migration (data preserved, schema validated) | `app/test/db/migrations/fixture_v2_migration_test.dart` — passing on host |
| CRUD + stream tests for all 8 repositories | `app/test/db/repositories/*` — passing on host |
| Background isolate (`NativeDatabase.createInBackground`) + cipher hook runs first | `app/test/db/db_infra_test.dart` (`PRAGMA application_id` set by the hook is visible) |
| Line coverage of `lib/core/**` incl. the DB layer | 97.4 % (`tools/ci/check_coverage.py`) |

Option 2 (Isar): the 3.x line has had no stable release for a long time and depends on its own
native core; no FTS5 or SQLCipher-class encryption story (from the project's public repository at
the time of writing — not re-measured here). Option 3 loses typed queries, generated migration
tests and table-level stream invalidation, which drift provides on the same SQLite engine.
Option 4 has a proprietary core library and no SQL/FTS5.

Not measured (device-only, follow-up in PRF/QA benchmarks): open latency and query latency on a
low-end Android device; `sqlite3mc` binary size delta.

## Decision
We choose **drift on SQLite** (Option 1), with these design rules:

- **One process-wide connection** opened by `openDatabaseFile()` (`lib/core/db/connection.dart`)
  on a drift background isolate (`NativeDatabase.createInBackground`). Other isolates (the FND-05
  pipeline worker) use `db.serializableConnection()`; never a second independent connection.
- **Encryption switch point:** `DatabaseCipher.apply(raw)` runs first on every raw connection.
  FND-04 ships `PlaintextCipher`; SEC-01 provides an implementation that issues `PRAGMA key`
  and asserts `PRAGMA cipher`, overrides `databaseCipherProvider`, and adds the `sqlite3`
  `user_defines` in `pubspec.yaml`. No other DB code changes.
- **Location:** `<appSupport>/vv/db/vaultvoice.sqlite` (`StoragePaths`) — Application Support on
  iOS, `filesDir` on Android; never Documents. Stored file paths are **relative** to `vv/`.
- **Backups:** Android `allowBackup="false"` + `dataExtractionRules` / `fullBackupContent`
  excluding all domains (done here). iOS `isExcludedFromBackup` on `vv/` needs a platform
  channel and is part of SEC-01 ("Exclude app data from cloud backups by default").
- **Schema v1** (`lib/core/db/tables/`): all 17 tables of `vv-local-database`. Timestamps are UTC
  epoch-ms ints (`EpochMsConverter`), JSON columns use `TypeConverter`s, enums are stored by
  Dart name (`textEnum`). Child tables use `ON DELETE CASCADE`; idempotency keys are unique
  (`audio_chunks(recording_id, seq)`, `transcript_segments(transcript_id, seq)`,
  `speakers(recording_id, label)`, `exports(recording_id, target_id)`).
- **Migrations:** `buildMigrationStrategy()` (`lib/core/db/migrations.dart`) — `createAll` on
  create; on upgrade FKs off, every registered step in one transaction, downgrade refused,
  `PRAGMA foreign_key_check` after; FKs on in `beforeOpen`. Steps are registered per target
  version in `VaultVoiceDatabase.migrationSteps`; each bump runs `drift_dev make-migrations`.
- **Repositories** are drift DAOs (`lib/core/db/repositories/`) returning `Result<T>` for
  reads/writes (errors mapped to content-free `StorageFailure('sqlite error <code>')`) and
  `Stream`s for watchers; Riverpod providers in `lib/core/db/db_providers.dart`.

### Deviations from the skill table (engineering choices)
- `transcript_segments.text` and `action_items.text` are named **`body`**: `drift_dev schema
  generate` 2.35.1 emits a `text` getter that conflicts with `Table.text()` and fails to compile.
- `recordings.source` value `import` is stored as **`imported`** (Dart reserved-word clash);
  status values are Dart enum names (`inProgress`, not `in_progress`).
- `jobs` gains `priority`, `waiting_reason`, `not_before` (FND-05 queue order, `waiting(reason)`,
  retry backoff) — added in v1 because nothing has shipped yet.

## Consequences
- Positive: typed SQL, FTS5 available for APP-02, cipher switch is one provider override plus a
  pubspec user-define, frozen schema snapshots + generated migration helpers, fast host tests
  with `NativeDatabase.memory()`.
- Negative / risks:
  - `sqlite3` build hooks download pre-compiled SQLite from the package's GitHub releases at
    **build time** (sha256-pinned by the package). Runtime makes no network calls. If builds must
    be hermetic, set `hooks: user_defines: sqlite3: url_pattern:` to an internal mirror (CI
    follow-up).
  - SQLite3MultipleCiphers / SQLCipher have their own licenses — SEC-01 must record them in
    `docs/licenses.md`.
  - Generated code (`*.g.dart`, schema helpers) is committed; `tools/ci/check_codegen.sh` guards
    staleness.
- Follow-up tasks: SEC-01 (cipher + iOS backup exclusion), SEC-04 (secure deletion of files;
  rows already cascade), APP-02 (FTS5 `search_index` as `.drift` file; `fts5` module already
  enabled in `app/build.yaml`).
