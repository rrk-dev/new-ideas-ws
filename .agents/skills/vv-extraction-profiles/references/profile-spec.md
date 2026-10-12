# VaultVoice Profile Spec — format 1

A profile is YAML (built-in assets, `.vvprofile` bundles) or the equivalent JSON (DB `profiles.definition`).

| Key | Type | Required | Notes |
|---|---|---|---|
| `format` | int | ✅ | Always `1` for this spec. |
| `id` | string | ✅ | `^[a-z][a-z0-9_-]{1,39}$`, globally unique. Built-ins: `meeting`, `warranty`, `engineering`. |
| `version` | int | ✅ | Increment on any change to `schema`, `instructions`, `examples`. |
| `name` | string | ✅ | Display name (localizable key allowed: `@l10n:profile_meeting`). |
| `description` | string | ✅ | One line; used by auto-classification. |
| `icon` | string | – | Material icon name. |
| `tier` | enum | ✅ | `free` \| `pro` \| `enterprise`. |
| `source` | enum | set by app | `builtin` \| `user` \| `enterprise`. Not in bundles. |
| `stt.vocabulary` | string[] | – | Joined into Whisper `initial_prompt` (≤ 200 chars total). |
| `stt.diarization` | bool | – | Default `true` for multi-speaker profiles. |
| `stt.num_speakers` | int \| `auto` | – | Hint for clustering. |
| `classify.keywords` | string[] | – | Fast pre-filter for auto routing. |
| `instructions` | string | ✅ | ≤ 2000 chars. Imperative bullets. |
| `schema` | JSON Schema (subset) | ✅ | Root `type: object`. Every array needs `maxItems`, every string `maxLength`. Supported keywords: `type`, `properties`, `required`, `items`, `enum`, `maxItems`, `minItems`, `maxLength`, `description`, `format: date` (hint only). |
| `map_schema` | JSON Schema | – | Schema for map step of map-reduce; defaults to `schema` with prose fields removed. |
| `reduce` | map field→strategy | – | `union_dedupe` (lists), `first_non_null`, `llm_summarize` (prose), `max`, `min`. Default: lists `union_dedupe`, scalars `first_non_null`, `summary`/`title` `llm_summarize`. |
| `post_process` | list | – | Named Dart post-processors in order: `resolve_relative_dates`, `compute_warranty_expiry`, `normalize_serial`, `map_owner_to_speaker`, `sort_by_timestamp`, `drop_ungrounded_timestamps`. Unknown names = validation error. |
| `examples` | list of {transcript, output} | – | 0–2; `output` must validate against `schema`. |
| `template_id` | string | ✅ | Default template (built-in id or user template). |
| `filename_pattern` | string | – | Overrides template default, e.g. `{{date:YYYY-MM-DD}}-{{slug}}.md` (filename token syntax: `vv-markdown-vault-export`). |
| `routing.default_target` | string | – | Vault target id or `ask`. |
| `review_before_export` | bool | – | Default `false`; APP-05. |
| `consent_confirmation` | enum | ✅ | `required` \| `optional` \| `none`. SEC-07: `required` for multi-person profiles (`meeting`, `engineering`, and whenever profile = Auto); `none` for personal notes / `warranty`. |

## Built-in profile updates
Built-ins are loaded from `app/assets/profiles/*.yaml` on every launch and keyed by `(id, version)`;
they are never stored as editable rows. "Duplicate" creates a user profile with a new id
(`<id>-copy-N`), so built-in updates never overwrite user copies. `extractions.profile_version`
records which version produced each result (re-extract uses the current version).

## Grammar generation
On save/import the app converts `schema` (and `map_schema`) to GBNF via the bridge and caches
it with the profile version. A schema that fails conversion is a validation error.

## Rendering context passed to templates
`{ data: <extraction JSON after post_process>, meta: { recording_id, title, date (YYYY-MM-DD),
time (HH:mm), duration_ms, duration_human, profile_id, profile_name, speakers: [{label, name}],
tags: [], markers: [{t, label, kind}], model_ids: {stt, llm}, app_version, device (model name),
consent_at (ISO-8601 with offset, from recordings.consent_confirmed_at, or null),
has_consent_at }, transcript: { segments: [{t, speaker, text}] } }`

The context normalizer (Dart, one function) guarantees: every schema field present (null when
unknown), empty strings → null, and a `has_<field>` bool for every list and nullable scalar at
every level (e.g. each action item gets `has_owner`, `has_due`, `has_due_iso`, `has_t`).
