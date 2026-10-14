# PRF-02 — System Prompt Builder

**Workstream:** Profiles | **Phase:** 2 (pulled forward: needed by LLM-05 / PRF-09 / GATE-02) | **Size:** M | **Depends on:** PRF-01, LLM-04 | **Source:** §5 Phase 3
**Status:** in-progress
**Skills:** vv-task-workflow, vv-extraction-profiles, vv-llm-inference, vv-testing

## Goal
Assemble the final prompt from profile + transcript + context, within the token budget.

## Scope
- [ ] Compose: system prompt, profile instructions, few-shot examples, metadata (date, duration, speakers, user markers from AUD-08), transcript (speaker-labelled), output-schema reminder.
- [ ] Apply model chat template from GGUF.
- [ ] Token budgeting: trim examples first, then hand off to LLM-06 map-reduce when transcript exceeds budget.
- [ ] Prompt-injection hygiene: transcript is clearly delimited as data (someone may *say* "ignore previous instructions").
- [ ] Snapshot tests of rendered prompts.

## Acceptance Criteria
- Prompt snapshots stable across runs; budget never exceeded (unit-tested with large transcripts).
