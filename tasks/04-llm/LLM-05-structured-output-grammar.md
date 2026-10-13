# LLM-05 — Structured Output via Constrained Decoding

**Workstream:** LLM | **Phase:** 2–3 | **Size:** M | **Depends on:** LLM-04, PRF-09 | **Source:** Gap (small models produce unreliable free-form Markdown; templates need structured data)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-llm-inference, vv-extraction-profiles, vv-ffi-bridge, vv-native-build, vv-benchmark-eval, vv-testing

## Goal
The LLM produces JSON matching each profile's output schema; Markdown is rendered from that JSON by the template engine (EXP-01), not written freehand by the model.

## Scope
- [ ] Convert profile JSON Schema → GBNF grammar (llama.cpp `json_schema_to_grammar`).
- [ ] Validate output against schema; on failure, one repair retry, then fall back to raw-summary mode.
- [ ] Handle grammar performance cost (measure tok/s impact).
- [ ] Evidence fields: optionally include transcript timestamps for each extracted item (traceability, reduces hallucination).

## Acceptance Criteria
- ≥ 99% of runs on the PRF-09 eval set produce schema-valid JSON.
- Grammar overhead on decode speed documented (< 20% target).
