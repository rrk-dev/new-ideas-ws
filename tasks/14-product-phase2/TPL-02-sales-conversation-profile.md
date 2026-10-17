# TPL-02 — Built-in profile: Sales conversation

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** PRF-02, PRF-03, PRF-09, EXP-01, SEC-07, SEC-09 | **Source:** User decision 2026-10-16 (product Phase 2: more summary templates)
**Status:** review
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-markdown-vault-export, vv-llm-inference, vv-benchmark-eval, vv-audio-capture, vv-testing

## Goal
A built-in English "Sales conversation" profile summarises an in-person meeting or an imported recording of a sales conversation into needs, objections, commitments and next steps.

## Scope
- [x] `app/assets/profiles/sales_call.yaml` (format 1): schema with `title`, `summary`, `participants[]`, `needs[]`, `objections[] {objection, response}`, `commitments[] {who, what, t}`, `next_steps[] {task, owner, due, t}`, `competitors_mentioned[]`, `open_questions[]`. Only what is stated: no deal scoring, no sentiment ratings, no probability-to-close.
- [x] **SEC-09 wording:** the app records through the microphone only and never records phone or VoIP calls. The profile name, description, icon, template text and any UI copy must not suggest call recording (name it "Sales conversation"; describe in-person conversations and imported audio the user has the right to use; speakerphone or video-call audio picked up from the room is not a supported use case and must not be advertised, AUD-06 attestation applies). Add a test that scans the profile and template strings for call-recording claims.
- [x] `stt.diarization: true`, `consent_confirmation: required` (multi-person; validator rule).
- [x] `next_steps` reuses the `{task, owner, due, t}` item shape of the meeting `action_items` so later export tasks (TSK-02) can treat them uniformly; `render_write_steps.dart` reads only `json['action_items']`, so implement and test a profile-aware mapping of `next_steps` into the `action_items` table without changing meeting behaviour, and record it in the profile notes.
- [x] Templates `sales-call-default`, `sales-call-logseq`, `sales-call-plain`; goldens (full / empty / adversarial); registered in `builtin_templates.dart` and `builtin_profiles.dart`; `tier` provisional with `// PRODUCT-DECISION` (LIC-05).
- [x] Eval: ≥ 30 synthetic transcripts in `tools/bench/eval/sales_call/` (fictional people and companies, 2–4 speakers, objections raised and dropped, commitments by each side, a conversation with no next steps, injection attempt); baseline recorded.

## Acceptance Criteria
- `next_steps` appear as action items with correct fields and meeting action items are unchanged (`[TPL-02/AC6]`).
- The profile passes `ProfileValidator`, built-in profile tests and the prompt snapshot test (`[TPL-02/AC1]`).
- Goldens match and are markdownlint-clean (`[TPL-02/AC2]`).
- On the 30-case eval with the default catalog model: schema validity ≥ 90%, hallucination ≤ 15%; next-step recall/precision targets are written into this file before the first baseline run and the baseline is committed (artifact).
- A scan test proves no profile, template or localised string claims or implies phone/VoIP call recording (`[TPL-02/AC4]`).
- Meeting profile output and its goldens are unchanged (existing tests stay green).

## Eval targets (written before the first baseline run)
Mirrored in `tools/bench/eval/sales_call/scoring.json`. These are targets, not measurements.

| Metric | Target |
|---|---|
| `schema_valid` (hard gate, ADR-LLM-08) | ≥ 0.90 |
| `hallucination_rate` (hard gate, ADR-LLM-08) | ≤ 0.15 |
| `lists.next_steps.recall` | ≥ 0.60 |
| `lists.next_steps.precision` | ≥ 0.60 |
| `lists.next_steps.owner_accuracy` | ≥ 0.50 |
| `lists.objections.recall` | ≥ 0.50 |
| `lists.commitments.recall` | ≥ 0.50 |
| `lists.needs.recall` | ≥ 0.50 |

## Notes
- English only. The profile summarises what was said; it does not advise on, rank or score the participants.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/TPL-02-sales-conversation-profile · **Date:** 2026-10-17
- **Summary:** Built-in English `sales_call` profile ("Sales conversation", `app/assets/profiles/sales_call.yaml`; diarization on, `consent_confirmation: required`, existing post-processors only, no examples, no scoring/rating/prediction), three templates (`sales-call-default/-logseq/-plain`) with 9 markdown goldens, and the profile-aware action-item mapping (`next_steps` → `action_items` via `kActionItemSourceFields`; meeting and lecture unchanged). 32-case eval set in `tools/bench/eval/sales_call/` — **transcripts are simulated** (`gen_cases.py`, `meta.asr.simulated: true`), not TTS → whisper. The task text's `[TPL-02/ACn]` tags do not match the bullets' positions; tests use the positional numbering (AC1 = next steps … AC6 = meeting unchanged), which is what `tasks.py` checks. Tests that enumerate built-in profiles were updated.
- **Baseline (measured, Llama-3.2-1B-Instruct Q4_K_M, host CPU, 32 cases, commit 8ddb8c0 + uncommitted TPL-02 changes):** schema_valid 100 %, hallucination 1.7 % (hard gates pass); next_steps recall 60.8 % (≥ 60 % ✅), owner accuracy 80.6 %, objections recall 73.3 %, needs recall 83.3 %. **Misses:** next_steps precision 56.4 % (target 60 %) and commitments recall 44.2 % (target 50 %). Also noted: next_steps `due` accuracy 6.5 %, over-extraction in objections (precision 30.8 %) and open_questions (11.6 %). Targets were not lowered. Report `tools/bench/results/2026-10-17-eval-sales_call-Llama-3.2-1B-Instruct-Q4-K-M.md`.
- **Acceptance evidence:**
  - AC1: ✅ test: [TPL-02/AC1]
  - AC2: ✅ test: [TPL-02/AC2]
  - AC3: ✅ test: [TPL-02/AC3]
  - AC4: ✅ test: [TPL-02/AC4]; artifact: tools/bench/eval/baselines/sales_call.Llama-3.2-1B-Instruct-Q4-K-M.json
  - AC5: ✅ test: [TPL-02/AC5]
  - AC6: ✅ test: [TPL-02/AC6]
- **Decisions:** tier `pro` is a placeholder (`# PRODUCT-DECISION (LIC-05)`); sales_call is not added to the default `tools/ci/eval.sh` list until the missed targets are met.
- **Follow-ups:**
  - Tune instructions/post-processing for next_steps precision (≥ 60 %) and commitments recall (≥ 50 %), then gate in `eval.sh`.
  - Investigate next_steps `due` accuracy (6.5 %) and over-extraction of objections/open_questions.
  - Re-record the 32 transcripts with `synth.py` (TTS → whisper) and re-baseline.
  - Product: Free vs Pro tier (LIC-05); consent/AUD-06 attestation wording (SEC-07); classifier keywords (PRF-06) not tuned.
