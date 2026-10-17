# TPL-03 — Built-in profile: Interview

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** PRF-02, PRF-03, PRF-09, EXP-01, SEC-07 | **Source:** User decision 2026-10-16 (product Phase 2: more summary templates)
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-markdown-vault-export, vv-llm-inference, vv-benchmark-eval, vv-testing

## Goal
A built-in English "Interview" profile turns a two-person interview (research, journalism, podcast-style or informational) into topics, question-and-answer highlights, verbatim quotes and follow-ups.

## Scope
- [x] `app/assets/profiles/interview.yaml` (format 1): schema with `title`, `summary`, `participants[] {name, role}`, `topics[]`, `qa_highlights[] {question, answer, t}`, `quotes[] {speaker, text, t}`, `follow_ups[] {task, owner, due, t}`, `open_questions[]`.
- [x] Quotes must be verbatim: `ground_to_transcript` (or a stricter post-processor if the existing one is too lenient for verbatim text — decide and document) drops any quote not found in the transcript.
- [x] **Out of scope by design:** no scoring, ranking, rating or hire/no-hire recommendation of any person. State this in the profile instructions, the profile description and the task notes (small models are unreliable and such output carries legal and fairness risk).
- [x] `stt.diarization: true` with `num_speakers` fixed at 2 as a hint only (the user can still override), `consent_confirmation: required`.
- [x] Templates `interview-default`, `interview-logseq`, `interview-plain` with Q&A rendered as blockquote pairs; goldens (full / empty / adversarial); registered in `builtin_templates.dart` and `builtin_profiles.dart`; `tier` provisional with `// PRODUCT-DECISION` (LIC-05).
- [x] **Action-item mapping:** `render_write_steps.dart` reads only `json['action_items']`. Implement and test a profile-aware normalisation that maps `follow_ups` into the `action_items` table (body, owner, `due_iso` only when resolvable, `t`) so they reach the Action Items screen and the exporters, without changing the meeting profile; record the mapping in the profile notes.
- [x] Eval: ≥ 30 synthetic interviews in `tools/bench/eval/interview/` (fictional people; varied length; interruptions, cross-talk, a one-word-answer interview, an injection attempt); baseline recorded.

## Acceptance Criteria
- Items in `follow_ups` appear as action items with correct fields, and the meeting profile's action items are unchanged (`[TPL-03/AC6]`).
- The profile passes `ProfileValidator`, built-in profile tests and the prompt snapshot test (`[TPL-03/AC1]`).
- Goldens match and are markdownlint-clean (`[TPL-03/AC2]`).
- Every quote in every eval output is a substring of the transcript after the documented normalisation (quote-fidelity 100%, `[TPL-03/AC3]`).
- On the 30-case eval with the default catalog model: schema validity ≥ 90%, hallucination ≤ 15%; Q&A recall targets are written into this file before the first baseline run and the baseline is committed (artifact).
- A test proves no schema field or instruction text asks the model to rate, score or recommend a person (`[TPL-03/AC5]`).

## Eval targets (written before the first baseline run)
Mirrored in `tools/bench/eval/interview/scoring.json`. These are targets, not measurements. `quote_fidelity` is the share of quotes in the post-processed output (what the app stores) that are a substring of the transcript after normalisation (lower case, typographic apostrophes folded, punctuation and whitespace ignored); the raw model output is reported next to it for information.

| Metric | Target |
|---|---|
| `schema_valid` (hard gate, ADR-LLM-08) | ≥ 0.90 |
| `hallucination_rate` (hard gate, ADR-LLM-08) | ≤ 0.15 |
| `quote_fidelity` (post-processed) | = 1.00 |
| `lists.qa_highlights.recall` | ≥ 0.50 |
| `lists.qa_highlights.precision` | ≥ 0.40 |
| `lists.follow_ups.recall` | ≥ 0.60 |
| `lists.follow_ups.precision` | ≥ 0.60 |
| `lists.follow_ups.owner_accuracy` | ≥ 0.50 |
| `lists.topics.recall` | ≥ 0.50 |

## Notes
- English only. Interviewing a person is a consent-sensitive recording (SEC-07 confirmation stays on).
- No scoring, ranking, rating or hire/no-hire output by design: the profile instructions and description say so and a test (`[TPL-03/AC6]`) scans schema and instructions. `quotes` use the new stricter `verbatim_quotes` post-processor because `ground_to_transcript` keeps an item when half of its key terms occur anywhere in the transcript, which would let a paraphrase through as a "quote".
- Action-item mapping: `follow_ups[] {task, owner, due, t}` → `action_items` rows (body, owner, `due_iso` only when `resolve_relative_dates` resolved it, `t`) via `kActionItemSourceFields['interview']`; meeting unchanged.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/TPL-03-interview-profile · **Date:** 2026-10-17
- **Summary:** Built-in English `interview` profile (`app/assets/profiles/interview.yaml`; diarization on, `num_speakers: 2` hint, `consent_confirmation: required`, no examples, no scoring/ranking/rating/hire recommendation stated in instructions, description and notes), templates `interview-default/-logseq/-plain` (Q&A as blockquote pairs) with 9 markdown goldens, and the action-item mapping (`follow_ups` → `action_items` via `kActionItemSourceFields`; meeting, lecture and sales_call unchanged). **Quote decision:** existing `ground_to_transcript` keeps an item when ≥ 50 % of its key terms appear anywhere, so a paraphrase passes; a new stricter post-processor `verbatim_quotes` drops any quote that is not a whole-word substring of the transcript (case, punctuation and typographic apostrophes normalised). Quotes spanning two speaker turns or containing ellipses are dropped. 32-case eval set in `tools/bench/eval/interview/` — **transcripts are simulated** (`gen_cases.py`, `meta.asr.simulated: true`). The task text's `[TPL-03/ACn]` tags do not match the bullet order; tests use the positional numbering that `tasks.py` checks. Tests enumerating built-in profiles were updated.
- **Baseline (measured, Llama-3.2-1B-Instruct Q4_K_M, host CPU, 32 cases, commit 4974d12 + uncommitted TPL-03 changes):** schema_valid 100 %, hallucination 5.3 %; quote fidelity 100 % post-processed vs 93.5 % raw (43 of 46 quotes kept); qa_highlights recall 50.9 % / precision 83.1 %; follow_ups recall 69.8 % / precision 61.2 % / owner accuracy 80.0 %. **Miss:** topics recall 19.8 % (target 50 %). Also noted: follow_ups `due` accuracy 26.7 %, quotes recall 12.9 %, open_questions precision 2.6 % (over-extraction). Targets were not lowered. Report `tools/bench/results/2026-10-17-eval-interview-Llama-3.2-1B-Instruct-Q4-K-M.md`.
- **Acceptance evidence:**
  - AC1: ✅ test: [TPL-03/AC1]
  - AC2: ✅ test: [TPL-03/AC2]
  - AC3: ✅ test: [TPL-03/AC3]
  - AC4: ✅ test: [TPL-03/AC4]
  - AC5: ✅ test: [TPL-03/AC5]; artifact: tools/bench/eval/baselines/interview.Llama-3.2-1B-Instruct-Q4-K-M.json
  - AC6: ✅ test: [TPL-03/AC6]
- **Decisions:** tier `pro` is a placeholder (`# PRODUCT-DECISION (LIC-05)`); interview is not added to the default `tools/ci/eval.sh` list until the missed target is met; new `verbatim_quotes` post-processor documented in `docs/profile-spec.md`.
- **Follow-ups:**
  - Tune topics recall (≥ 50 %), then gate in `eval.sh`; investigate open_questions over-extraction and follow_ups `due` accuracy.
  - Re-record the 32 transcripts with `synth.py` (TTS → whisper) and re-baseline.
  - Allow `verbatim_quotes` to match quotes spanning adjacent turns of one speaker if real recordings need it.
  - Product: Free vs Pro tier (LIC-05); consent wording (SEC-07); classifier keywords (PRF-06) not tuned.
