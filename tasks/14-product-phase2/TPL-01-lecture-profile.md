# TPL-01 — Built-in profile: Lecture notes

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** PRF-02, PRF-03, PRF-09, EXP-01, SEC-07 | **Source:** User decision 2026-10-16 (product Phase 2: more summary templates)
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-markdown-vault-export, vv-llm-inference, vv-benchmark-eval, vv-testing

## Goal
A built-in English "Lecture" profile turns a single-speaker lecture or class recording into structured study notes (summary, key concepts, outline, deadlines) written as Markdown.

## Scope
- [x] `app/assets/profiles/lecture.yaml` (format 1, `docs/profile-spec.md`): schema with `title`, `summary`, `key_concepts[] {term, explanation}`, `outline[] {heading, points[]}`, `assignments[] {task, due, t}`, `questions[]` (review questions the lecturer posed), `references[]` (books/papers/links named aloud). Instructions follow the small-model rules in the spec (no few-shot examples, grounded, empty list when absent).
- [x] `stt.diarization: false`; `post_process` limited to the existing named post-processors (e.g. `resolve_relative_dates`, `drop_ungrounded_timestamps`, `ground_to_transcript`); no new post-processor unless justified in the task notes.
- [x] `consent_confirmation`: `required` (user decision 2026-10-17: consent is always required; the description may say personal use is fine, SEC-07 owner confirms the wording); the validator rule "diarization true may not use `none`" is unaffected.
- [x] Templates `lecture-default`, `lecture-logseq`, `lecture-plain` in `app/assets/templates/`, registered in `builtin_templates.dart`; markdownlint-clean output; golden fixtures (full / empty / adversarial) like the existing profiles.
- [x] Register the profile in `builtin_profiles.dart`; set `tier` provisionally and mark it `// PRODUCT-DECISION` until LIC-05 decides Free vs Pro.
- [x] Eval: ≥ 30 synthetic transcripts with expected JSON in `tools/bench/eval/lecture/` using the PRF-09 recipe (fictional lecturers and courses; include noisy ASR, long lectures that need map-reduce, a lecture with no assignments, an injection attempt); record a baseline for the catalog's current default model.
- [x] **Action-item mapping:** `render_write_steps.dart` reads only `json['action_items']`. Implement and test a profile-aware normalisation that maps `assignments` into the `action_items` table (body, owner, `due_iso` only when resolvable, `t`) so they reach the Action Items screen and the exporters, without changing the meeting profile; record the mapping in the profile notes.
- [x] STT vocabulary hints stay user-configurable through the existing `vocabulary.<profileId>` setting.

## Acceptance Criteria
- Items in `assignments` appear as action items with correct fields, and the meeting profile's action items are unchanged (`[TPL-01/AC6]`).
- The profile passes `ProfileValidator`, the existing built-in profile tests and the prompt snapshot test (`[TPL-01/AC1]`).
- Rendered Markdown for full, empty and adversarial fixtures matches goldens and passes markdownlint (`[TPL-01/AC2]`).
- On the 30-case eval with the default catalog model: schema validity ≥ 90% and hallucination rate ≤ 15% (the ADR-LLM-08 hard gates); the remaining per-field targets (key-concept recall, assignment recall/precision) are written into this file **before** the first baseline run and reported with the baseline in `tools/bench/eval/baselines/` (artifact).
- A 60-minute lecture transcript completes through the map-reduce path without exceeding the tier memory budget (host test with the CI model; device row for the Low tier).
- No new network host, permission or log line containing transcript content (`check_egress.sh`, log-content test).

## Eval targets (written before the first baseline run)
Mirrored in `tools/bench/eval/lecture/scoring.json`. These are targets, not measurements.

| Metric | Target |
|---|---|
| `schema_valid` (hard gate, ADR-LLM-08) | ≥ 0.90 |
| `hallucination_rate` (hard gate, ADR-LLM-08) | ≤ 0.15 |
| `lists.key_concepts.recall` | ≥ 0.50 |
| `lists.assignments.recall` | ≥ 0.60 |
| `lists.assignments.precision` | ≥ 0.60 |

## Notes
- English only. Lecture notes are study aids, not verbatim transcripts; definitions must come from the transcript, not model knowledge (grounding check).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/TPL-01-lecture-profile · **Date:** 2026-10-17
- **Summary:** Built-in English `lecture` profile (`app/assets/profiles/lecture.yaml`, single speaker, `consent_confirmation: required`, existing post-processors only, no examples), three templates (`lecture-default/-logseq/-plain`) with 9 markdown goldens, and per-profile action-item mapping (`assignments` → `action_items` table via `kActionItemSourceFields`; meeting unchanged). 30-case eval set in `tools/bench/eval/lecture/` — **transcripts are simulated** (`gen_cases.py`, `meta.asr.simulated: true`), not TTS → whisper output. The task text's `[TPL-01/ACn]` tags do not match the bullets' positions; tests use the positional numbering (AC1 = action items … AC6 = egress), which is what `tasks.py` checks.
- **Baseline (measured, Llama-3.2-1B-Instruct Q4_K_M, host CPU, 30 cases, commit b30e084 + uncommitted TPL-01 changes):** schema_valid 100 %, hallucination 1.2 % (both hard gates pass); key_concepts recall 95.1 % (target 50 %), assignments recall 88.9 % (target 60 %) — **assignments precision 47.1 % misses its 60 % target** (model over-extracts assignments; 51 predicted vs 27 expected). Report `tools/bench/results/2026-10-17-eval-lecture-Llama-3.2-1B-Instruct-Q4-K-M.md`, baseline `tools/bench/eval/baselines/lecture.Llama-3.2-1B-Instruct-Q4-K-M.json`. Numbers are on simulated transcripts and are optimistic vs real ASR output.
- **60-min host test:** SmolLM2-135M, ctx 4096: 22141 transcript tokens, 14 chunks (12 invalid — a 135M model; the path is exercised, not quality), peak RSS 358 → 370 MiB.
- **Acceptance evidence:**
  - AC1: ✅ test: [TPL-01/AC1]
  - AC2: ✅ test: [TPL-01/AC2]
  - AC3: ✅ test: [TPL-01/AC3]
  - AC4: ✅ test: [TPL-01/AC4]; artifact: tools/bench/eval/baselines/lecture.Llama-3.2-1B-Instruct-Q4-K-M.json
  - AC5: ⏳ test: [TPL-01/AC5]; device: docs/test-plans/device/TPL-01.md
  - AC6: ✅ test: [TPL-01/AC6]
- **Decisions:** tier `pro` is a placeholder (`# PRODUCT-DECISION (LIC-05)`); no new post-processor; action-item source is a per-profile field map rather than a schema change; lecture is not added to the default `tools/ci/eval.sh` list until the precision target is met; eval cases are sized for single-pass context (long cases ~1.1k words).
- **Follow-ups:**
  - Tune lecture instructions/post-processing to lift assignment precision to ≥ 60 % (then add lecture to `eval.sh` gating).
  - Re-record the 30 transcripts with `synth.py` (TTS → whisper) and re-baseline.
  - LLM-06 repair prompt (prompt + invalid answer) can exceed n_ctx on long transcripts with tiny models; the engine rejects it safely, but the repair should truncate or skip.
  - Product: Free vs Pro tier (LIC-05); consent wording for lectures (SEC-07); classifier keywords for auto-detecting lectures (PRF-06) not tuned.
  - Run the Low-tier device row.
