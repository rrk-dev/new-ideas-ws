# PRF-01 — Extraction Profile Data Model & Versioning

**Workstream:** Profiles | **Phase:** 2 (pulled forward: needed by LLM-05 / PRF-09 / GATE-02) | **Size:** M | **Depends on:** FND-04 | **Source:** §3.1.5 (Domain Extraction Profiles / Skills)
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-local-database, vv-llm-inference, vv-markdown-vault-export, vv-testing

## Goal
A single, versioned definition format for "skills" that drives prompt, output schema, template and routing.

## Scope
- [x] Profile definition (YAML/JSON): id, name, version, description, icon, instructions, few-shot examples, output JSON Schema, default template id, default routing target, STT hints (vocabulary, diarization on/off), tier (free/pro/enterprise).
- [x] Built-in profiles shipped as read-only assets; user/enterprise profiles stored in DB.
- [x] Profile versioning: built-ins loaded from assets each launch keyed (id, version); duplicates get new ids; `extractions.profile_version` keeps history (spec → "Built-in profile updates"). The system prompt is fixed app code (PRF-02), not a profile field.
- [x] Validation (schema well-formed, template variables match schema fields).

## Acceptance Criteria
- Profile spec documented in `docs/profile-spec.md` with a full example.
- Validator rejects malformed profiles with actionable errors.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/PRF-01-profile-data-model · **Date:** 2026-10-13
- **Summary:** Spec `docs/profile-spec.md` (adapted from the skill reference: key table with limits, JSON-Schema
  subset, post-processor contract, validation + template-variable rules, render context / normalizer contract,
  storage/versioning/duplicate rules, grammar generation, full `meeting` example). Immutable hand-written model
  `app/lib/features/profiles/domain/profile.dart` (`Profile`, `ProfileStt`, `ProfileExample`, `ProfileTier`,
  `ConsentConfirmation`, `ReduceStrategy`, `ProfileRef` = (id, version), canonical `toJson`, extraction fingerprint),
  schema subset parser + instance validator `profile_schema.dart`, `ProfileValidator` (`profile_validator.dart`:
  every issue at once as `path: message` naming keys/limits only), YAML/JSON decoding `profile_codec.dart`
  (`yaml` 3.1.4, reviewed in `docs/privacy-audit.md`), post-processor contract `post_processors.dart` (known
  names, required fields, added fields `<date>_iso` / `warranty_expiry`), render-context shape + normalizer
  `render_context.dart` (`has_*` helpers at every level + root aliases, shared with the template check),
  strict-Mustache template-variable check `template_variables.dart`, `SchemaGrammarConverter` interface +
  `ProfileGrammarCache` `profile_grammar.dart` (fake: `app/test/fakes/fake_schema_grammar_converter.dart`; no
  converter implemented — LLM-05). Built-ins `app/assets/profiles/{meeting,warranty,engineering}.yaml`
  (`BuiltinProfiles`, keyed (id, version), loaded each launch, never stored). `ProfileRegistry`
  (`app/lib/features/profiles/data/profile_registry.dart` + Riverpod providers) persists user/enterprise profiles
  in the FND-04 `profiles` table (no migration needed: id PK + version + source + definition JSON), id uniqueness
  across sources, auto version bump on extraction-content change, read-only built-in/managed profiles, managed
  no-downgrade, duplicate to `<id>-copy-N`, grammar generation on save (rejection = validation error).
  `ProfileValidationFailure` / `ProfileReadOnlyFailure` added to `core/errors/failure.dart`.
- **Acceptance evidence:**
  - AC1: ✅ artifact: docs/profile-spec.md; test: [PRF-01/AC1]
  - AC2: ✅ test: [PRF-01/AC2]
- **Decisions:** no ADR (no technology choice beyond the spec). Engineering choices recorded here: hand-written
  immutable classes instead of freezed (the profile is a validated JSON-shaped tree; codegen would add a dependency
  without removing the custom validation path); `enum` strings need no `maxLength` (bounded by the enum); arrays
  cannot be nullable; `stt.diarization: true` forbids `consent_confirmation: none` (SEC-07); `has_<field>` emitted
  for every scalar (superset of the spec rule) and aliased at the context root (the built-in meeting template uses
  `{{#has_attendees}}`); grammar cache in memory until LLM-05 persists it.
  PRODUCT-DECISION: `warranty` and `engineering` tiers are placeholders (`pro`, marked in the YAML) pending LIC-01.
- **Follow-ups:** see below.

## Follow-ups
- LLM-05: implement `SchemaGrammarConverter` over `vv_json_schema_to_gbnf` and override
  `schemaGrammarConverterProvider`; persist `ProfileGrammarCache` (new migration step, e.g. `profile_grammars`
  table keyed (id, version, schema hash) so built-ins are covered too); reuse `validateInstance` for model output.
- EXP-01: build the render context with `buildRenderContext` (same shape as the validator) and keep
  `kTemplateLambdas` in sync with the implemented lambdas. Note the FND-04 `templates.profile_id` FK references
  `profiles.id`, but built-ins have no rows — built-in templates must keep `profile_id` null (or EXP-01 changes the FK).
- PRF-03/PRF-04: implement the post-processors against the contract in `post_processors.dart`
  (`resolve_relative_dates` adds `<field>_iso`; `compute_warranty_expiry` reads `purchase_date_iso`).
- LIC-01: decide Free vs Pro for `warranty` and `engineering` (PRODUCT-DECISION in the YAML).
- PRF-02 prep (proposal, not implemented): build the prompt from `Profile` only — `instructions`, field
  descriptions generated by walking `ObjectSchema` (path, type, `maxLength`/`maxItems`, `enum`, nullable →
  "or null"), examples as user/assistant pairs (`ProfileExample.output` serialized with canonical key order), and
  `meta` fields from the same `kMetaShape`; snapshot the three built-ins in `app/test/golden_prompts/`; trim
  examples first via `Profile.examples` length; neutralize `</transcript>` in transcript text.

