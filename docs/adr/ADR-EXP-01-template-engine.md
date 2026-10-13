# ADR-EXP-01 — Markdown template engine: Mustache (`mustache_template`) + custom lambdas

- **Status:** Proposed (library choice backed by host evidence; on-device render timing is
  checked when EXP-05 writes notes on the device-matrix phones — accept then)
- **Date:** 2026-10-13
- **Task:** EXP-01
- **Deciders:** Claude Code (implementer) + human reviewer
- **Supersedes:** —

## Context
The LLM fills JSON; Dart renders Markdown (vv-extraction-profiles). Templates are user-editable
(EXP-07, Pro) and imported in `.vvprofile` bundles (PRF-08), so the engine must be **safe with
untrusted templates and untrusted values**: no code execution, no file/network access, no way
for transcript/LLM text to change the note structure or the YAML front-matter. Constraints from
`AGENTS.md`: offline, pure Dart (no new native code), license allowing commercial
redistribution, no telemetry, testable on the host. PRF-01 already ships a strict
template-variable check (`template_variables.dart`) written against Mustache semantics.

## Options
1. **Mustache via `mustache_template` 2.0.5** (flutter/core-packages, BSD-2) — logic-less,
   spec-compliant, lambdas with `LambdaContext` (`renderString`, `lookup`, `source`), strict
   mode (`lenient: false`) that throws on missing keys, `TemplateException` with line/column.
2. **Handlebars port** (e.g. `handlebars2`/`jinja`-style packages) — block helpers, `if/else`,
   comparisons in the template.
3. **Own mini-language** — full control, but parser/escaping bugs are ours and editors (EXP-07)
   get no ecosystem syntax highlighting.

## Criteria (weights fixed before evaluating)
| Criterion | Weight |
|---|---|
| Safety with untrusted templates/values (no logic, no I/O, strict lookups) | 30% |
| License & maintenance health | 20% |
| Integration effort (fits PRF-01 checker, errors with positions) | 20% |
| Expressiveness for Obsidian/Logseq output (via helpers) | 15% |
| Performance (host now, device in EXP-05) | 10% |
| Testability | 5% |

## Evidence
Environment: macOS host, Apple M3 Pro, Flutter 3.47.7 (FVM), `mustache_template` 2.0.5 source
in the pub cache (read: `renderer.dart`, `lambda_context.dart`, `parser.dart`).

| Item | Mustache (`mustache_template`) | Handlebars ports | Own language |
|---|---|---|---|
| Maintenance | moved to `flutter/core-packages` (Flutter team); 2.0.5 2026-06-09, 2.0.6 2026-09-15 (docs only) | single-maintainer packages, sparse releases | us |
| License | BSD-2-Clause | MIT (varies) | — |
| Imports | only its own `src/` (no `dart:io`, no network) | varies | — |
| Strict mode | `lenient: false`: missing key → `TemplateException` (line, column) | partial | to build |
| Logic in templates | none (sections over lists/bools/maps, lambdas we register) | `if`/comparisons/helpers from template authors | — |
| PRF-01 checker fit | written for exactly these semantics | would need a new checker | new checker |
| Render `meeting-default` (host) | full data 0.47 ms; adversarial data incl. 10k-char fields 3.9 ms; compile 0.34 ms | n/m | n/m |

Behaviour verified by tests (`app/test/unit/templates/`): 18 Markdown goldens (6 built-in
templates × full / all-null / adversarial) lint-clean with markdownlint-cli2 0.23.3 and
`docs/markdownlint.json`; adversarial values (quotes, `---`, `#`, `{{`, wikilinks, HTML
comments, fences, emoji/ZWJ, RTL + bidi overrides, 10k chars) keep the exact line structure and
the front-matter round-trips through a YAML parser.

## Decision
We choose **Mustache with `mustache_template` 2.0.5** (exact pin), constructed as
`Template(source, htmlEscapeValues: false, lenient: false, name: id)`, plus a fixed set of 15
Dart lambdas (`yaml`, `yaml_list`, `wikilink`, `slug`, `upper`, `lower`, `trim`, `date`,
`duration`, `checkbox`, `md_table`, `bullets`, `transcript_block`, `audio_link`, `code_block` —
`docs/templates.md`). Helpers are the only "logic", they are app code, and the strict checker
validates templates at save/import time. Handlebars' extra logic is exactly what we do not want
in user/enterprise templates, and its Dart ports are weakly maintained.

### Safety model (because HTML escaping is off)
- Every string of the render context is wrapped in `InlineText`: `{{x}}` prints a sanitized
  form (newlines collapsed, leading block markers stripped, `[[`/`]]`/`<`/backticks escaped,
  `{{` neutralized, control chars and bidi overrides removed). Values are never re-parsed as
  templates (`mustache_template` writes variables verbatim).
- Quoting/fencing lambdas (`yaml`, `yaml_list`, `code_block`, `wikilink`, `slug`, `md_table`)
  read the **raw** value (a Zone flag switches `InlineText.toString`) and apply their own
  escaping: YAML double-quoted scalars escape every control/line-break character, fences are
  longer than any backtick run, table cells escape `|`.
- `meta.date` (unquoted for Obsidian) must be `YYYY-MM-DD` or it is blanked with a warning.
- Export never loses a note: a strict-mode render error (template that skipped validation)
  re-renders leniently and records `name:line:col: message` (content-free) as a warning.

### Template storage (resolves the PRF-01 FK note)
FND-04 `templates.profile_id` references `profiles.id`, but built-in profiles have no rows.
**Built-in templates are read-only assets** (`app/assets/templates/*.mustache`), never stored as
`templates` rows — like built-in profiles. The binding profile → template is the profile's
`template_id`; `templates.profile_id` is only an optional "authored for" hint on **user**
templates and stays **null** when the profile is a built-in (or is later deleted —
`ON DELETE SET NULL` already). No migration needed. EXP-07 must follow this when saving a
user template for a built-in profile; the user's choice of template per profile goes into
settings/`templateOverrides`, not into the FK.

## Consequences
- Positive: no template logic to sandbox; one checker for save-time validation; line/column
  errors for syntax (`TemplateSyntaxFailure`) and variables (`ProfileIssue`); pure Dart.
- Negative: Mustache cannot test "has any value" across fields; templates need the normalizer's
  `has_*` bools (PRF-01) and verbose title fallbacks. Mitigation: the generic template generator
  writes them for custom profiles.
- Risk: `mustache_template` treats non-Map/List values as "objects" in lenient mode; we only use
  lenient as an export fallback after a strict failure.
- Follow-ups: EXP-05 measures on-device render time with the adversarial context (accept this
  ADR then); EXP-07 uses `MarkdownTemplateEngine.validate` on save; EXP-08 exposes the Logseq /
  plain variants.
