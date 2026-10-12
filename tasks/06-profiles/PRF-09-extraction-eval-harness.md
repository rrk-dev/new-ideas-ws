# PRF-09 — Extraction Quality Evaluation Harness

**Workstream:** Profiles | **Phase:** 2–3 (start early) | **Size:** L | **Depends on:** LLM-04, PRF-02 | **Source:** Gap (no quality bar defined for extraction)
**Status:** todo
**Skills:** vv-task-workflow, vv-benchmark-eval, vv-extraction-profiles, vv-llm-inference, vv-testing

## Goal
A repeatable, offline eval that scores prompts/models per profile so changes are measured, not guessed.

## Scope
- [ ] Seed meeting cases from `vv-extraction-profiles/references/meeting-profile.example.yaml`; draft warranty/engineering schemas here (PRF-04/05 finalize them). Synthetic audio recipe: `vv-benchmark-eval` → LLM extraction eval.
- [ ] Golden dataset: ≥ 30 transcripts per built-in profile (synthetic + consented real recordings), each with expected JSON.
- [ ] Desktop runner (same llama.cpp build on macOS/Linux) for fast iteration; on-device runner for final numbers.
- [ ] Metrics: schema validity, per-field exact/fuzzy match, list recall/precision, hallucination rate (items not grounded in transcript), latency.
- [ ] Report diff between runs (prompt or model changes) — used as a regression gate in CI for prompt changes.

## Acceptance Criteria
- `make eval PROFILE=meeting MODEL=...` (root `Makefile` wrapping `tools/bench/eval/run.py`) produces a report in < 30 min on a dev machine; `tools/ci/eval.sh` runs it in CI on prompt/profile changes.
- Baseline numbers recorded for each built-in profile.
