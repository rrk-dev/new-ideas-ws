# TPL-03 — Built-in profile: Interview

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** PRF-02, PRF-03, PRF-09, EXP-01, SEC-07 | **Source:** User decision 2026-10-16 (product Phase 2: more summary templates)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-markdown-vault-export, vv-llm-inference, vv-benchmark-eval, vv-testing

## Goal
A built-in English "Interview" profile turns a two-person interview (research, journalism, podcast-style or informational) into topics, question-and-answer highlights, verbatim quotes and follow-ups.

## Scope
- [ ] `app/assets/profiles/interview.yaml` (format 1): schema with `title`, `summary`, `participants[] {name, role}`, `topics[]`, `qa_highlights[] {question, answer, t}`, `quotes[] {speaker, text, t}`, `follow_ups[] {task, owner, due, t}`, `open_questions[]`.
- [ ] Quotes must be verbatim: `ground_to_transcript` (or a stricter post-processor if the existing one is too lenient for verbatim text — decide and document) drops any quote not found in the transcript.
- [ ] **Out of scope by design:** no scoring, ranking, rating or hire/no-hire recommendation of any person. State this in the profile instructions, the profile description and the task notes (small models are unreliable and such output carries legal and fairness risk).
- [ ] `stt.diarization: true` with `num_speakers` fixed at 2 as a hint only (the user can still override), `consent_confirmation: required`.
- [ ] Templates `interview-default`, `interview-logseq`, `interview-plain` with Q&A rendered as blockquote pairs; goldens (full / empty / adversarial); registered in `builtin_templates.dart` and `builtin_profiles.dart`; `tier` provisional with `// PRODUCT-DECISION` (LIC-05).
- [ ] **Action-item mapping:** `render_write_steps.dart` reads only `json['action_items']`. Implement and test a profile-aware normalisation that maps `follow_ups` into the `action_items` table (body, owner, `due_iso` only when resolvable, `t`) so they reach the Action Items screen and the exporters, without changing the meeting profile; record the mapping in the profile notes.
- [ ] Eval: ≥ 30 synthetic interviews in `tools/bench/eval/interview/` (fictional people; varied length; interruptions, cross-talk, a one-word-answer interview, an injection attempt); baseline recorded.

## Acceptance Criteria
- Items in `follow_ups` appear as action items with correct fields, and the meeting profile's action items are unchanged (`[TPL-03/AC6]`).
- The profile passes `ProfileValidator`, built-in profile tests and the prompt snapshot test (`[TPL-03/AC1]`).
- Goldens match and are markdownlint-clean (`[TPL-03/AC2]`).
- Every quote in every eval output is a substring of the transcript after the documented normalisation (quote-fidelity 100%, `[TPL-03/AC3]`).
- On the 30-case eval with the default catalog model: schema validity ≥ 90%, hallucination ≤ 15%; Q&A recall targets are written into this file before the first baseline run and the baseline is committed (artifact).
- A test proves no schema field or instruction text asks the model to rate, score or recommend a person (`[TPL-03/AC5]`).

## Notes
- English only. Interviewing a person is a consent-sensitive recording (SEC-07 confirmation stays on).
