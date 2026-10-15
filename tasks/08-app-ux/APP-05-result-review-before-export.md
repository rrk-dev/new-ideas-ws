# APP-05 — Extraction Result Review & Edit Before Export

**Workstream:** App UX | **Phase:** 3 | **Size:** M | **Depends on:** LLM-05, EXP-01 | **Source:** Gap (small local models make mistakes; users need a check step)
**Status:** review
**Skills:** vv-task-workflow, vv-flutter-architecture, vv-extraction-profiles, vv-markdown-vault-export, vv-pipeline-orchestrator, vv-whisper-stt, vv-testing

## Goal
Optionally review and correct extracted fields before the note is written to the vault.

## Scope
- [x] Setting: auto-export vs review-first (per profile).
- [x] Form view generated from profile schema (edit attendees, tasks, owners, dates).
- [x] Each item links to its source timestamp in the transcript (from LLM-05 evidence fields).
- [x] Rendered Markdown preview; "Export" commits.

## Acceptance Criteria
- Edits are reflected in exported Markdown; source-link jumps to correct audio position.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/APP-05-review-before-export (stacked on
  task/APP-02-library-search: reuses the recording detail, `TranscriptNavigator`, transcript
  lines and library providers) · **Date:** 2026-10-14
- **Summary:** Per-profile setting `review.mode.<profile>` (Settings › Export › Review before
  export, `ReviewSettingsScreen`; unset = the profile's `review_before_export`). Pipeline:
  `RenderStep` asks `ReviewGate` (`pipeline/data/steps/review_gate.dart`, DB-only so it runs in the
  worker isolate) and returns `StepWaiting(WaitingReason.review)` until the user approved exactly
  the current content (`review.approved.<extraction>` = order-independent content hash, so a
  re-extraction is reviewed again). Review screen (`/library/recordings/:id/review`, banner + menu
  entry on the recording detail): `SchemaForm` generated from the profile output schema (text /
  enum dropdown / number / switch, repeatable groups with add/remove, nested cards), evidence `t`
  fields with a ▶ source link → `TranscriptNavigator.open(atMs)` (default: transcript lines
  highlighted at that time; STT-06 override adds the audio seek); schema validation of the edits
  (export disabled while invalid); Preview tab renders the edits with the same EXP-01
  `TemplateNoteRenderer` as the pipeline; "Export note" (`ReviewService.approveAndExport`) saves
  the JSON (`ExtractionsRepository.updateJson`), stores the approval, then `resolveWaiting` (or
  `rerun(render)` for an already exported note so the vault note gets the edits). Recording
  deletion also drops its approvals.
- **Acceptance evidence:**
  - AC1: ⏳ test: [APP-05/AC1]; device: docs/test-plans/device/APP-05.md
- **Decisions:** none (no technology choice). PRODUCT-DECISIONs: default stays auto-export (all
  built-in profiles ship `review_before_export: false`); export is blocked while edits violate the
  schema (an invalid result would fall back to the summary-only template and drop the edits);
  the preview shows Markdown source (no Markdown-rendering dependency added).
- **Follow-ups:** see below.
- **Privacy checklist:** no network code; no logging; no new dependencies; approvals are hashes,
  not content.

## Follow-ups
- **STT-06 integration:** override `transcriptNavigatorProvider` so source links also seek the
  audio (AC "source-link jumps to correct audio position" device row depends on it).
- **APP-04 note:** a local notification "Your result is waiting for review" when a job enters
  `waiting(review)` would help review-first users (not in scope here).
- Codex review 2026-10-15 (open): preview omits custom templates/bindings used by production export; share renderer loader
- Codex review 2026-10-15 (open): schema_form.dart:151 invalid numeric input silently becomes 0/null; preserve invalid state and block export
