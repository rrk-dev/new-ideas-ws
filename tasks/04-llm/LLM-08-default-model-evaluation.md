# LLM-08 — Default LLM Model Evaluation & Selection

**Workstream:** LLM | **Phase:** 2–3 | **Size:** M | **Depends on:** LLM-04, PRF-09 | **Source:** §4.2 (Llama-3.2-3B or Gemma-2B — open decision)
**Status:** todo
**Skills:** vv-task-workflow, vv-llm-inference, vv-benchmark-eval, vv-decision-records, vv-privacy-security

## Goal
Pick default and fallback models per tier using extraction quality and speed on our own eval set.

## Scope
- [ ] Candidates: Llama-3.2-3B-Instruct, Llama-3.2-1B-Instruct, Gemma-2-2B-IT (and newer small instruct models available at build time, e.g., Qwen / Phi / Gemma 3 variants) in Q4_K_M / Q4_0.
- [ ] Evaluate on PRF-09 harness: schema validity, field accuracy, action-item recall/precision, hallucination rate, tok/s, RAM.
- [ ] Check license compatibility for commercial redistribution (SEC-05).
- [ ] Choose default per tier; document in `docs/models.md`.

## Acceptance Criteria
- Decision backed by eval results table; ADR-LLM-08 committed.
