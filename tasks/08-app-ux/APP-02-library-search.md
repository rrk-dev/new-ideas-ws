# APP-02 — Recording Library & Local Full-Text Search

**Workstream:** App UX | **Phase:** 3 | **Size:** M | **Depends on:** FND-04, STT-03 | **Source:** Gap (§4.1 mentions indexing metadata & task status but no UI)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-local-database, vv-whisper-stt, vv-pipeline-orchestrator, vv-markdown-vault-export, vv-testing

## Goal
Browse, filter and search all past recordings, transcripts and extracted items locally.

## Scope
- [ ] Library list: title, date, duration, profile, status (processing/exported/failed), export destination.
- [ ] Filters: profile, date range, tag, status; sort options.
- [ ] Full-text search over transcripts and extracted fields (SQLite FTS5).
- [ ] Recording detail: audio player, transcript (STT-06), extracted result, export history, actions (re-extract, change profile, re-export, delete).
- [ ] Cross-recording action-item view (open tasks across meetings) backed by the `action_items` table (filled by RenderStep; `done` toggled in-app) — task status indexed per §4.1.

## Acceptance Criteria
- Search over 1,000 recordings returns in < 200 ms.
- Deleting a recording removes audio, transcript, DB rows (SEC-04) and asks whether to delete exported note.
