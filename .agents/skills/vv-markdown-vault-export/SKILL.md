---
name: vv-markdown-vault-export
description: "Markdown output and vault writing: Mustache templates with safe YAML front-matter, Obsidian/Logseq conventions, filename patterns, Android SAF and iOS security-scoped bookmarks, routing rules, export outbox/retry, template editor, share sheet."
---

# Markdown Rendering & Vault Export

Platform details: `references/android-saf.md`, `references/ios-bookmarks.md`.
Default template: `assets/meeting-default.mustache`.

## Template engine (EXP-01)
- Library: `mustache_template` (logic-less, supports lambdas). Record in ADR (Mustache vs
  Handlebars) — Handlebars ports for Dart are thinly maintained.
- Construct `Template(source, htmlEscapeValues: false, lenient: false, name: id)` — we emit
  Markdown, not HTML. Because escaping is off, **all safety is done by lambdas/pre-processing**:
  - Front-matter values: always through `{{#yaml}}…{{/yaml}}` → emits a double-quoted YAML
    string (JSON-escape: `\"`, `\\`, `\n`). Lists → `{{#yaml_list}}` → `["a", "b"]`.
  - Inline values from the LLM/transcript: pre-sanitized in the render context: collapse
    newlines to spaces, strip leading `#`, `>`, `-`, `---`, and trailing whitespace; escape
    `[[`/`]]` unless intended wikilinks; neutralize `{{` (render context values are never
    re-parsed as templates, but users may paste them into custom templates).
- Lambdas (register in one place, document in `docs/templates.md`):
  `yaml` (renders section, then quotes), `yaml_list` (section text is a variable path; resolve it
  with `LambdaContext.lookup`; treat any non-`Iterable` result — including the missing-property
  sentinel — as empty and emit `[]`), `wikilink` (`[[x]]`), `slug`, `upper`, `lower`, `trim`, `date` (format arg
  via section text: `{{#date}}YYYY-MM-DD{{/date}}` formats `meta.date`), `duration`, `checkbox`
  (renders `- [ ] text` / `- [x]`), `md_table` (list of objects → GFM table), `bullets` (list →
  `- ` lines), `transcript_block` (renders `transcript.segments` as `[hh:mm:ss] Speaker: text`
  lines inside a collapsible callout), `audio_link` (`![[attachments/<file>.m4a]]` when an audio
  sidecar was exported, else empty), `code_block` (fenced block whose fence is longer than any
  backtick run inside the text).
- Context = profile-spec "Rendering context" (`data`, `meta`, `transcript`). Post-processor
  `resolve_relative_dates` adds `<field>_iso` siblings (e.g. `due_iso`) when a date resolves.
  Any value that YAML could mis-type (times like `14:05`, `yes/no`, numbers-as-text) must go
  through `yaml`. Build the context by **normalizing against the profile schema**:
  every optional field is *present* with value `null` (never absent — absent keys throw with
  `lenient: false`), empty strings → `null`, every `has_<field>` helper is a `bool` (top-level
  lists and per-item scalars, e.g. `has_owner`, `has_due`, `has_due_iso`, `has_t` on each action
  item, `meta.has_consent_at`). Use `{{#x}}` / `{{^x}}` **only on lists, bools, maps or null** —
  with `lenient: false` a section *or* inverted section on a String/number throws
  `TemplateException`. Nullable scalars are always rendered via `{{#has_x}}…{{x}}…{{/has_x}}`.
  Golden tests must include a case where every optional field is non-null and one where all are null.
- Errors: syntax error → show line/column (catch `TemplateException`). Missing variable in
  lenient=false → error at **validation time** (profile/template save), not at export time:
  at export, render with a sanitized fallback and a warning in the export log.

## Obsidian / Logseq conventions
- Front-matter keys: `title`, `date` (ISO `YYYY-MM-DD`), `time`, `duration`, `type` (profile id),
  `tags` (list, no `#`), `attendees` (list), `source: vaultvoice`, `recording_id`, `consent_at?`.
- Tasks: `- [ ] Task text (@Owner) 📅 YYYY-MM-DD` — the 📅 date only when resolved to an absolute
  date (Obsidian Tasks plugin format); otherwise `due: next Friday` in text.
- Timestamps as plain `[00:12:05]`; optional link to audio attachment `![[file.m4a]]` if exported.
- Logseq variant (EXP-08): first block properties `type:: meeting`, `date:: [[YYYY-MM-DD]]`,
  everything as outline bullets (`- `) with 2-space nesting; tasks `- TODO text`.
- Validate output with markdownlint config `docs/markdownlint.json` in golden tests.

## Filename patterns (EXP-02) — own token syntax, not Mustache
Tokens: `{{date:FMT}}` (FMT: `YYYY`,`MM`,`DD`,`HH`,`mm`,`ss`), `{{time}}` (=`HHmm`), `{{title}}`,
`{{slug}}` (slugified title, ≤ 60 chars), `{{profile}}`, `{{id}}` (first 8 of recording id).
`/` creates sub-folders. Default: `{{date:YYYY-MM-DD}}-{{profile}}-{{slug}}.md`.
Sanitize each path segment: remove `\ / : * ? " < > |` and control chars, collapse spaces,
trim trailing dots/spaces, reject `.`/`..`, avoid Windows reserved names (`CON`, `NUL`, `COM1`…),
NFC-normalize, emoji allowed but counted in UTF-8 bytes (never split a grapheme when truncating), ≤ 255 **bytes** UTF-8 per segment (truncate before extension). Empty → `untitled`.
Collisions: `suffix` (`-2`, `-3`…), `overwrite` (only when the existing file is the one we wrote for
this recording — check `exports.rel_path` + `content_hash`), `skip`.

## Vault targets & routing (EXP-05)
- `VaultWriter` interface: `list`, `exists(relPath)`, `write(relPath, bytes, {overwrite})`,
  `mkdirs(relPath)`, `delete(relPath)` (APP-02 "also delete exported note"),
  `checkAccess() → ok | revoked | unavailable`.
  Impls: `SafVaultWriter` (Android), `BookmarkVaultWriter` (iOS), `AppLocalVaultWriter`.
- Rules (`routing_rules`, ordered by priority): match on `profile_id`, `tags_any`,
  `keywords_any` (in title/summary), `speakers_any`; action → target + sub_path + filename
  pattern. Mode per rule: `stop` (first match) or `continue` (multi-target). No match → profile
  default target → the **default vault target** (setting `export.default_target` = the folder
  the user last picked in onboarding/Settings or marked "Make default"; if unset, deleted or
  inactive: the newest active target). Settings shows the same resolved target as "Default".
- Free tier: 1 target + no rules; Pro: unlimited (`EntitlementService`).
- Optional sidecars per target: transcript note (`<name>.transcript.md`), audio copy into
  `attachments/` (m4a). Off by default (size, privacy).

## Outbox & idempotency (EXP-06)
1. Render → save `rendered/<recording_id>.md` + content hash (always succeeds locally).
2. `exports` row per target `pending` → WriteStep tries → `written` or `failed(reason)`.
3. Retry on: revoked permission (after user re-grants), iCloud unavailable, SD removed, disk full.
4. Re-export same recording ⇒ update the same `rel_path` (stable identity), never a duplicate.
5. Atomic write: write `.<name>.tmp` then rename (iOS file coordinator / SAF: write to new
   document then delete old if rename unsupported — see references).

## Template editor (EXP-07, Pro)
Code field (`re_editor` preferred; `flutter_code_editor` is less actively maintained) with Mustache
highlighting, autocomplete of `data.*` from profile schema + `meta.*`; live preview debounced
200 ms using sample data from profile examples or a chosen recording; toggle raw / rendered
(`flutter_markdown_plus` or maintained successor). Reset to default, duplicate.

## Built-in fallback & generic templates
- `summary-only` (used when extraction JSON is invalid — LLM-05): front-matter + title + free-text
  summary + `transcript_block`; front-matter adds `extraction: failed`.
- **Generic template generator** (custom profiles, PRF-07): from the profile schema produce a
  template — scalars as `**Label:** {{value}}` (guarded by `has_`), string lists via `bullets`,
  checkbox lists via `checkbox`, arrays of objects via `md_table`; front-matter = standard keys.
  The user can then edit it in the template editor (EXP-07).

## Share & alternate outputs (EXP-08)
`share_plus` for `.md` file or text; clipboard copy; Logseq and plain variants are just
alternate built-in templates.

## Verification
- Golden tests per built-in template × (Obsidian, Logseq, plain) with adversarial data
  (quotes, `---`, `#`, `{{`, emoji, RTL text, 10k-char fields).
- Front-matter round-trip: parse rendered output with a YAML parser, assert values equal input
  (`date` is intentionally unquoted for Obsidian and parses as a date — compare as a date).
- Device: notes appear in Obsidian (Android local vault; iOS local + iCloud vault) without
  manual refresh; permission revoke → re-grant → exactly one note.
