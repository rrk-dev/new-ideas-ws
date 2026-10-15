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

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ · analyze ✅ · tests ✅ (780 passed, 29 skipped; coverage not re-measured locally, CI test job gates ≥80% and is green) · native smoke n/a (no native/bridge change) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51 of ci, commit 67b6fcf, completed successfully; run 50 also succeeded)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[PRF-01/AC1]` inside the full suite; `profile_spec_doc_test.dart` parses the single YAML example in `docs/profile-spec.md`, requires it to equal the shipped meeting built-in, and requires every definition key, schema keyword, post-processor, reduce strategy and consent value to appear in the doc
  - AC2: ✅ re-ran `[PRF-01/AC2]`; `profile_validator_test.dart` asserts exact `path: message` failures (missing maxLength/maxItems, unknown keywords, examples, consent/SEC-07, every issue at once, messages that do not echo field values); registry tests refuse a grammar-converter rejection and a multi-issue save with nothing stored. Mutation: changed the maxLength message in `profile_schema.dart` to "can loop"; the tagged test failed (`Expected: …cannot loop`); restored with `git checkout`
- **Adversarial checks:** empty/whitespace instructions, 2001-char instructions, duplicate ids, unknown keys, enum duplicates, nesting deeper than 6, YAML/JSON syntax errors, and a field value `SECRET-PROJECT-NAME` that must not appear in the issue text. Built-ins stay out of the `profiles` table; user/enterprise rows version on extraction-fingerprint change. No transcript/LLM content logging and no new network host in this feature.
- **Skill/rule compliance:** profile spec, validator, built-in assets and registry match `vv-extraction-profiles` / `vv-local-database` (existing `profiles` table, no migration). Hand-written model instead of freezed is recorded in Completion Notes. No credentials, certificates, or banned crypto.
- **Issues found:** none
- **Pending for done:** dependency FND-04 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
