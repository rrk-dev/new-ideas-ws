# PRF-01 — Extraction Profile Data Model & Versioning

**Workstream:** Profiles | **Phase:** 2 (pulled forward: needed by LLM-05 / PRF-09 / GATE-02) | **Size:** M | **Depends on:** FND-04 | **Source:** §3.1.5 (Domain Extraction Profiles / Skills)
**Status:** todo
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-local-database, vv-llm-inference, vv-markdown-vault-export, vv-testing

## Goal
A single, versioned definition format for "skills" that drives prompt, output schema, template and routing.

## Scope
- [ ] Profile definition (YAML/JSON): id, name, version, description, icon, instructions, few-shot examples, output JSON Schema, default template id, default routing target, STT hints (vocabulary, diarization on/off), tier (free/pro/enterprise).
- [ ] Built-in profiles shipped as read-only assets; user/enterprise profiles stored in DB.
- [ ] Profile versioning: built-ins loaded from assets each launch keyed (id, version); duplicates get new ids; `extractions.profile_version` keeps history (spec → "Built-in profile updates"). The system prompt is fixed app code (PRF-02), not a profile field.
- [ ] Validation (schema well-formed, template variables match schema fields).

## Acceptance Criteria
- Profile spec documented in `docs/profile-spec.md` with a full example.
- Validator rejects malformed profiles with actionable errors.
