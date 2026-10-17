# Long transcripts — chunking + map-reduce extraction (LLM-06)

A 60-minute meeting is about 9–12k tokens, a 2-hour one 20–40k. Mobile context budgets are
4–8k (LLM-07 tiers). This page describes how Lumen extracts structured data from transcripts
that do not fit the context, and how recall is compared against single-pass extraction.

Code: `app/lib/features/extraction/domain/long_transcript/`
(`token_budget.dart`, `transcript_chunker.dart`, `partial_reducer.dart`,
`extraction_prompts.dart`, `map_reduce_extractor.dart`); pipeline hook `ExtractStep(longTranscript:)`
in `app/lib/features/pipeline/data/steps/extract_step.dart`; KV prefix reuse
`vv_gen_params.reuse_prefix` in `native/bridge/vv_llama_engine.cpp`.

## 1. Plan (exact token counts)

`LlmService` implements `LlmTokenizer` (`vv_llm_count_tokens` on the loaded model, chat template
applied). `contextWindow` is the **effective** n_ctx after the LLM-07 memory gate
(`planLlmLoad` may halve it on low RAM; memory pressure halves it again).

```
single limit = n_ctx − n_predict − 64 (safety)
templated single prompt (with examples)  ≤ limit → singlePass
templated single prompt (no examples)    ≤ limit → singlePassNoExamples
otherwise                                         → mapReduce
  map n_predict = min(profile n_predict, max(256, n_ctx / 4))
  chunk budget  = n_ctx − map n_predict − map prompt overhead − 64
  chunk tokens  = min(chunk budget, tier cap)      tier cap: Low 2048 · Mid 3072 · High 4096
  overlap       = 10% of chunk tokens
  n_ctx too small for a 384-token chunk → OutOfMemoryFailure (pipeline: smaller model / retry)
```

The tier cap is an engineering default (bounded prefill time and compute buffers on slow
devices; small models lose items in the middle of long prompts). Tune it with the recall
methodology below (LLM-08 follow-up).

## 2. Map

- Lines are transcript segments rendered `[hh:mm:ss] Speaker: text`; a segment is never split
  (segments longer than a third of a chunk are pre-split into word pieces with the same
  timestamp).
- A chunk ends at the last speaker change within its final 20% when there is one (the next
  chunk starts with a new turn), else at the last segment that fits.
- The next chunk repeats the previous chunk's last segments up to the overlap budget, so an
  item stated across a boundary is seen whole at least once.
- Each chunk block is recounted exactly; if any chunk exceeds the budget (BPE merges across
  joined lines), the chunker re-runs with a 10% smaller target (≤ 3 times).
- Each chunk runs the profile's `map_schema` (default: `schema` — same fields, partial) with its
  grammar, the LLM-05 validator, one repair attempt and evidence cleanup against **that chunk's**
  timestamps. A chunk that stays invalid contributes nothing (no per-chunk summary fallback).
- **Checkpoint per chunk** (`jobs.checkpoint`, atomically with the progress update):
  `{mapReduce: {paramsHash, chunks: [{s,e,o}], results: {"<i>": partial | null}}}`.
  `paramsHash` = FNV-1a of model/profile key, n_ctx, map n_predict, transcript hash and the chunk
  boundaries — a resume with another model, profile version, context or an edited transcript
  starts over. Partials are user content: they live only in the encrypted DB and are never
  logged.
- **Progress**: one unit per map chunk + one per prose field; tokens inside a chunk move the bar
  within its unit.

## 3. Reduce

Deterministic, in Dart (`PartialReducer`), per top-level field with the profile's `reduce`
strategy (`docs/profile-spec.md`):

| Strategy | Rule |
|---|---|
| `union_dedupe` | union in chunk order; duplicate when token Jaccard ≥ 0.8, or same evidence `t` and Jaccard ≥ 0.5 (overlap re-extractions are often reworded); duplicates merge (null/empty fields filled from the later copy); lists of objects stable-sorted by `t` (else the chunk start); capped at `maxItems` |
| `first_non_null` | first non-null, non-empty value in time order |
| `max` / `min` | over non-null numbers, or strings (ISO dates sort lexically) |
| `llm_summarize` | the only LLM step: the non-empty per-chunk values in order → one free-text call (summary preset), cleaned ("Here is…", quotes; titles keep the first line) and clipped to `maxLength`. One value → used as is; none → null. Parts that do not fit one prompt are reduced hierarchically (halves, then the two results) |

The merged object is conformed to `schema` (missing lists → `[]`, nullable → null) and validated;
all map chunks invalid → `valid = false` with a summary-only fallback over the first chunk
(LLM-05 rule).

## 4. KV prefix reuse

Every map and reduce call of one extraction has the identical system prompt (fixed text +
instructions + field descriptions); chunk-specific text starts in the user turn. With
`LlmRequest.reusePrefix` the engine keeps the KV entries of the longest token prefix shared with
the previous run (`llama_memory_seq_rm(mem, 0, keep, -1)`) and prefills only the rest. It falls
back to a full clear when partial removal is unsupported (recurrent models) or early positions
were pruned (`llama_memory_seq_pos_min ≠ 0`, SWA caches), and after a cancelled/failed decode.
Greedy output with reuse is byte-identical to a full prefill on the CPU backend (ctest
`vv_llm_prefix`); GPU backends may differ in the last float bits.

Saving = shared prefix / chunk prompt: with the meeting profile's ~300–600-token system prompt
and 2–4k-token chunks, about 10–20% of map prefill. Measurements: `tools/bench/results/2026-10-14-llm06-map-reduce.md`.

## 5. Recall methodology (AC2)

Goal: *action-item recall on long meetings (map-reduce) within 10 points of single-pass recall
on short meetings*, with the default model per tier.

1. **Dataset** (PRF-09, `tools/bench/eval/meeting/`): tag every case `short` (≤ 20 min, fits the
   Low-tier context in one pass) or `long` (≥ 60 min, map-reduce on every tier). Long cases are
   real-Whisper transcripts of scripted multi-speaker dialogues (≥ 10 cases, ≥ 15 action items
   each, items spread over the whole recording, some stated across what will be chunk
   boundaries, some repeated/reworded later in the meeting, a few with the owner only named in
   a later turn). Hand-written `expected.json`.
2. **Matching** (PRF-09 list rule): one-to-one greedy by score, token-set ratio ≥ 0.8 or Jaccard
   ≥ 0.6 on `task`; recall = matched / expected, precision = matched / extracted; report owner
   accuracy on matched items and the duplicate rate (extracted items matching an already matched
   expected item).
3. **Runs**: same model file, same seed, temperature 0 (deterministic preset), n_ctx per tier
   (4096 / 6144 / 8192), ≥ 3 runs (medians). Run `short` single-pass and `long` map-reduce; also run
   `long` single-pass on a host with a 32k context as an upper-bound reference.
4. **Criterion**: `recall(long, map-reduce) ≥ recall(short, single) − 0.10` per tier; also track
   precision (dedupe must not fall below single-pass precision − 0.05) and schema validity
   (≥ 99%, LLM-05).
5. **Ablations** (tune defaults, record in the LLM-08 ADR): chunk cap 1.5k/2k/3k/4k, overlap
   0/10/20%, dedupe thresholds (0.7/0.8/0.9; same-`t` 0.4/0.5/0.6), prefix reuse on/off
   (quality must be identical within run-to-run noise).

**Status:** the mechanics are verified on the host with an oracle model (recall 1.0 both ways —
`[LLM-06/AC2]` tests prove the chunk/merge path loses and duplicates nothing) and end-to-end with
SmolLM2-135M (path only; its recall is not a quality number). Real numbers ⏳ need the PRF-09
long-meeting set and the LLM-08 default model.
