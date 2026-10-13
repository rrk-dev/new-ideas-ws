# LLM-06 — Long-Transcript Handling (Chunking + Map-Reduce Extraction)

**Workstream:** LLM | **Phase:** 2–3 | **Size:** L | **Depends on:** LLM-04, LLM-05 | **Source:** Gap (a 60-min meeting ≈ 9–12k tokens; mobile context budgets are ~4–8k)
**Status:** todo
**Skills:** vv-task-workflow, vv-llm-inference, vv-extraction-profiles, vv-pipeline-orchestrator, vv-benchmark-eval, vv-testing

## Goal
Extraction works for transcripts much longer than the usable context window.

## Scope
- [ ] Token-budget planner: choose single-pass vs map-reduce based on transcript tokens, model context and device RAM.
- [ ] Map step: chunk on speaker/segment boundaries with overlap; extract partial structured results per chunk.
- [ ] Reduce step: merge/dedupe partial JSON (action items, decisions, attendees) — deterministic merge in Dart where possible, LLM merge for summaries.
- [ ] Persist per-chunk results for resume (FND-05).
- [ ] Progress reporting per chunk.

## Acceptance Criteria
- 2-hour transcript extracts successfully on a 6 GB device without OOM.
- On long-meeting eval set, action-item recall within 10% of single-pass on short meetings.

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist).
