# EXP-07 — Template Editor with Live Preview (Pro)

**Workstream:** Export | **Phase:** 3 | **Size:** M | **Depends on:** EXP-01, LIC-01 | **Source:** §7 (Custom Markdown template engine — Pro)
**Status:** review
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-flutter-architecture, vv-licensing-iap, vv-extraction-profiles, vv-testing

## Goal
Pro users edit Markdown templates and filename patterns with immediate feedback.

## Scope
- [x] Code editor with Mustache syntax highlighting and variable autocomplete from the bound profile's schema.
- [x] Live preview using sample data or a real past recording.
- [x] Rendered Markdown preview toggle.
- [x] Reset to default; duplicate; per-profile template binding.

## Acceptance Criteria
- Syntax errors highlighted inline; preview updates < 200 ms after typing stops.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/EXP-07-template-editor · **Date:** 2026-10-14
- **Summary:** Settings › Templates (`/settings/templates`) lists built-in (read-only, duplicable)
  and custom templates; the editor (`/settings/templates/:templateId`,
  `templates/presentation/template_editor_screen.dart`) uses `re_editor` 0.10.0 with
  `re_highlight` `langHandlebars` highlighting, autocomplete of every context path from the
  profile schema + `meta` + `transcript` + list-item fields + lambdas (`templateCompletions`,
  only inside an open `{{` tag), inline problem markers (`⚠` in the line gutter + "Line N, column
  M" list that jumps to the position), live preview debounced 150 ms (`kPreviewDebounce`; AC is
  < 200 ms) on sample data (profile example) or one of the last 10 valid extractions of that
  profile, raw / rendered toggle (`flutter_markdown_plus`, network images replaced by their alt
  text), filename pattern field (EXP-02 parser), save gated by
  `MarkdownTemplateEngine.validate`, Duplicate, Reset to default (built-in origin), Delete and
  "Use for <profile> notes" binding. Storage: `templates` rows + settings `templates.meta`
  (schema profile, base) and `templates.bindings` (profile → template, the
  `TemplateNoteRenderer.templateOverrides` input); `templates.profile_id` is never set for a
  built-in profile (FK; ADR-EXP-01). Pro: `Feature.customTemplates` gates Duplicate; custom
  templates are read-only after a downgrade. Dependency review in `docs/privacy-audit.md`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [EXP-07/AC1]; device: docs/test-plans/device/EXP-07.md
- **Decisions:** PRODUCT-DECISION: template name = its id (slug), as the `templates` table has
  no name column; preview of built-ins hides validation issues (assets are tested, and
  `summary-only` has its own shape).
- **Follow-ups:** FND-11 wiring: build `TemplateNoteRenderer` with `userTemplates` (custom
  template bodies) and `templateOverrides` (`templates.bindings`) from this store; custom
  templates' `filenamePattern` is stored but not yet used by the exporter (EXP-05 uses rule /
  folder / global patterns) — proposed EXP-12 (renumbered in integration wave 3).
- Codex review 2026-10-15 (open): selecting a past recording only supplies extraction JSON; pass full recording metadata/transcript rendering context
- Codex review 2026-10-15 (open): previewTemplate takes only extraction JSON; past-recording preview should pass full recording metadata/transcript context (API change)
