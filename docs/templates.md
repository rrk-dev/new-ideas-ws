# Markdown templates

How VaultVoice turns extraction JSON into a note (EXP-01). Decision record:
`docs/adr/ADR-EXP-01-template-engine.md`. Profile side (schema, `has_*` helpers, variable
check): `docs/profile-spec.md`.

Code: `app/lib/features/templates/domain/` — `template_engine.dart` (compile / validate /
render), `template_lambdas.dart`, `markdown_sanitizer.dart`, `note_context.dart` (`meta` and
`transcript` builders), `builtin_templates.dart`, `template_generator.dart`; pipeline adapter
`app/lib/features/templates/data/template_note_renderer.dart`.

## Engine rules
- Mustache via `mustache_template`, `htmlEscapeValues: false`, **`lenient: false`**.
- Partials (`{{> x}}`) and delimiter changes (`{{= =}}`) are not supported.
- Sections / inverted sections only on **lists, bools, maps or null**. A section on a string or
  number throws in strict mode — every nullable scalar `x` has a bool `has_x`
  (`{{#has_x}}…{{x}}…{{/has_x}}`).
- `{{x}}` and `{{{x}}}` behave the same (nothing is HTML-escaped); all values are made safe by
  the context (see "Sanitization").
- Front-matter must start on line 1 — put template comments (`{{! … }}`) at the end.
- Output post-processing: CRLF → LF, trailing whitespace trimmed per line, runs of blank lines
  collapsed (not inside fenced code), exactly one trailing newline.

## Rendering context
```
{ data: <extraction JSON after post_process, normalized against the profile schema>,
  meta: { recording_id, title?, date (YYYY-MM-DD), time (HH:mm), duration_ms, duration_human,
          profile_id, profile_name, speakers: [{label, name?}], tags: [], markers: [{t, label?, kind}],
          model_ids: {stt?, llm?}, app_version, device?, consent_at? (ISO-8601 with offset) },
  transcript: { segments: [{t (hh:mm:ss), speaker?, text}] },
  has_<field>: root alias of every data.has_<field> }
```
Normalizer guarantees (PRF-01 `buildRenderContext`): every schema / post-processor field is
present (null when unknown); empty strings → null; values of the wrong type → null (lists →
`[]`); `has_<field>` bools for every list and scalar at every level (`has_owner`, `has_due_iso`,
`has_t` on each action item, `meta.has_consent_at`, `meta.model_ids.has_stt`, …).
`?` = nullable. Tags never contain a leading `#`.

`summary-only` uses a fixed context: `data` = `{title?, summary?}` (`kSummaryOnlyRootShape`).

## Lambdas
Lambdas live at the context root; a context key with the same name in an inner section scope
wins (Mustache lookup order). The template checker (`template_variables.dart`) knows every
lambda's argument form; the two lists are kept equal by a test.

| Lambda | Form | Output |
|---|---|---|
| `yaml` | `{{#yaml}}…{{/yaml}}` | Renders the section with **raw** values and emits one double-quoted YAML scalar (escapes `"`, `\`, newlines, all C0/C1 controls, U+2028/9, BOM). Empty → `""`. |
| `yaml_list` | `{{#yaml_list}}data.attendees{{/yaml_list}}` | `["a", "b"]` from a list path; anything not a list (incl. a missing path) → `[]`. |
| `wikilink` | `{{#wikilink}}{{data.title}}{{/wikilink}}` | `[[target]]` — raw value, `[ ] \| # ^` removed, whitespace collapsed; empty → nothing. |
| `slug` | `{{#slug}}{{data.title}}{{/slug}}` | lower-case `a-b-c`; letters/digits of any script kept, emoji/punctuation separate; ≤ 60 graphemes. |
| `upper` / `lower` / `trim` | `{{#upper}}…{{/upper}}` | Case / whitespace transform of the rendered (sanitized) section. |
| `date` | `{{#date}}DD.MM.YYYY HH:mm{{/date}}` or `{{#date}}data.due_iso\|DD.MM.YYYY{{/date}}` | Formats `meta.date` + `meta.time` (or the named ISO date/time). Tokens `YYYY YY MM M DD D HH H mm ss`; empty format = `YYYY-MM-DD`; unparseable → empty. |
| `duration` | `{{#duration}}hh:mm:ss{{/duration}}` or `path\|FORMAT` | Formats `meta.duration_ms`: `human` / empty (`1h 05m`, `12m 03s`, `45s`), `hh:mm:ss`, `h:mm:ss`, `mm:ss`, `minutes`. |
| `checkbox` | `{{#checkbox}}{{task}}{{/checkbox}}` | `- [ ] text`, or `- [x] text` when the current item has `done: true` / `checked: true`. |
| `md_table` | `{{#md_table}}data.tradeoffs\|option,pros,cons{{/md_table}}` | GFM table from a list of objects; columns = the given fields or all scalar/list fields of the first item; header = humanized key; lists joined with `; `; `\|` escaped. Empty list → nothing. |
| `bullets` | `{{#bullets}}data.topics{{/bullets}}` | `- item` lines (objects: their scalar values joined with ` — `). Empty → nothing. |
| `transcript_block` | `{{transcript_block}}` | Collapsible Obsidian callout `> [!note]- Transcript` with `> [hh:mm:ss] Speaker: text` lines. No segments → nothing. |
| `audio_link` | `{{audio_link}}` | `![[attachments/<file>]]` when an audio sidecar was exported for this note (render option), else nothing. |
| `code_block` | `{{#code_block}}{{data.x}}{{/code_block}}` | Fenced block of the raw text; the fence is longer than any backtick run inside. |
| `code_lines` | `{{#code_lines}}data.signatures{{/code_lines}}` | Fenced block with one line per item of a list of strings (e.g. API signatures); same fence rule as `code_block`, tagged `text` (markdownlint MD040). Empty list → nothing. |

Argument checks at save time: `yaml_list` / `bullets` / `md_table` paths must name a list,
`md_table` columns must be item fields, `date` / `duration` `path|…` must name a scalar.

## Sanitization
Every string value is an `InlineText`. `{{x}}` prints the inline-safe form:
- any line break (`\r`, `\n`, U+2028/9, U+0085) → one space — a value can never start a new line,
  so it cannot open a heading, list, fence, table or a second front-matter block;
- C0 controls, DEL and bidi overrides (U+202D/E) removed; unpaired surrogates → U+FFFD;
- leading block markers stripped repeatedly: `#` headings, `>`, `-`/`*`/`+` list markers,
  `---`/`***`/`___`/`===`, code fences, `|`; trailing whitespace trimmed;
- `[[`/`]]` → `\[\[`/`\]\]`, `{{` → `{\{`, `<` → `\<`, `` ` `` → `` \` `` (CommonMark
  backslash escapes — Obsidian/Logseq display the original characters).

`yaml`, `yaml_list`, `code_block`, `wikilink`, `slug` and `md_table` use the **raw** value with
their own escaping, so front-matter values round-trip exactly (tested with a YAML parser).

## Errors
- **Syntax** (unclosed tag/section, mismatched close, invalid tag name) →
  `TemplateSyntaxFailure(name, line, column, message)` from `MarkdownTemplateEngine.compile`.
- **Save/import validation** → `MarkdownTemplateEngine.validate(source, shape)`: syntax first,
  then PRF-01's strict variable check; each issue is `name:line:col: message`
  (with "did you mean" hints). EXP-07/PRF-08 must refuse templates with issues.
- **Export** never fails on a template: a strict render error re-renders leniently (missing
  values → empty) and adds a content-free warning (`name:line:col: message`) for the export
  log; an unparseable user template falls back to the profile's built-in / generated template;
  an invalid extraction or unknown profile renders `summary-only`.

## Built-in templates (`app/assets/templates/`)
Read-only assets, never `templates` rows (see ADR-EXP-01 → "Template storage": built-in
templates have no row, and a user template written for a built-in profile keeps
`templates.profile_id = null`).

| id | Profile | Flavor | Notes |
|---|---|---|---|
| `meeting-default` | meeting | Obsidian | front-matter (title, date, time, duration, type, attendees, tags, source, recording_id, consent_at?), Obsidian Tasks `📅` when `due_iso` resolved |
| `meeting-logseq` | meeting | Logseq | page properties (`type::`, `date:: [[YYYY-MM-DD]]` …), outline bullets, `TODO` tasks (EXP-08 exposes it) |
| `meeting-plain` | meeting | plain | no front-matter / wikilinks / callouts (EXP-08) |
| `warranty-default` | warranty | Obsidian | details list, expiry reminder task with `📅 warranty_expiry` |
| `warranty-logseq` | warranty | Logseq | page properties incl. `warranty-expiry:: [[date]]`, details bullets, reminder `TODO … [[date]]` (EXP-08) |
| `warranty-plain` | warranty | plain | details list, no front-matter / wikilinks (EXP-08) |
| `engineering-default` | engineering | Obsidian | API designs, trade-off table (`md_table`), TODO checkboxes |
| `engineering-logseq` | engineering | Logseq | nested outline (API designs, pros/cons per option), `TODO` tasks (EXP-08) |
| `engineering-plain` | engineering | plain | trade-offs as nested lists instead of a table (EXP-08) |
| `summary-only` | any | Obsidian | fallback: `extraction: failed`, summary or notice, `transcript_block` |

Alternate outputs (EXP-08): the recording screen's share action renders the note as Obsidian
(the exported vault note), Logseq or plain via `builtinVariant(profile, flavor)` and hands it to
the OS share sheet (`.md` file or text) or the clipboard. Custom profiles have no Logseq variant;
their plain output is the vault note without front-matter.

Goldens: `app/test/fixtures/markdown/golden/<id>.<full|empty|adversarial>.md`, regenerated with
`(cd app && fvm flutter test --update-goldens test/unit/templates/)` and linted with
`tools/ci/markdownlint.sh` (markdownlint-cli2, config `docs/markdownlint.json`).

## Generic template generator (custom profiles)
`generateTemplate(profile)` builds an Obsidian template from the schema (PRF-07; editable in
EXP-07): standard front-matter; root `title` string → heading (else `meta.title`, else
"<profile name> <date>"); short scalars (strings ≤ 200 chars, enums, numbers, bools, `*_iso`)
→ `- **Label:** value` lines in "Details"; long strings → own section; string lists →
`bullets`; lists of objects with a `task`/`text` field → `checkbox` lines (`owner`, `t`,
`*_iso` 📅, other scalars as ` — Label: v`); other lists of objects → `md_table`; objects → a
section of their scalar fields and string lists. The output always passes the strict check.
It is also used when a profile's `template_id` names no available template.

## Markdownlint
`docs/markdownlint.json` (markdownlint-cli2 0.23.3): defaults plus ATX headings, `-` bullets,
2-space nesting, `_emphasis_`, `**strong**`; disabled: MD013 (line length — values are long),
MD034 (bare URLs from transcripts), MD041 (Logseq notes start with properties);
MD024 siblings only; MD025 ignores the front-matter `title`.

## Filename patterns (EXP-02)
Own token syntax — **not** Mustache. Code: `app/lib/features/export/domain/filename_pattern.dart`,
`filename_sanitizer.dart`, `export_collision.dart`; identity from the DB:
`app/lib/features/export/data/export_identity.dart`.

| Token | Value |
|---|---|
| `{{date:FMT}}` | recording start (local time); FMT from `YYYY MM DD HH mm ss` and `- _ .` / space |
| `{{date}}` | `YYYY-MM-DD` |
| `{{time}}` | `HHmm` |
| `{{title}}` | note title (extraction `title`, else recording title) |
| `{{slug}}` | slugified title, ≤ 60 characters |
| `{{profile}}` | profile id |
| `{{id}}` | first 8 characters of the recording id |

Default: `{{date:YYYY-MM-DD}}-{{profile}}-{{slug}}.md`. A literal `/` creates a sub-folder
(`{{date:YYYY}}/{{date:MM}}/{{slug}}.md`); token values never create folders. `.md` is enforced.
Parse errors (`FilenamePatternFailure`, 1-based column): unknown token, unclosed `{{`, bad date
format, `/` inside a date format, argument on a token without one, leading/trailing `/`, empty /
`.` / `..` segments. A token that renders empty drops one adjacent joiner (`-`, `_`, `.`, space).

**Segment sanitization** (`sanitizeSegment`, every folder and the file name): NFC; remove
`\ / : * ? " < > |` (Windows-synced vaults) and `# ^ [ ]` (Obsidian links); remove C0/C1
controls, DEL, U+2028/9, BOM and bidi controls (an RLO can disguise an extension); line breaks
and tabs → space, whitespace collapsed; leading dots/spaces (hidden files, `.`/`..`) and trailing
dots/spaces removed; Windows device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`, with
or without extension) get `_`; ≤ 255 UTF-8 bytes per segment, truncated before the extension and
never inside a grapheme cluster (emoji ZWJ sequences, flags); empty → `untitled`. Emoji allowed.

**Collisions** (`planExport`; paths compared NFC + case-insensitively, because iOS, Windows and
most Android storage are case-insensitive):

| Situation | `suffix` (default) | `overwrite` | `skip` |
|---|---|---|---|
| Path free | write | write | write |
| Re-export, our note unchanged on disk (`exports.rel_path` exists) | update in place | update in place | update in place |
| Re-export, same content hash | nothing to write | nothing | nothing |
| Re-export, our note deleted by the user | re-create at `rel_path` | same | same |
| Re-export, our note edited by the user (needs a vault read: `currentHash`) | new file (pattern path, else `-N`) | replace it | leave it |
| Path taken by a foreign file or claimed by another recording's export | `-2`, `-3`, … | `-N` (never replaces a foreign file) | leave it |

Stable identity: this recording's `exports` row (any status) fixes the note path for that
target; re-exports update it even when the title or pattern now renders another name.

