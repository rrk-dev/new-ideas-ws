# VaultVoice Profile Spec — format 1

An **extraction profile** (the app's user-facing "skill") is one versioned definition that drives
STT hints, the LLM prompt and output schema, Dart post-processing, the Markdown template and
routing. **The LLM fills JSON; Dart renders Markdown.** Anything computable deterministically
(dates, expiry, sorting, dedupe) is done by post-processors, never asked of the model.

- Code: `app/lib/features/profiles/domain/` (model `profile.dart`, schema subset
  `profile_schema.dart`, `ProfileValidator`, post-processor contract `post_processors.dart`,
  render-context shape + normalizer `render_context.dart`, template check
  `template_variables.dart`), storage `app/lib/features/profiles/data/profile_registry.dart`.
- Built-ins: `app/assets/profiles/{meeting,warranty,engineering}.yaml`.
- Owner task: PRF-01. Tests: `app/test/unit/profiles/`, `app/test/db/repositories/profile_registry_test.dart`.

A profile is YAML (built-in assets, `.vvprofile` bundles) or the equivalent JSON (DB
`profiles.definition`). Both decode to the same map and go through the same validator.

## Keys

| Key | Type | Required | Rules |
|---|---|---|---|
| `format` | int | ✅ | Always `1`. |
| `id` | string | ✅ | `^[a-z][a-z0-9_-]{1,39}$`, unique across built-in, user and enterprise profiles. Built-ins: `meeting`, `warranty`, `engineering`. |
| `version` | int ≥ 1 | ✅ | Increment on any change to `schema`, `map_schema`, `instructions`, `examples`, `reduce`, `post_process` (the *extraction fingerprint*). The app bumps it automatically when a user edit changes the fingerprint without a bump. |
| `name` | string | ✅ | ≤ 60 chars. Display name (localizable key allowed: `@l10n:profile_meeting`). |
| `description` | string | ✅ | One line, ≤ 200 chars; used by auto-classification (PRF-06). |
| `icon` | string | – | Material icon name (`^[a-z][a-z0-9_]{0,63}$`). |
| `tier` | enum | ✅ | `free` \| `pro` \| `enterprise` (gated by LIC-01). |
| `source` | enum | set by app | `builtin` \| `user` \| `enterprise`. **Never in a definition** — a `source` key is a validation error. Stored in the `profiles.source` column. |
| `stt.vocabulary` | string[] | – | Joined with `, ` into Whisper `initial_prompt`; ≤ 200 chars total. |
| `stt.diarization` | bool | – | `true` for multi-speaker profiles. |
| `stt.num_speakers` | int 1–10 \| `auto` | – | Clustering hint; default `auto`. |
| `classify.keywords` | string[] | – | ≤ 30 entries, each ≤ 40 chars. Fast pre-filter for auto routing. |
| `instructions` | string | ✅ | ≤ 2000 chars. Imperative bullets, small-model friendly. The system prompt itself is fixed app code (PRF-02), not a profile field. |
| `schema` | JSON Schema (subset) | ✅ | Root `type: object`, not nullable. See "Schema subset". |
| `map_schema` | JSON Schema (subset) | – | Schema for the map step of map-reduce (LLM-06); same rules as `schema`. |
| `reduce` | map field → strategy | – | Top-level fields only. `union_dedupe` (lists), `first_non_null` (scalars/objects), `llm_summarize` (free-text strings), `max`, `min` (numbers/strings). Defaults: lists `union_dedupe`, `summary`/`title` `llm_summarize`, other scalars `first_non_null`. |
| `post_process` | list | – | Named Dart post-processors, in order, each at most once (see "Post-processors"). Unknown names are validation errors. |
| `examples` | list of `{transcript, output}` | – | 0–2. `transcript` non-empty, ≤ 4000 chars, synthetic (no real people). `output` must validate against `schema`. |
| `template_id` | string | ✅ | `^[a-z][a-z0-9_-]{1,63}$`; built-in or user template. |
| `filename_pattern` | string | – | Ends in `.md`, relative, no `..`. Tokens: `{{date:FMT}}` (FMT from `YYYY MM DD HH mm ss` and `- _ .`), `{{time}}`, `{{title}}`, `{{slug}}`, `{{profile}}`, `{{id}}` (`vv-markdown-vault-export`). |
| `routing.default_target` | string | – | Vault target id or `ask`. |
| `review_before_export` | bool | – | Default `false` (APP-05). |
| `consent_confirmation` | enum | ✅ | `required` \| `optional` \| `none` (SEC-07). `required` for multi-person profiles (`meeting`, `engineering`, Auto); `none` for personal notes / `warranty`. A profile with `stt.diarization: true` may not use `none`. |

Any other top-level key (or unknown key under `stt`, `classify`, `routing`, an example) is a
validation error, so typos never pass silently.

## Schema subset

Everything here converts to a **bounded** GBNF grammar (`vv-llm-inference` → Constrained output).

- Keywords: `type`, `properties`, `required`, `items`, `enum`, `maxItems`, `minItems`,
  `maxLength`, `description`, `format` (`date` only; a prompt hint — dates are resolved in Dart).
  Anything else (`$ref`, `oneOf`, `pattern`, `additionalProperties`, `minimum`, …) is rejected.
- Types: `object`, `array`, `string`, `integer`, `number`, `boolean`. Nullable via
  `type: [<t>, "null"]` (exactly one non-null type; no unions). Arrays are never nullable — an
  empty list means "nothing found".
- **Every array has `maxItems`** (1–200); `minItems` ≤ `maxItems`.
- **Every string has `maxLength`** (1–4000), except a string with `enum`, which is already
  bounded. `enum` values are unique non-empty strings (≤ 50) or numbers.
- Objects need a non-empty `properties` (≤ 40); `required` ⊆ `properties`.
- Field names: `^[a-z][a-z0-9_]{0,39}$` and must not start with `has_` (reserved for helpers).
- Nesting: at most 6 array levels. `description` ≤ 300 chars (it goes into the prompt).
- The validator keeps declaration order; the canonical JSON (`Profile.toJson`) is what is stored,
  hashed and passed to the grammar converter.

## Post-processors

Contract in `post_processors.dart`; implementations land with the profile tasks (PRF-03/04) and
LLM-05. A processor whose required fields are missing is a validation error.

| Name | Needs | Adds to the extraction JSON |
|---|---|---|
| `resolve_relative_dates` | a date field: a string named `date`, `due`, `*_date`, or with `format: date` | nullable `<field>_iso` (YYYY-MM-DD) next to every date field, e.g. `due_iso`, `purchase_date_iso` |
| `compute_warranty_expiry` | root `purchase_date` (string) and `warranty_period {value: number, unit: string}`; `warranty_expiry` must **not** be in the schema | root nullable `warranty_expiry` |
| `normalize_serial` | root string `serial_number` | – (uppercase, strip spaces, spelled letters "S as in Sam" → S) |
| `map_owner_to_speaker` | a string field `owner` | – |
| `sort_by_timestamp` | a list of objects with a string field `t` | – |
| `drop_ungrounded_timestamps` | a string field `t` | – (nulls `t` values not present in the transcript) |

A schema field that collides with an added field (e.g. a declared `due_iso`) is an error.

## Validation (`ProfileValidator`)

`ProfileValidator.validate(map, source:, takenIds:)` returns a `Profile` **or** every issue
found (never just the first). Each issue is `path: message`, where the path locates the key
(`schema.action_items[].owner`, `examples[0].output.title`, `post_process[2]`,
`template:12:5`) and the message says what to change, e.g.:

```text
schema.action_items[].owner: missing maxLength — every string needs one (e.g. maxLength: 200) so the grammar cannot loop
instructions: is 2140 chars, max 2000; shorten to imperative bullets
examples[0].output.topics: required field is missing
post_process[3]: unknown post-processor "translate" (known: resolve_relative_dates, …)
template:3:1: unknown variable "data.atendees" — not a profile schema field, post-processor field or render metadata (did you mean data.attendees?)
```

Messages name keys and limits only — never field values — so they are safe to log at INFO.
YAML syntax errors are reported as `yaml: invalid YAML at line L, column C`.

Checks: everything in "Keys", "Schema subset" and "Post-processors" above; `id` unique
(`takenIds` = built-in ids + stored ids other than the profile being updated); examples validate
against `schema` (types, `required`, no undeclared fields, `maxItems`/`minItems`, `maxLength`,
`enum`); and, on profile/template save, **template variables ⊆ render context**
(`validateTemplate`, next section). Grammar conversion is the last step on save (see "Grammar
generation"); its failure is also a validation error.

## Template variable check

`ProfileValidator.validateTemplate(profile, source)` checks every Mustache tag against the render
context shape below, with `mustache_template` `lenient: false` semantics, so a template that
validates cannot hit a missing key at export time:

- Unknown variable/section names (with `line:column` and a "did you mean" hint).
- A section or inverted section on a string/number (throws in strict mode) → use
  `{{#has_x}}…{{/has_x}}`.
- A list or object printed as a variable (`{{data.attendees}}`) → iterate it or use a lambda.
- Unbalanced/unclosed sections; partials (`{{> x}}`) and delimiter changes are unsupported.
- Name resolution follows the Mustache spec: the first segment of a dotted name is looked up from
  the innermost section outwards, the rest strictly from there; lambdas resolve last.
- Lambdas (`vv-markdown-vault-export`; EXP-01 implements them): content lambdas
  (`yaml`, `wikilink`, `slug`, `upper`, `lower`, `trim`, `checkbox`, `code_block` — inner tags
  are checked), text-argument lambdas (`date`, `duration`; an optional `path|FORMAT` path must
  be a scalar), path-argument lambdas (`yaml_list`, `bullets`, `md_table` — the text before an
  optional `|args` must name a list; `md_table` columns must be item fields), and variable
  lambdas (`transcript_block`, `audio_link`). Reference: `docs/templates.md`.

## Rendering context passed to templates

```
{ data: <extraction JSON after post_process, normalized>,
  meta: { recording_id, title?, date (YYYY-MM-DD), time (HH:mm), duration_ms, duration_human,
          profile_id, profile_name, speakers: [{label, name?}], tags: [], markers: [{t, label?, kind}],
          model_ids: {stt?, llm?}, app_version, device?, consent_at? (ISO-8601 with offset, from
          recordings.consent_confirmed_at) },
  transcript: { segments: [{t, speaker?, text}] },
  has_<field> … }                                   ← root alias of every top-level data helper
```

The **context normalizer** (`buildRenderContext` / `normalizeToShape`, one shape shared with the
template check) guarantees, at every level of `data`, `meta` and `transcript`:

- every schema field and every post-processor field is present (null when unknown; lists `[]`);
- empty / whitespace-only strings → null; values of the wrong type → null (lists → `[]`); null
  entries are dropped from lists;
- a `has_<field>` bool for every list (non-empty), every scalar except non-nullable booleans, and
  every nullable object (non-null) — a superset of "every list and nullable scalar", because a
  non-nullable string can still arrive empty. Each action item gets `has_task`, `has_owner`,
  `has_due`, `has_due_iso`, `has_t`; `meta` gets `has_consent_at`, `has_tags`, …;
- the top-level data helpers are also at the root (`{{#has_attendees}}`), as the built-in
  meeting template uses them.

## Storage, built-in updates and duplicates

- **Built-ins** are loaded from `app/assets/profiles/*.yaml` on every launch (list in
  `kBuiltinProfileAssets`, a test keeps it equal to the folder) and keyed by `(id, version)`
  (`ProfileRef`); they are never stored as editable rows. An invalid built-in fails loudly
  (`BuiltinProfileException`) and is caught by the asset tests.
- **User and enterprise profiles** are rows in the FND-04 `profiles` table: `id` (PK),
  `version`, `source`, `definition` (canonical JSON without `source`), `updated_at`. Only the
  current version is stored; `extractions.profile_version` records which version produced each
  result (re-extract uses the current version). No schema migration was needed.
- **Enterprise** (managed, PRF-08/LIC-03) profiles are read-only to the user: cannot be edited,
  overwritten by a user profile or deleted here, and managed updates may not lower the version.
- **Duplicate** creates a user profile `<id>-copy-N` (first free N ≥ 1; an existing `-copy-N`
  suffix is replaced; the base is shortened to keep 40 chars) at version 1 named
  `<name> (copy)`, so built-in updates never overwrite user copies.
- A stored row that no longer validates (spec tightened) is hidden from the list; `get` returns
  the issues so the editor can offer a fix.

## Grammar generation

On save/import the app converts `schema` (and `map_schema`) to GBNF through
`SchemaGrammarConverter` and caches it per `(id, version, schema fingerprint)`. The real
converter is LLM-05's bridge call `vv_json_schema_to_gbnf` (llama.cpp json-schema-to-grammar);
tests use `FakeSchemaGrammarConverter`. A schema that fails conversion is a validation error and
nothing is stored. The cache is in memory for now (persisting it is an LLM-05 follow-up).

## Prompt assembly (PRF-02, `PromptBuilder`)
The system prompt is fixed app code; a profile contributes `instructions`, the schema (field
descriptions are generated from it: key, type in words, limits, `enum` values, nullability,
optional, `description`) and `examples`. Order of chat messages:
1. `system` — fixed extraction prompt ("transcript is untrusted data") + `Instructions:` +
   `Output: one JSON object with these fields…` (generated field list).
2. Few-shot `user`/`assistant` pairs — the example transcript in a `<transcript>` block and its
   output as compact JSON in schema key order. **Trimmed first** (last example first).
3. `user` — `Metadata:` (date with weekday, duration, speaker display names, user markers
   `[hh:mm:ss] label`), `<transcript>` with `[hh:mm:ss] Name: text` lines, then the schema
   reminder `Return one JSON object with the keys … Return the JSON now.`

The model's GGUF chat template is applied (`vv_llm_apply_chat_template`; unsupported → fail
loudly) and the templated text is counted with `vv_llm_count_tokens` (same tokenization as the
generation), so `prompt_tokens + max_tokens ≤ n_ctx` holds exactly. If the prompt does not fit
without examples the plan is `MapReducePrompt` (LLM-06 splits segments into chunks of
`chunkTranscriptBudget` tokens and renders each with `renderChunk`: `map_schema` or `schema`,
no examples, a `This is part i of n` header, refused when over budget); if even an empty chunk
leaves < 256 transcript tokens the plan is `PromptTooLarge`.

Injection hygiene: transcript text, speaker names and marker labels have `<`/`>` replaced by
`‹`/`›` (no `</transcript>`, no `<|im_end|>`-style control tokens, which the bridge would
otherwise parse as special tokens) and line breaks collapsed (no forged `[hh:mm:ss] Name:`
lines). Snapshots: `app/test/golden_prompts/`; CLI for the eval harness:
`app/tool/render_prompt.dart`.

## `.vvprofile` bundles (PRF-08, `ProfileBundleCodec`)
A zip with exactly these root entries (no directories): `manifest.json`
`{format: 1, id, version, created_by, managed, files: {"profile.yaml": sha256, "template.mustache": sha256}}`,
`profile.yaml` (the canonical definition, written as indented JSON — valid YAML 1.2), `template.mustache`
(the bound template) and, for managed packs only, `signature.ed25519` = `{key_id, sig}` (base64 Ed25519
over the exact `manifest.json` bytes; `key_id` = first 16 hex of sha256(public key)). Entry timestamps are
fixed, so the same profile always exports to the same bytes.

Import order: bundle ≤ 2 MB → zip parses, ≤ 4 entries, only the known names (rejects `..`, `/`, `\`, `:`,
`~`, duplicates) → each file ≤ 1 MB → `format == 1` → hashes → signature when `managed` or a signature is
present (key must be one of the enterprise license's org keys, LIC-03) → profile validation (managed →
`enterprise`, else `user`) → `id`/`version` match the manifest → template validation against the
profile. Conflicts: built-in id or an id of another source → refused; same version → already installed;
higher → update offered; lower → refused. Custom imports need `Feature.customProfiles`, managed packs
`Feature.managedProfiles`. File type: extension `vvprofile`, UTI `com.vaultvoice.profile`, MIME
`application/vnd.vaultvoice.profile+zip`.

## Full example (built-in `meeting`, version 1)

This block is validated by `[PRF-01/AC1]` in `app/test/unit/profiles/profile_spec_doc_test.dart`
and must stay identical (as data) to `app/assets/profiles/meeting.yaml`.

```yaml
format: 1
id: meeting
version: 1
name: Meeting Action Items
description: In-person meetings with decisions, action items, owners and open questions.
icon: groups
tier: free
stt:
  vocabulary: []
  diarization: true
  num_speakers: auto
classify:
  keywords: [meeting, agenda, action item, follow up, next steps, standup, sync]
instructions: |
  - Extract only what is explicitly said in the transcript. Never invent people, tasks or dates.
  - attendees: names of people who speak or are clearly present. Use speaker names as given.
  - decisions: things the group agreed on, one short sentence each.
  - action_items: concrete tasks. owner = the person responsible if stated, else null.
    due = the due date exactly as spoken (e.g. "next Friday"), else null.
    t = the [hh:mm:ss] timestamp of the line where the task was stated.
  - open_questions: questions raised but not answered.
  - summary: 2-4 sentences, neutral tone.
  - If a field has nothing, return an empty list or null.
schema:
  type: object
  required: [title, summary, attendees, decisions, action_items, open_questions, topics]
  properties:
    title: {type: string, maxLength: 80, description: Short meeting title}
    summary: {type: string, maxLength: 600, description: 2-4 sentence summary}
    attendees:
      type: array
      maxItems: 20
      items: {type: string, maxLength: 60}
    decisions:
      type: array
      maxItems: 30
      items: {type: string, maxLength: 200}
    action_items:
      type: array
      maxItems: 50
      items:
        type: object
        required: [task, owner, due, t]
        properties:
          task: {type: string, maxLength: 200}
          owner: {type: [string, "null"], maxLength: 60}
          due: {type: [string, "null"], maxLength: 40}
          t: {type: [string, "null"], maxLength: 8, description: "hh:mm:ss timestamp of the source line"}
    open_questions:
      type: array
      maxItems: 20
      items: {type: string, maxLength: 200}
    topics:
      type: array
      maxItems: 10
      items: {type: string, maxLength: 40}
reduce:
  summary: llm_summarize
  title: llm_summarize
  attendees: union_dedupe
  decisions: union_dedupe
  action_items: union_dedupe
  open_questions: union_dedupe
  topics: union_dedupe
post_process: [map_owner_to_speaker, resolve_relative_dates, drop_ungrounded_timestamps, sort_by_timestamp]
examples:
  - transcript: |
      [00:00:05] Priya: Let's lock the API version today. We go with v2.
      [00:00:12] Sam: Fine. I'll update the client SDK by Friday.
      [00:00:20] Priya: Still unclear who owns the migration guide.
    output:
      title: API version decision
      summary: The team agreed to standardize on API v2. Sam will update the client SDK. Ownership of the migration guide is still open.
      attendees: [Priya, Sam]
      decisions: [Use API v2]
      action_items:
        - {task: Update the client SDK to API v2, owner: Sam, due: Friday, t: "00:00:12"}
      open_questions: ["Who owns the migration guide?"]
      topics: [API versioning]
template_id: meeting-default
filename_pattern: "{{date:YYYY-MM-DD}}-Meeting-{{slug}}.md"
routing:
  default_target: ask
review_before_export: false
consent_confirmation: required
```

Its default template (`vv-markdown-vault-export/assets/meeting-default.mustache`) passes the
template variable check against this profile (`due_iso` comes from `resolve_relative_dates`).

The drafts `warranty.yaml` and `engineering.yaml` follow the field tables in
`vv-extraction-profiles`; PRF-04/PRF-05 tune their instructions and examples against the eval
harness (PRF-09) and bump `version`. Their `tier` is a PRODUCT-DECISION pending LIC-01.
