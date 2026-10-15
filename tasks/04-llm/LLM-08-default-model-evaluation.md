# LLM-08 — Default LLM Model Evaluation & Selection

**Workstream:** LLM | **Phase:** 2–3 | **Size:** M | **Depends on:** LLM-04, PRF-09 | **Source:** §4.2 (Llama-3.2-3B or Gemma-2B — open decision)
**Status:** review
**Skills:** vv-task-workflow, vv-llm-inference, vv-benchmark-eval, vv-decision-records, vv-privacy-security

## Goal
Pick default and fallback models per tier using extraction quality and speed on our own eval set.

## Scope
- [x] Candidates: Llama-3.2-3B-Instruct, Llama-3.2-1B-Instruct, Gemma-2-2B-IT (and newer small instruct models available at build time, e.g., Qwen / Phi / Gemma 3 variants) in Q4_K_M / Q4_0.
- [x] Evaluate on PRF-09 harness: schema validity, field accuracy, action-item recall/precision, hallucination rate, tok/s, RAM.
- [x] Check license compatibility for commercial redistribution (SEC-05).
- [x] Choose default per tier; document in `docs/models.md`.

## Acceptance Criteria
- Decision backed by eval results table; ADR-LLM-08 committed.

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist).

## Completion Notes
- **Agent:** GitHub Copilot CLI · **Branch:** fix/sttllm (PR with STT-05; builds on origin/task/LLM-08-default-llm-model) · **Date:** 2026-10-15
- **Summary:** `tools/bench/llm_select/{candidates.json,rank.py}` (12 candidates, licences, sizes, tier budgets, fixed weights, hard gates; unmeasured models are never picked; `make llm-select`), report `tools/bench/results/2026-10-15-llm08-selection.md`, ADR-LLM-08 (Proposed), `docs/models.md` "LLM defaults (LLM-08)", device rows `docs/test-plans/device/LLM-08.md`, tests `tools/ci/tests/test_llm_select.py` (5).
- **Numbers:** only Llama-3.2-1B Q4_K_M has real PRF-09 host results (quality 64%, 96.7% valid, 10.8% hallucination, 93 tok/s, 1203 MiB); the other candidates are `needs-eval` (weights unavailable offline). Licence screen from model cards: Qwen2.5-3B rejected (research licence).
- **Acceptance evidence:**
  - AC1: ⏳ test: [LLM-08/AC1]; artifact: docs/adr/ADR-LLM-08-default-llm.md; device: docs/test-plans/device/LLM-08.md
- **Decisions:** ADR-LLM-08-default-llm (Proposed).
- **Follow-ups:** see below

## Follow-ups
- Run `make eval-all` for every `needs-eval` candidate (needs the GGUF weights and device time), re-run `make llm-select`, then move ADR-LLM-08 to Accepted and update `docs/models.md` and the catalog defaults.
- Long-meeting ablations and device speed from the LLM-06 eval plan (chunk caps, overlap, map `n_predict`, prefix reuse; 2 h map-reduce wall time and thermal state).
- SEC-05 to confirm the licence screen (Llama 3.2 / Gemma pass-through terms).
