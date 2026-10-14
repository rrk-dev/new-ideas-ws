# APP-02 — Recording Library & Local Full-Text Search

**Workstream:** App UX | **Phase:** 3 | **Size:** M | **Depends on:** FND-04, STT-03 | **Source:** Gap (§4.1 mentions indexing metadata & task status but no UI)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-local-database, vv-whisper-stt, vv-pipeline-orchestrator, vv-markdown-vault-export, vv-testing

## Goal
Browse, filter and search all past recordings, transcripts and extracted items locally.

## Scope
- [x] Library list: title, date, duration, profile, status (processing/exported/failed), export destination.
- [x] Filters: profile, date range, tag, status; sort options.
- [x] Full-text search over transcripts and extracted fields (SQLite FTS5).
- [x] Recording detail: transcript (read-only lines; STT-06 editor via `TranscriptNavigator`), extracted result, export history, actions (re-extract, change profile, re-export, delete).
- [~] Recording detail audio player: deferred → STT-06 (its transcript viewer owns playback — `just_audio` over the chunk reader; it plugs in by overriding `transcriptNavigatorProvider`).
- [x] Cross-recording action-item view (open tasks across meetings) backed by the `action_items` table (filled by RenderStep; `done` toggled in-app) — task status indexed per §4.1.

## Acceptance Criteria
- Search over 1,000 recordings returns in < 200 ms.
- Deleting a recording removes audio, transcript, DB rows (SEC-04) and asks whether to delete exported note.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/APP-02-library-search (stacked on
  task/MDL-03-model-management → task/APP-01-onboarding: shares `app_en.arb`, routes and test
  helpers) · **Date:** 2026-10-14
- **Summary:** FTS5 search in schema **v2** (`app/lib/core/db/tables/search.drift`:
  `search_index(recording_id, kind, body)` with `unicode61 remove_diacritics 2`; one row per
  recording title+tags, one per transcript segment (rowid = −segment id, so a segment write is
  O(1)), one per newest extraction (all string leaves); kept in sync by SQL triggers — the single
  write path, whichever isolate writes; migration step `core/db/search_migration.dart` creates
  them from the frozen `database.steps.dart` snapshot and backfills; `drift_schema_v2.json` +
  generated migration test). `SearchRepository`: every term quoted (`ftsTerms`), last term prefix,
  recordings must contain every term (`INTERSECT`), bm25 ranking, snippet. Library
  (`features/library/`): list with title/date/duration/profile/status/export destination, search
  field, filter chips (status, profile, tag, date range), sort (newest/oldest/longest/title),
  empty/no-match/error states. Recording detail (route `/library/recordings/:id`, still the
  notification deep-link target): facts, processing status card, transcript preview →
  `TranscriptLinesScreen` (`/library/recordings/:id/text?t=<ms>` highlights the line at `t`),
  extracted fields, export history, actions re-extract / change profile / re-export (pipeline
  `rerun`, or `enqueue` when never processed) / delete. Delete dialog asks whether to delete the
  exported note (default keep); `LocalRecordingDeleter` cancels the recording's jobs, deletes the
  notes via each target's `VaultWriter.delete` when asked, deletes all rows (cascade + FTS) in one
  transaction, then audio / work / rendered files. Action items screen
  (`/library/action-items`): open/all, done toggle on `action_items`, link to the recording.
- **Acceptance evidence:**
  - AC1: ⏳ test: [APP-02/AC1]; device: docs/test-plans/device/APP-02.md
  - AC2: ⏳ test: [APP-02/AC2]; device: docs/test-plans/device/APP-02.md
- **Decisions:** none new (FTS5 per `vv-local-database`). PRODUCT-DECISION: the delete dialog
  keeps the exported note unless the user ticks "Also delete the exported note"; untitled
  recordings sort last by title.
- **Follow-ups:** see below.
- **Privacy checklist:** no network code; no logging added (titles, snippets and folder names
  are only displayed); no new dependencies; search index lives in the (SEC-01-encrypted) DB and
  is deleted with the recording (triggers + explicit delete).

## Follow-ups
- **Integration notes:** (1) schema v2 is taken by this task's FTS step — if another branch also
  adds a v2 step, renumber one of them and re-run `make-migrations`; (2) SEC-04's
  `RecordingPurger` already cleans `search_index` — it can back `recordingDeleterProvider`
  (keep the exported-note step); (3) STT-06: override `transcriptNavigatorProvider` with its
  `TranscriptRoute` + `TranscriptPlayback.playFrom(atMs)` so "show transcript" and APP-05 source
  links seek the audio.
- **Test note:** widget tests that open the Library tab or a recording through `App()` need
  `libraryOverrides()` (`test/helpers/library_fixtures.dart`), else the DB-backed providers keep
  loading.
