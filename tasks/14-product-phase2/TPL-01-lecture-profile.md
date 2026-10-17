# TPL-01 — Built-in profile: Lecture notes

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** PRF-02, PRF-03, PRF-09, EXP-01, SEC-07 | **Source:** User decision 2026-10-16 (product Phase 2: more summary templates)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-markdown-vault-export, vv-llm-inference, vv-benchmark-eval, vv-testing

## Goal
A built-in English "Lecture" profile turns a single-speaker lecture or class recording into structured study notes (summary, key concepts, outline, deadlines) written as Markdown.

## Scope
- [ ] `app/assets/profiles/lecture.yaml` (format 1, `docs/profile-spec.md`): schema with `title`, `summary`, `key_concepts[] {term, explanation}`, `outline[] {heading, points[]}`, `assignments[] {task, due, t}`, `questions[]` (review questions the lecturer posed), `references[]` (books/papers/links named aloud). Instructions follow the small-model rules in the spec (no few-shot examples, grounded, empty list when absent).
- [ ] `stt.diarization: false`; `post_process` limited to the existing named post-processors (e.g. `resolve_relative_dates`, `drop_ungrounded_timestamps`, `ground_to_transcript`); no new post-processor unless justified in the task notes.
- [ ] `consent_confirmation`: `required` (user decision 2026-10-17: consent is always required; the description may say personal use is fine, SEC-07 owner confirms the wording); the validator rule "diarization true may not use `none`" is unaffected.
- [ ] Templates `lecture-default`, `lecture-logseq`, `lecture-plain` in `app/assets/templates/`, registered in `builtin_templates.dart`; markdownlint-clean output; golden fixtures (full / empty / adversarial) like the existing profiles.
- [ ] Register the profile in `builtin_profiles.dart`; set `tier` provisionally and mark it `// PRODUCT-DECISION` until LIC-05 decides Free vs Pro.
- [ ] Eval: ≥ 30 synthetic transcripts with expected JSON in `tools/bench/eval/lecture/` using the PRF-09 recipe (fictional lecturers and courses; include noisy ASR, long lectures that need map-reduce, a lecture with no assignments, an injection attempt); record a baseline for the catalog's current default model.
- [ ] **Action-item mapping:** `render_write_steps.dart` reads only `json['action_items']`. Implement and test a profile-aware normalisation that maps `assignments` into the `action_items` table (body, owner, `due_iso` only when resolvable, `t`) so they reach the Action Items screen and the exporters, without changing the meeting profile; record the mapping in the profile notes.
- [ ] STT vocabulary hints stay user-configurable through the existing `vocabulary.<profileId>` setting.

## Acceptance Criteria
- Items in `assignments` appear as action items with correct fields, and the meeting profile's action items are unchanged (`[TPL-01/AC6]`).
- The profile passes `ProfileValidator`, the existing built-in profile tests and the prompt snapshot test (`[TPL-01/AC1]`).
- Rendered Markdown for full, empty and adversarial fixtures matches goldens and passes markdownlint (`[TPL-01/AC2]`).
- On the 30-case eval with the default catalog model: schema validity ≥ 90% and hallucination rate ≤ 15% (the ADR-LLM-08 hard gates); the remaining per-field targets (key-concept recall, assignment recall/precision) are written into this file **before** the first baseline run and reported with the baseline in `tools/bench/eval/baselines/` (artifact).
- A 60-minute lecture transcript completes through the map-reduce path without exceeding the tier memory budget (host test with the CI model; device row for the Low tier).
- No new network host, permission or log line containing transcript content (`check_egress.sh`, log-content test).

## Notes
- English only. Lecture notes are study aids, not verbatim transcripts; definitions must come from the transcript, not model knowledge (grounding check).
