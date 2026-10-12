# EXP-01 — Markdown Template Engine (Mustache/Handlebars)

**Workstream:** Export | **Phase:** 3 | **Size:** M | **Depends on:** PRF-01 | **Source:** §3.1.4, §5 Phase 3, §7 (Custom template engine — Pro)
**Status:** todo
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-decision-records, vv-testing, vv-extraction-profiles

## Goal
Render structured extraction JSON into Markdown using user-editable templates.

## Scope
- [ ] Choose library: `mustache_template` (logic-less, safe) vs a Handlebars port with helpers. Record decision (helpers needed → likely Mustache + small custom lambda set).
- [ ] Built-in helpers/lambdas: date formatting, checkbox list, bullet list, table, wikilink `[[...]]`, slugify, transcript embed, audio link, duration.
- [ ] YAML front-matter generation with safe escaping.
- [ ] Create `docs/markdownlint.json` (used by golden tests and `tools/ci/markdownlint.sh`) and `docs/templates.md` (lambda + context reference).
- [ ] Context object documented: extraction JSON + recording metadata (date, duration, speakers, profile, tags, device).
- [ ] Error handling: missing variables render empty with warning; template syntax errors reported with line numbers.

## Acceptance Criteria
- Golden-file tests for each built-in template.
- Malicious input (transcript containing `{{` or YAML `---`) cannot break front-matter or template structure.
