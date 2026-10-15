# EXP-02 — Filename Templates, Sanitization & Collisions

**Workstream:** Export | **Phase:** 3 | **Size:** S | **Depends on:** EXP-01 | **Source:** §3.1.4 (`YYYY-MM-DD-Meeting-Topic.md`)
**Status:** review
**Stacked on:** EXP-01 (branch `task/EXP-01-markdown-template-engine`, itself stacked on PRF-01) — merge those first.
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-testing

## Goal
Predictable, valid, configurable filenames and sub-folder paths.

## Scope
- [x] Pattern tokens: `{{date:YYYY-MM-DD}}`, `{{time}}`, `{{profile}}`, `{{title}}`, `{{slug}}`, sub-folders (`{{date:YYYY}}/{{date:MM}}/`).
- [x] Sanitize for iOS/Android/Windows-synced vaults (reserved chars, length ≤ 255 bytes, trailing dots/spaces, emoji handling).
- [x] Collision strategy: append `-2`, overwrite (re-export of same recording), or skip — configurable.
- [x] Stable identity: store export path per recording to update instead of duplicate on re-export.

## Acceptance Criteria
- Unit tests for sanitization edge cases and all collision modes.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/EXP-02-filename-templates (stacked on task/EXP-01-markdown-template-engine) · **Date:** 2026-10-13
- **Summary:** `FilenamePattern` (`app/lib/features/export/domain/filename_pattern.dart`): own `{{token}}` /
  `{{token:arg}}` parser (not Mustache) for `date:FMT`, `date`, `time`, `title`, `slug` (EXP-01 `slugify`, ≤ 60),
  `profile`, `id`; literal `/` = sub-folder, token values never create folders; parse errors →
  `FilenamePatternFailure(column)` (new in `core/errors/failure.dart`); `.md` enforced; empty tokens drop one
  joiner. `sanitizeSegment` / `VaultFileName` (`filename_sanitizer.dart`): NFC (`unorm_dart` 0.3.2), reserved +
  Obsidian-link characters, controls, bidi marks, whitespace, leading/trailing dots & spaces, `.`/`..`, Windows
  device names, ≤ 255 UTF-8 bytes per segment truncated before the extension on grapheme boundaries (`characters`),
  `untitled` fallback, suffix-safe `withSuffix`. `planExport` (`export_collision.dart`): modes `suffix` / `overwrite`
  / `skip` with stable identity from `exports.rel_path` + `content_hash` (re-export updates in place; unchanged
  content → no write; deleted note re-created; user-edited note handled per mode when a vault read is available;
  foreign files never overwritten; paths of other recordings' exports count as taken; NFC + case-insensitive
  comparison). `ExportIdentity.load` (`export/data/export_identity.dart`) reads prior + claimed paths from FND-04
  `exports`. Docs: `docs/templates.md` → "Filename patterns"; dependency row `unorm_dart` in `docs/privacy-audit.md`.
- **Acceptance evidence:**
  - AC1: ✅ test: [EXP-02/AC1]
- **Decisions:** no ADR (the only new dependency, `unorm_dart`, is reviewed in `docs/privacy-audit.md`; the Dart SDK
  has no Unicode normalization). Engineering choices: `# ^ [ ]` are removed too (Obsidian cannot link such names);
  bidi controls removed (extension spoofing); comparison is case-insensitive; the `exports` row of any status is the
  identity (avoids a duplicate after a failed retry). PRODUCT-DECISION (proposed default, confirm): collision mode
  default `suffix`; `overwrite` replaces a *user-edited* copy of our own note on re-export but never a foreign file.
- **Follow-ups:** see below.

## Follow-ups
- EXP-05: use `FilenamePattern` (profile `filename_pattern` / rule pattern / default) + `ExportIdentity.load` +
  `planExport` in `WriteStep` (today it still writes `<recording_id>.md`); add a `read`/hash capability to
  `VaultWriter` so `currentHash` can detect user edits; store the collision mode in settings (per target).
- EXP-07/PRF-07: validate a pattern on save with `FilenamePattern.parse` and show the column.

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ · analyze ✅ · tests ✅ (780 passed, 29 skipped; coverage not re-measured locally, CI test job gates ≥80% and is green) · native smoke n/a (no native/bridge change) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51 of ci, commit 67b6fcf, completed successfully; run 50 also succeeded)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[EXP-02/AC1]`; sanitization covers reserved characters, controls, bidi/RLO, whitespace, `.`/`..`, Windows device names, NFC, 255-byte grapheme truncation, emoji. Collision tests cover suffix, overwrite (never a foreign file), and skip, plus stable identity via `exports.rel_path` (update in place, unchanged hash skips, deleted note recreated, user-edited note follows the mode). Mutation: dropped `:` from the reserved class; the sanitizer test failed (`abc:defghij` vs `abcdefghij`); restored
- **Adversarial checks:** empty title, `CON`/`COM1`/`nul.txt`, decomposed `é`, surrogate, path traversal tokens (`../`, absolute, `//`), unknown token column, suffix exhaustion, vault errors propagated, case-insensitive claimed paths. Token values cannot create folders. No content logging.
- **Skill/rule compliance:** own token parser (not Mustache), documented in `docs/templates.md`. `unorm_dart` reviewed in the privacy audit; no ADR required. No credentials, certificates, or banned crypto.
- **Issues found:** none
- **Pending for done:** dependency EXP-01 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
