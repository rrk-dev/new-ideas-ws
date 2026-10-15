# PRF-07 — Custom Profile Editor (Pro)

**Workstream:** Profiles | **Phase:** 3 | **Size:** L | **Depends on:** PRF-01, PRF-02, LIC-01 | **Source:** §7 (Unlimited domain extraction profiles — Pro)
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-flutter-architecture, vv-licensing-iap, vv-markdown-vault-export, vv-testing

## Goal
Pro users create their own extraction profiles (e.g., Sprint Planning, Legal Intake, Patient Notes) without writing JSON Schema by hand.

## Scope
- [x] Create from scratch or duplicate a built-in.
- [x] Field builder UI (name, type: text/list/date/number/checkbox list/table, description) → generates JSON Schema.
- [x] Instruction text editor + optional examples.
- [x] "Test on a recording" button: run against a selected transcript and show JSON + rendered Markdown.
- [x] Generate a default template with the generic template generator (`vv-markdown-vault-export`), editable in EXP-07; bind it (EXP-01) and the routing target (EXP-05).
- [x] Free tier limited to built-in profiles (gate via LIC-01).

## Acceptance Criteria
- A user can build a 5-field custom profile and get a correct export without touching raw JSON.
- Profiles survive app updates and DB migrations.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/PRF-07-custom-profile-editor (stacked on task/PRF-02-system-prompt-builder — uses
  the prompt builder for the preview) · **Date:** 2026-10-14
- **Summary:** Field builder domain `app/lib/features/profiles/domain/profile_draft.dart` (`FieldKind` text / long text /
  list of text / date / number / yes-no / checkbox list / table{columns} / advanced; each maps to one bounded schema node;
  `ProfileDraft.toDefinition()` → format-1 definition validated by PRF-01; `fromProfile` reads schemas back, unsupported
  shapes stay as read-only "advanced" fields; plain-text example values → schema-valid outputs; inline issues).
  `CustomProfileService` + `ProfilePreview` (`profiles/data/custom_profile_service.dart`): save via `ProfileRegistry`
  (version bump, grammar), generated template (EXP-01 `generateTemplate`) stored as `<id>-default` `templates` row bound
  to the profile (regenerated when fields change), duplicate built-ins/any profile into a new draft, delete; "Test on a
  recording" runs the PRF-02 system/user messages through `LlmEngine` with the profile grammar and renders JSON + Markdown.
  Providers `custom_profile_providers.dart` (profile list without the grammar converter, gating, recordings for the test).
  UI: Profiles tab `profiles_screen.dart` (built-ins + custom, duplicate, new) and editor `profile_editor_screen.dart`
  (name, description, instructions, speakers switch, routing target from EXP-05 vault targets / ask / default, fields,
  up to 2 examples, save/delete, test dialog with JSON / note tabs), routes `/profiles/new`, `/profiles/:profileId`.
  Gating via LIC-01 `featureProvider(Feature.customProfiles)` + `ensureFeature` paywall; without it custom profiles stay
  visible and usable but read-only (never deleted); built-in / managed profiles open read-only. new ARB strings (`profiles*`, `profileEditor*`);
  accessibility rows `Profile editor (new)` and `Profile editor (built-in, read-only)`.
- **Acceptance evidence:**
  - AC1: ✅ test: [PRF-07/AC1]
  - AC2: ✅ test: [PRF-07/AC2]
- **Decisions:** no ADR. PRODUCT-DECISION: custom profiles get `tier: pro`; on Pro expiry they become read-only (skill rule).
  PRODUCT-DECISION: diarized custom profiles ask for consent (`consent_confirmation: required`), single-speaker ones
  `optional`. The preview omits few-shot examples and cuts transcripts at 10k chars (no tokenizer from `LlmService` yet).
  Gates: format 0 changed, analyze / `dart analyze --fatal-infos` 0 issues, `flutter test` 825 passed / 24 skipped,
  pytest 66, recording-policy / egress OK.
- **Follow-ups:** see below.

## Follow-ups
- EXP-07: open the generated `<id>-default` template in the template editor (button placeholder not added).
- Wiring: override `schemaGrammarConverterProvider` (LLM-05) in the app so saving works on devices; the editor's preview
  needs `llmEngineProvider` (FND-11) — both are overridden in tests only.
- Preview with the exact-budget `BuiltPrompt` once `LlmService` exposes a `PromptTokenizer` (see PRF-02 follow-ups).
