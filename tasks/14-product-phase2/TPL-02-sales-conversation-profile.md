# TPL-02 — Built-in profile: Sales conversation

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** PRF-02, PRF-03, PRF-09, EXP-01, SEC-07, SEC-09 | **Source:** User decision 2026-10-16 (product Phase 2: more summary templates)
**Status:** todo
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-markdown-vault-export, vv-llm-inference, vv-benchmark-eval, vv-audio-capture, vv-testing

## Goal
A built-in English "Sales conversation" profile summarises an in-person meeting or an imported recording of a sales conversation into needs, objections, commitments and next steps.

## Scope
- [ ] `app/assets/profiles/sales_call.yaml` (format 1): schema with `title`, `summary`, `participants[]`, `needs[]`, `objections[] {objection, response}`, `commitments[] {who, what, t}`, `next_steps[] {task, owner, due, t}`, `competitors_mentioned[]`, `open_questions[]`. Only what is stated: no deal scoring, no sentiment ratings, no probability-to-close.
- [ ] **SEC-09 wording:** the app records through the microphone only and never records phone or VoIP calls. The profile name, description, icon, template text and any UI copy must not suggest call recording (name it "Sales conversation"; describe in-person conversations and imported audio the user has the right to use; speakerphone or video-call audio picked up from the room is not a supported use case and must not be advertised, AUD-06 attestation applies). Add a test that scans the profile and template strings for call-recording claims.
- [ ] `stt.diarization: true`, `consent_confirmation: required` (multi-person; validator rule).
- [ ] `next_steps` reuses the `{task, owner, due, t}` item shape of the meeting `action_items` so later export tasks (TSK-02/TSK-03) can treat them uniformly; `render_write_steps.dart` reads only `json['action_items']`, so implement and test a profile-aware mapping of `next_steps` into the `action_items` table without changing meeting behaviour, and record it in the profile notes.
- [ ] Templates `sales-call-default`, `sales-call-logseq`, `sales-call-plain`; goldens (full / empty / adversarial); registered in `builtin_templates.dart` and `builtin_profiles.dart`; `tier` provisional with `// PRODUCT-DECISION` (LIC-05).
- [ ] Eval: ≥ 30 synthetic transcripts in `tools/bench/eval/sales_call/` (fictional people and companies, 2–4 speakers, objections raised and dropped, commitments by each side, a conversation with no next steps, injection attempt); baseline recorded.

## Acceptance Criteria
- `next_steps` appear as action items with correct fields and meeting action items are unchanged (`[TPL-02/AC6]`).
- The profile passes `ProfileValidator`, built-in profile tests and the prompt snapshot test (`[TPL-02/AC1]`).
- Goldens match and are markdownlint-clean (`[TPL-02/AC2]`).
- On the 30-case eval with the default catalog model: schema validity ≥ 90%, hallucination ≤ 15%; next-step recall/precision targets are written into this file before the first baseline run and the baseline is committed (artifact).
- A scan test proves no profile, template or localised string claims or implies phone/VoIP call recording (`[TPL-02/AC4]`).
- Meeting profile output and its goldens are unchanged (existing tests stay green).

## Notes
- English only. The profile summarises what was said; it does not advise on, rank or score the participants.
