# LLM-06 — Long-Transcript Handling (Chunking + Map-Reduce Extraction)

**Workstream:** LLM | **Phase:** 2–3 | **Size:** L | **Depends on:** LLM-04, LLM-05 | **Source:** Gap (a 60-min meeting ≈ 9–12k tokens; mobile context budgets are ~4–8k)
**Status:** review
**Skills:** vv-task-workflow, vv-llm-inference, vv-extraction-profiles, vv-pipeline-orchestrator, vv-benchmark-eval, vv-testing

## Goal
Extraction works for transcripts much longer than the usable context window.

## Scope
- [x] Token-budget planner: choose single-pass vs map-reduce based on transcript tokens, model context and device RAM. `TokenBudgetPlanner` on exact counts (`LlmService` now implements `LlmTokenizer`: `countTokens`, `countPromptTokens` with the chat template, `contextWindow` = n_ctx after the LLM-07 memory gate); single pass → single pass without examples → map-reduce; map `n_predict` ≤ n_ctx/4; chunk = min(budget, tier cap Low 2048 / Mid 3072 / High 4096); 10% overlap; too small → `OutOfMemoryFailure`.
- [x] Map step: chunk on speaker/segment boundaries with overlap; extract partial structured results per chunk. `chunkTranscript` (segments never cut; ends at a speaker change in the last 20% when possible; ~10% overlap; exact recount + re-plan); profile `map_schema` (default `schema`) via `MapReduceSpec.fromProfile`; LLM-05 `StructuredExtractor` per chunk (grammar, validation, one repair, evidence check against the chunk's timestamps, no per-chunk summary fallback). KV prefix reuse: `vv_gen_params.reuse_prefix` (`llama_memory_seq_rm` from the shared prefix; full clear on SWA-pruned / unsupported memories / after a failed or cancelled decode) + `vv_llm_last_reused_tokens`; measured in ctest `vv_llm_prefix`.
- [x] Reduce step: merge/dedupe partial JSON (action items, decisions, attendees) — deterministic merge in Dart where possible, LLM merge for summaries. `PartialReducer` implements the profile `reduce` strategies (`union_dedupe` with token Jaccard ≥ 0.8 or same `t` + ≥ 0.5, null-filling merge, time sort, `maxItems`; `first_non_null`; `max`/`min`); `llm_summarize` fields only go to the LLM (free text, summary preset, cleaned/clipped, hierarchical when the parts do not fit).
- [x] Persist per-chunk results for resume (FND-05). `MapReduceCheckpoint` in `jobs.checkpoint` via `StepContext.saveCheckpoint` (one transaction per chunk); `paramsHash` over model/profile key, n_ctx, map n_predict, transcript hash and chunk boundaries; `ExtractStep(longTranscript: LongTranscriptExtraction(...))` hook.
- [x] Progress reporting per chunk. One unit per map chunk + one per prose field, token progress within a chunk; checkpoint saves carry the progress.

## Acceptance Criteria
- 2-hour transcript extracts successfully on a 6 GB device without OOM.
- On long-meeting eval set, action-item recall within 10% of single-pass on short meetings.

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/LLM-06-long-transcript-map-reduce (base `origin/main` 67b6fcf; LLM-04/05/07 already merged there) · **Date:** 2026-10-14
- **Summary:** Dart `app/lib/features/extraction/domain/long_transcript/` — `token_budget.dart` (planner, tier caps), `transcript_chunker.dart` (lines, chunks, timestamps), `partial_reducer.dart` (deterministic reduce), `extraction_prompts.dart` (`ExtractionPromptSource`, default `ProfilePromptSource` until PRF-02, transcript escaping), `map_reduce_extractor.dart` (`MapReduceExtractor`, `MapReduceSpec`, `MapReduceCheckpoint`); `LlmTokenizer` + `LlmRequest.reusePrefix` (`core/platform/llm_engine.dart`), `LlmService implements LlmTokenizer`, `LlmSession.generate(reusePrefix:)`, `LlmRunStats.reusedPromptTokens`; `StructuredExtractor` gained `onToken`, `summaryFallback`, `reusePrefix`; `ExtractStep(longTranscript:)` + `_StepCheckpoints`. Native: `reuse_prefix` in `vv_gen_params`, `vv_llm_last_reused_tokens`, KV token tracking in `vv_llama_engine.cpp`; ctest `native/tests/llm_prefix_test.c`; regenerated `vv_bindings.g.dart`; `LlmGenParams.reusePrefix`, `LlmGenResult.reusedTokens`. Docs `docs/long-transcripts.md` (design + recall methodology), results `tools/bench/results/2026-10-14-llm06-map-reduce.md`, device rows `docs/test-plans/device/LLM-06.md`. Tests: `test/unit/extraction/long_transcript_test.dart` (21), `test/unit/pipeline/long_transcript_pipeline_test.dart` (2, orchestrator kill/resume on a file DB), `test/unit/extraction/long_transcript_host_test.dart` (SmolLM2), `llm_service_test.dart` (+2); fakes `OracleLlmEngine`, `WordTokenizer`, `helpers/synthetic_transcript.dart`.
- **Host numbers (M3 Pro, heavily shared host):** 2-hour synthetic meeting = 47.6k real tokens → 30 chunks at n_ctx 4096, completes, schema-valid, every call ≤ n_ctx, peak RSS 341 → 361 MiB vs the 10-minute run (bounded by n_ctx, not length); prefix reuse 196 of 1031 chunk-prompt tokens (−14% prefill, greedy output identical), 46.9% of all map prompt tokens incl. repairs. SmolLM2-135M recall is 0 (loops the 50-item list to `n_predict`) — not a quality number. Oracle model: 23/23 planted action items of the 2-hour meeting kept exactly once, sorted, owners kept; recall(2 h map-reduce) = recall(short single pass) = 1.0.
- **Acceptance evidence:**
  - AC1: ⏳ test: [LLM-06/AC1]; device: docs/test-plans/device/LLM-06.md
  - AC2: ⏳ test: [LLM-06/AC2]; artifact: docs/long-transcripts.md; device: docs/test-plans/device/LLM-06.md
- **Decisions:** engineering defaults documented in `docs/long-transcripts.md` (tier chunk caps, 10% overlap, map `n_predict` ≤ n_ctx/4, dedupe thresholds 0.8 / same-`t` 0.5 — the same-`t` rule needs similarity too so two items stated on one line are not merged); default `map_schema` = `schema` (prose fields stay in the map output: they are the LLM reduce input). No technology choice → no ADR.
- **Follow-ups:** see below

## Follow-ups
- Codex review 2026-10-15 (chunker no-whitespace split + oversize-chunk failure fixed; eval still open): AC2 uses OracleLlmEngine; real-model long/short recall-gap eval needed. Chunker leaves oversized no-whitespace (e.g. Chinese) text as one piece (transcript_chunker.dart:169); split it and verify templated prompts fit before generation.
- **Wiring (pipeline/PRF owners):** pass `ExtractStep(longTranscript: LongTranscriptExtraction(extractor: MapReduceExtractor(engine: llmService, tokenizer: llmService), inputFor: …))` in `defaultSteps` once PRF-02 prompts and `ProfileRegistry.grammarsFor` are wired; `inputFor` = `LongExtractionInput(lines, ProfilePromptSource(profile) or the PRF-02 builder, MapReduceSpec.fromProfile(profile, grammars), tierForRam(...), paramsKey: '$modelId|${profile.id}@${profile.version}')`. Until then `ExtractStep` keeps its placeholder single prompt.
- **PRF-02:** replace `ProfilePromptSource` with the prompt builder; keep the map/reduce wording and the rule "nothing chunk-specific in the system prompt" (KV prefix reuse).
- **PRF-01 spec note:** `.agents/skills/vv-extraction-profiles/references/profile-spec.md` says `map_schema` defaults to "schema with prose fields removed"; the implementation keeps prose fields (they feed `llm_summarize`). Align the reference (docs/profile-spec.md does not state a default).
- **RenderStep:** `_actionItems` reads `text`, but the Meeting schema's items use `task` — action items of real extractions are not written to `action_items` (EXP/APP owner).
- **Resume across a context change:** after memory pressure the retry runs with half n_ctx, the plan changes and finished chunks are recomputed. Reusing partials whose chunks still fit the smaller budget would save work (LLM-12 candidate, not filed).
- **Grammar whitespace (LLM-05):** llama.cpp's converter allows pretty-printed JSON (`space` rule up to 20 chars); compact-only whitespace would cut map output tokens noticeably for long lists.
- **LLM-08 eval plan notes (proposed, not implemented):**
  1. Candidates per tier (Llama-3.2-1B/3B, Gemma-3-1B/4B, Qwen2.5/3 1.5–4B, Phi-4-mini; Q4_K_M and Q4_0) on the PRF-09 set split `short` (single pass) / `long` (≥ 60 min, map-reduce at the tier's n_ctx) per `docs/long-transcripts.md` §5; report recall/precision/owner accuracy/duplicate rate, schema validity, repair rate, invalid-chunk rate.
  2. Long-meeting ablations on the chosen default: chunk cap (1.5k/2k/3k/4k), overlap (0/10/20%), dedupe thresholds, map `n_predict` (n_ctx/4 vs /6) and prefix reuse on/off — pick per-tier caps by recall at fixed wall time; record in ADR-LLM-08.
  3. Speed on devices: map wall time for a 2-hour transcript (prefill tok/s with/without reuse, decode tok/s with grammar), peak footprint per chunk, thermal state after the run (QA-03 protocol); the AC "Free = 1B class" means the 1B model must reach the AC2 recall bound on its own.
  4. Prose reduce quality: summary faithfulness on long meetings (hallucination rate vs per-chunk summaries) for the summary preset vs greedy.
