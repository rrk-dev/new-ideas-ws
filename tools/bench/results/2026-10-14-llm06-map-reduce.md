# LLM-06 map-reduce + KV prefix reuse — host results (2026-10-14)

**Setup:** Apple M3 Pro (18 GB), macOS 27.0.1, `native/build.sh host` (Release), llama.cpp
v0.6.0 (d812350) / ggml 0.26.0, bridge at branch `task/LLM-06-long-transcript-map-reduce`.
Model SmolLM2-135M-Instruct-Q8_0.gguf (sha256 `5a139571…6bba83`, `tools/ci/test-models.lock`).
**The host was heavily shared** (load average 55–80 from parallel agent builds/tests during all
runs), so wall times are noisy upper bounds; token counts are exact. Single runs unless noted.
Synthetic transcripts only (`app/test/helpers/synthetic_transcript.dart`, no real people).

## KV prefix reuse (ctest `vv_llm_prefix`, CPU backend, n_ctx 4096, greedy)

Map-style prompts: identical system prompt (~200 tokens, the meeting extraction instructions),
user turn = 30 transcript lines (≈ 10% overlap between consecutive chunks).

| Measure | Value |
|---|---|
| chunk prompt tokens | 1031 |
| tokens reused from KV (chunk B after A, C after B) | 196, 196 |
| prefill chunk B, full (median of 3) | 1498.6 ms |
| prefill chunk B, with reuse (median of 3) | 1285.8 ms (−14%; token expectation −19%) |
| greedy output with reuse = full prefill | yes (byte-identical, also after a cancelled run) |
| same prompt twice | n − 1 tokens reused |

An earlier run with 60-line chunks (1857 tokens, load average ≈ 70) measured reuse *slower* than
full (6.6 s vs 8.2 s) — contention noise; timing is therefore printed, not asserted, and the
deterministic token saving is the criterion. Expected saving = shared prefix / chunk prompt:
with the real meeting system prompt (~300–600 tokens incl. field list) and 2–4k-token chunks,
≈ 10–20% of map prefill. **Repair attempts reuse almost the whole chunk prompt** (the repair
prompt extends the original user prompt), which dominates in the run below.

## End-to-end map-reduce (`app/test/unit/extraction/long_transcript_host_test.dart`)

Real tokenizer, `vv_jsg` grammar for the meeting-shaped schema, `LlmService` on Metal, n_ctx 4096,
Low tier (chunk cap 2048), single-pass `n_predict` 768, built-in Meeting profile prompts.

```
LLM-06 host: ctx 4096; 10 min: mapReduce 32s recall 0.00; 2 h: 47564 tokens, 30 chunks
(29 invalid), valid true, 321s, recall 0.00; prefix reuse 35876/76548 prompt tokens (46.9%);
peak RSS 341 -> 361 MiB
```

- **Bounded memory:** peak RSS after the 2-hour run is 20 MiB above the 10-minute run (limit in
  the test: 150 MiB) — memory depends on n_ctx, not transcript length. Every call satisfied
  `prompt + n_predict ≤ n_ctx`.
- **Path completes:** 47.6k transcript tokens (≈ 11.6× the context) → 30 chunks → reduce → schema-
  valid output; no OOM; progress per chunk.
- **Quality (not meaningful for this model):** SmolLM2-135M fills `action_items` with repeated
  items until `n_predict` and truncates the JSON (29/30 chunks invalid after repair; recall 0).
  The LLM-05 host test passed with a 5-item schema; the 50-item meeting schema exceeds what a
  135M model can do. Real recall needs the 1B/3B defaults on the PRF-09 set (⏳, see
  `docs/long-transcripts.md` → Recall methodology).
- With the oracle model (unit tests) the chunk → map → reduce path keeps all 23 planted action
  items of the 2-hour meeting exactly once, in time order with owners, and 10-minute
  single-pass recall equals 2-hour map-reduce recall (1.0 / 1.0).
