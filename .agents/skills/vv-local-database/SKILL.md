---
name: vv-local-database
description: "drift/SQLite implementation: schema tables, DAOs, migrations (make-migrations), FTS5 search, encrypted DB setup and key handling code, file storage layout, secure-deletion code. Use when adding tables, persisted state or search."
---

# Local Database (drift + SQLite)

Default per tasks/README: **drift on SQLite** (ADR-FND-04 records it in FND-04). If ADR-FND-04
decides otherwise, follow the ADR and update this skill.

## Packages (verify current versions on pub.dev; pin exact)
`drift`, `drift_dev` (dev), `build_runner` (dev), `path_provider`, `path`.
`sqlite3` ≥ 3.x bundles SQLite via build hooks — do **not** add `sqlite3_flutter_libs` or
`sqlcipher_flutter_libs` (both EOL with sqlite3 v3; see sqlite3.dart `UPGRADING_TO_V3.md`).
Encryption (SEC-01): in `app/pubspec.yaml` set `hooks: user_defines: sqlite3: source: sqlite3mc`
(SQLite3 Multiple Ciphers, drift-recommended; `source: sqlcipher` also supported — record the
choice in the SEC-01 ADR). Follow the current drift "Encryption" page for your pinned versions.

## Schema v1 (FND-04) — `app/lib/core/db/tables/`
| Table | Key columns |
|---|---|
| `recordings` | id (uuid text PK), title, created_at, duration_ms, status (`recording/in_progress/recorded/failed`), source (`mic/import`), profile_id?, tags (json), consent_confirmed_at?, import_attested_at?, stop_reason? (`user/call_interruption/max_duration/silence/low_storage`), recovered (bool) |
| `audio_chunks` | id, recording_id FK, seq, path (relative), sample_rate, start_ms, end_ms, bytes, sha256? |
| `speech_segments` (VAD) | id, recording_id, start_ms, end_ms |
| `markers` | id, recording_id, at_ms, kind (`user/gap/call_interruption/consent`), label? |
| `transcripts` | id, recording_id, model_id, language, created_at, edited (bool) |
| `transcript_segments` | id, transcript_id, seq, start_ms, end_ms, speaker?, text, original_text? (pre-edit), avg_logprob?, tokens_json? (`[{text,p,t0_ms,t1_ms}]` for low-confidence highlighting) |
| `speakers` | id, recording_id, label (`Speaker 1`), display_name? |
| `jobs` | id, recording_id, kind, step, status, progress, attempts, error_code?, error_detail?, created_at, updated_at, checkpoint (json) |
| `profiles` | id, version, source (`builtin/user/enterprise`), definition (json), updated_at |
| `templates` | id, profile_id?, body, filename_pattern, updated_at |
| `extractions` | id, recording_id, profile_id, profile_version, model_id, json, valid (bool), created_at |
| `vault_targets` | id, platform, display_name, handle (SAF uri / bookmark base64), created_at |
| `routing_rules` | id, priority, match (json), target_id, sub_path, filename_pattern |
| `action_items` | id, recording_id, extraction_id, text, owner?, due_iso?, t_ms?, done (bool), done_at? — filled by RenderStep for APP-02's cross-recording task view |
| `exports` | id, recording_id, target_id, rel_path, content_hash, status, attempts, updated_at |
| `models_installed` | id, type, version, path, sha256, size, installed_at |
| `settings` | key PK, value (json) |
Rules: timestamps as UTC epoch ms ints; store **relative** paths (container paths change on iOS
reinstall/update); JSON columns via drift `TypeConverter`s to freezed classes.

## Isolates
The pipeline worker runs in a background isolate: open the DB once with
`NativeDatabase.createInBackground` / `DriftIsolate` and share it (drift `shareAcrossIsolates` /
`DriftIsolate.connect`) — never open two independent connections to the encrypted file.

## FTS5 (APP-02)
Enable the module for drift_dev's analyzer in `app/build.yaml`:
`targets: $default: builders: drift_dev: options: sql: {dialect: sqlite, options: {modules: [fts5]}}`.
Use a `.drift` file: `CREATE VIRTUAL TABLE search_index USING fts5(recording_id UNINDEXED, kind UNINDEXED, body, tokenize='unicode61 remove_diacritics 2');`
Keep it in sync with triggers or in the repository write path (one place). Query with `MATCH`
and `bm25()`; escape user input (wrap terms in double quotes) to avoid FTS syntax errors.

## Migrations
- `schemaVersion` bump + `MigrationStrategy.onUpgrade` step per version (`stepByStep` helper).
- Configure `drift_dev` options in `app/build.yaml`: `databases: {vaultvoice: lib/core/db/database.dart}`,
  `schema_dir: drift_schemas/`, `test_dir: test/db/migrations/`. After every `schemaVersion` bump run
  `fvm dart run drift_dev make-migrations` (emits schema JSON, `*.steps.dart` for `stepByStep`,
  and migration tests). Generated tests must pass for every from→to pair.
- Never edit a released migration.

## Files on disk
```
<appSupport>/vv/            (Application Support on iOS, filesDir on Android — NOT Documents)
  db/vaultvoice.sqlite
  audio/<recording_id>/chunk_<seq>.wav | archive.m4a
  work/<job_id>/...         (intermediate artifacts, deleted on job completion)
  rendered/<recording_id>.md
  models/<model_id>/...     (excluded from backup)
  logs/
```
Exclude `models/` (and by default everything) from iCloud/Google backup (see `vv-privacy-security`).

## Encryption key (SEC-01)
Random 32-byte key generated on first launch, stored in Keychain
(`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — needed so background work can open the DB)
/ Android Keystore-wrapped (e.g. `flutter_secure_storage`, verify its Android backend). Issue
`PRAGMA key` first inside `NativeDatabase.createInBackground(file, setup: (db) { … })`; assert the
cipher build with `PRAGMA cipher` (sqlite3mc) / `PRAGMA cipher_version` (sqlcipher).

## Secure deletion (SEC-04)
Delete in one repository method inside a transaction: rows (all child tables + FTS), then files
(audio dir, work dir, rendered md). Use `PRAGMA secure_delete = ON`. For per-file encrypted
audio, delete the wrapped file key (crypto-shredding). Provide a test that asserts no residual
files/rows after deletion.

## Verification
CRUD + stream tests per DAO, migration tests, FTS query test with tricky input (`"`, `*`, `-`),
encrypted DB cannot be opened without key (test on device or host with sqlcipher).
