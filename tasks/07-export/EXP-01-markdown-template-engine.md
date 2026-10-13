# EXP-01 — Markdown Template Engine (Mustache/Handlebars)

**Workstream:** Export | **Phase:** 3 | **Size:** M | **Depends on:** PRF-01 | **Source:** §3.1.4, §5 Phase 3, §7 (Custom template engine — Pro)
**Status:** review
**Stacked on:** PRF-01 (branch `task/PRF-01-profile-data-model`, in review) — merge PRF-01 first.
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-decision-records, vv-testing, vv-extraction-profiles

## Goal
Render structured extraction JSON into Markdown using user-editable templates.

## Scope
- [x] Choose library: `mustache_template` (logic-less, safe) vs a Handlebars port with helpers. Record decision (helpers needed → likely Mustache + small custom lambda set).
- [x] Built-in helpers/lambdas: date formatting, checkbox list, bullet list, table, wikilink `[[...]]`, slugify, transcript embed, audio link, duration.
- [x] YAML front-matter generation with safe escaping.
- [x] Create `docs/markdownlint.json` (used by golden tests and `tools/ci/markdownlint.sh`) and `docs/templates.md` (lambda + context reference).
- [x] Context object documented: extraction JSON + recording metadata (date, duration, speakers, profile, tags, device).
- [x] Error handling: missing variables render empty with warning; template syntax errors reported with line numbers.

## Acceptance Criteria
- Golden-file tests for each built-in template.
- Malicious input (transcript containing `{{` or YAML `---`) cannot break front-matter or template structure.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/EXP-01-markdown-template-engine (stacked on task/PRF-01-profile-data-model) · **Date:** 2026-10-13
- **Summary:** `MarkdownTemplateEngine` (`app/lib/features/templates/domain/template_engine.dart`):
  `mustache_template` 2.0.5 with `htmlEscapeValues: false, lenient: false`; `compile` →
  `TemplateSyntaxFailure(name, line, column)` (new in `core/errors/failure.dart`); `validate` = syntax +
  PRF-01 strict variable check; `render` sanitizes the context, blanks a non-ISO `meta.date`, and on a
  strict render error re-renders leniently with content-free `name:line:col` warnings (missing values →
  empty). All 15 skill lambdas in `template_lambdas.dart` (yaml, yaml_list, wikilink, slug, upper, lower,
  trim, date, duration, checkbox, md_table, bullets, transcript_block, audio_link, code_block); `bullets`
  and `md_table` became path-argument lambdas and `date`/`duration` accept `path|FORMAT` — PRF-01's
  `template_variables.dart` checker + `docs/profile-spec.md` updated accordingly (test keeps the lambda
  map == `kTemplateLambdas` == docs). Sanitization `markdown_sanitizer.dart`: every context string is an
  `InlineText` (inline-safe `toString`; raw inside quoting lambdas via a Zone flag) — newlines collapsed,
  leading block markers stripped, `[[ ]] { { < `` ` `` escaped, controls/bidi overrides removed,
  YAML double-quoted scalars escape every control/line break. Context via PRF-01 `buildRenderContext` +
  `note_context.dart` (`buildNoteMeta`, `buildNoteTranscript`, `summary-only` shape). Built-in assets
  `app/assets/templates/`: `meeting-default`, `meeting-logseq`, `meeting-plain`, `warranty-default`,
  `engineering-default`, `summary-only`. Generic schema → template generator `template_generator.dart`.
  Pipeline seam: `TemplateNoteRenderer` (`features/templates/data/`) is a `NoteRenderer`;
  `PipelineEngines.renderer` (optional) is passed to `RenderStep` by `defaultSteps` (null = FND-05
  placeholder, unchanged default). Docs `docs/templates.md`, `docs/markdownlint.json`,
  `tools/ci/markdownlint.sh` (markdownlint-cli2 0.23.3 via npx; local run: 18 files, 0 issues).
  Dependency review rows (`mustache_template`, `characters`) in `docs/privacy-audit.md`.
- **Acceptance evidence:**
  - AC1: ✅ test: [EXP-01/AC1]; artifact: app/test/fixtures/markdown/golden/
  - AC2: ✅ test: [EXP-01/AC2]
- **Decisions:** ADR-EXP-01 (Proposed until EXP-05 measures device render time; host: 0.47 ms full /
  3.9 ms adversarial-10k per render on M3 Pro). FK note from PRF-01 resolved without a migration:
  built-in templates are read-only assets (no `templates` rows); `templates.profile_id` stays null for
  user templates written for a built-in profile (binding = profile `template_id` / user override).
- **Follow-ups:** see below.

## Follow-ups
- CI (owner of ci.yml): add a step `bash tools/ci/markdownlint.sh` (needs Node.js ≥ 20, e.g.
  `actions/setup-node`) to the `test` or `static` job, after the Flutter tests.
- FND-05 / app wiring: the production `PipelineEnginesFactory` should load `BuiltinProfiles` +
  `BuiltinTemplates` (asset text read before spawning the worker, passed in as strings) and set
  `PipelineEngines.renderer: TemplateNoteRenderer(...).call`; user profiles/templates need a sync
  snapshot from the DB at job start. Left out of EXP-01 to avoid touching worker-isolate asset loading.
- EXP-05: measure on-device render time with the adversarial golden context, then accept ADR-EXP-01;
  pass `LambdaOptions.audioAttachment` when the audio sidecar is exported.
- EXP-07: validate with `MarkdownTemplateEngine.validate` on save; never set `templates.profile_id`
  for built-in profiles; store the per-profile template choice as an override.
- EXP-08: expose `meeting-logseq` / `meeting-plain`; add Logseq/plain variants for warranty/engineering.
- LLM-05: render invalid extractions with `summary-only` (already the renderer's fallback); decide
  where a free-text summary comes from when JSON is invalid.

