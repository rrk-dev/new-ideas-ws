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


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (387 files, 0 changed) · flutter analyze ✅ (0 issues) · flutter test --coverage ✅ (785 passed, 24 skipped on this host; Linux goldens/platform/model-dependent checks are not all executed locally) · coverage check_coverage: 93.2% of 4708 lines in 126 gated files (min 80%) · pytest tools/ci/tests ✅ (66 passed) · native/build.sh host + ctest ✅ (23 registered: 9 executed/pass, 14 explicitly skipped without configured model/backend fixtures) · egress ✅ · recording policy ✅ (source manifests; no local merged Android build) · tasks.py validate ✅ (85 tasks, 0 problems) · CI: [main run 51](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858), same verified SHA, six jobs green; [PR run 50](https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574) also green. Shared gates were run once before mutations, as requested; logs under /tmp/vv-verify-a/.
- **Fresh state / review:** Fresh clone of origin/main; local branch `verify/codex-a`. Reviewed task scope, Completion Notes, implementation history/diffs, current source, listed skills and tagged tests. No product/test fixes retained.
- **Acceptance criteria:**
  - AC1: ✅ fixture_v2_migration_test.dart validates frozen v1, actual v1 file reopen into v2, preserved recordings/segments/jobs/settings and imported-label backfill, foreign keys, missing upgrade step rejection and downgrade refusal.
  - AC2: ✅ Read all tagged repository tests: recordings/chunks/VAD/markers/speakers, transcripts/segments, jobs/queue order, profiles/templates, extractions/action items, vault targets/rules/exports, models and settings. They assert real CRUD outputs and stream emissions plus idempotency, filtering, not-found and FK failure paths.
  - AC3: ✅ Read docs/adr/ADR-FND-04-database.md: options/weights, host evidence, drift/sqlite pins, migration policy, isolates, storage location, encryption seam and explicit device-measurement limits.
- **Adversarial checks:** Changed beforeOpen foreign_keys from ON to OFF; [FND-04/AC1] foreign-key enforcement assertion failed, then passed after git checkout restored migrations.dart. Reviewed duplicate IDs, unknown FKs, missing migration steps, downgrade/reopen, Unicode/JSON-capable values and cascade tests.
- **Skill/rule compliance:** drift DAOs/providers, background connection, versioned snapshot and relative private-storage paths follow the loaded skills. Cipher and iOS backup protection are explicitly owned by SEC-01, not claimed delivered here; ADR remains Proposed without device measurements. AGENTS.md, vv-task-workflow and vv-task-verify followed; no push, PR, GitHub API, tool installation or git-config changes.
- **Issues found:** none
- **Acceptance runner:** `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify FND-04 --run` was invoked; its evidence/dependency checks refused before launching tagged tests. All referenced tagged tests were instead executed in the shared full Dart/pytest suites, then the mutation target was re-run red and green after restoration (QA-05 is artifact-only). Pre-report diagnostic output: `/tmp/vv-verify-a/FND-04-verify.log`.
- **Pending for done:** dependency FND-02 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task.
