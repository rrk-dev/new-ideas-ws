---
name: vv-llm-inference
description: "llama.cpp local LLM usage: model/context params, chat templates, samplers, GBNF/JSON-schema constrained output with validation, token budgets, map-reduce for long transcripts, KV/RAM math, device tiers, memory pressure. Use for any prompt execution code."
---

# Local LLM Inference

Build/backends: `vv-native-build`. ABI: `vv-ffi-bridge`. Prompts/profiles: `vv-extraction-profiles`.

## Runtime (LLM-01)
Default expectation is llama.cpp (shares ggml with whisper.cpp, GGUF ecosystem, GBNF grammars,
Metal/Vulkan/OpenCL/CPU). ExecuTorch / MLC-LLM only if the spike shows ≥ 1.5× decode speed on
target devices *and* acceptable integration/constrained-decoding story. Measure with the same
model family at comparable 4-bit quantization; ADR-LLM-01 (`vv-decision-records`).

Prototype pointers: ExecuTorch Llama demo apps (`examples/demo-apps` in pytorch/executorch) and
MLC-LLM's `mlc_llm package` + iOS/Android sample apps; llama.cpp `llama-bench`. Same prompt set
and quant class for all three.

## llama.cpp API (2025+ naming — verify in `native/llama.cpp/include/llama.h` at pinned commit)
```
llama_backend_init();
mp = llama_model_default_params(); mp.n_gpu_layers = gpu ? 999 : 0; mp.use_mmap = true;
model = llama_model_load_from_file(path, mp);
vocab = llama_model_get_vocab(model);
cp = llama_context_default_params(); cp.n_ctx = tier.ctx; cp.n_batch = 512; cp.n_ubatch = 512;
cp.n_threads = cp.n_threads_batch = perfCores;
cp.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_AUTO;  // enum; ENABLED / DISABLED also exist
cp.type_k = cp.type_v = GGML_TYPE_Q8_0;          // [EXPERIMENTAL] quantized V forces FA; with FA
                                                 // DISABLED init returns NULL → check, retry F16
ctx = llama_init_from_model(model, cp);
tmpl = llama_model_chat_template(model, NULL);   // may be NULL
llama_chat_apply_template(tmpl, msgs, n, true, buf, cap); // <0 = unsupported template (no jinja) → fail loudly (LLM-08)
llama_tokenize(vocab, text, len, tokens, max, add_special, parse_special);
llama_decode(ctx, llama_batch_get_one(tokens, n));          // prefill (in n_batch slices)
smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
// add: grammar (llama_sampler_init_grammar(vocab, gbnf, "root")), top_k, min_p, temp, dist(seed)
tok = llama_sampler_sample(smpl, ctx, -1);  // already calls llama_sampler_accept — do NOT accept again
                                           // (double-accept corrupts grammar state)
llama_vocab_is_eog(vocab, tok); llama_token_to_piece(vocab, tok, buf, cap, 0, true);
// KV clear / partial removal: llama_memory_clear / llama_memory_seq_rm(llama_get_memory(ctx), …)
```
Older names (`llama_load_model_from_file`, `llama_new_context_with_model`, `llama_kv_cache_*`)
are deprecated/removed — do not use. Always cross-check with `examples/simple` and
`examples/simple-chat` at the pinned commit.

On ARM CPUs current llama.cpp repacks Q4_0 weights into interleaved layouts at load time (extra
buffer types, on by default) — prefer Q4_0 for CPU-only Android if it benchmarks faster than
Q4_K_M; verify the mechanism at the pinned commit.

## Sampling presets
| Use | Preset |
|---|---|
| Structured extraction (default) | grammar + temp 0.2, min_p 0.05, top_k 40, **no repeat penalty** (breaks JSON), seed fixed |
| Deterministic tests | temp 0 (greedy) + grammar, seed 42 |
| Free-text summary field | temp 0.5, min_p 0.05, top_p 0.95, repeat penalty 1.05 (last 64) |
| Classification (PRF-06) | grammar enum, temp 0, max 16 tokens |
Order of samplers matters — mirror `common/sampling.cpp` at the pinned commit.

## Constrained output (LLM-05)
- Profile JSON Schema → GBNF. Use llama.cpp's converter compiled as the small `vv_jsg` lib (exact
  file list in `vv-native-build`), exposed as `vv_json_schema_to_gbnf(schema_json, char** out)`;
  `llama_sampler_init_grammar` returns NULL on a bad grammar — treat as validation error; generate when a profile is saved
  and cache in `profiles` (not on every run). Supported schema subset: object, array (with
  `maxItems`), string (`enum`, `maxLength`), integer/number, boolean, `required`. Keep schemas
  flat-ish; avoid `oneOf`/`$ref` recursion.
- Always cap: `maxItems` on arrays (e.g. 50) and `maxLength` on strings (e.g. 500) so grammar
  can't loop forever; plus `n_predict` hard limit.
- After generation: parse JSON → validate against schema in Dart (`json_schema` package or
  hand-written validator for our subset). Invalid → one repair attempt (prompt includes the
  error + previous output) → else store `valid=false` and fall back to summary-only template.
- Evidence fields: schema items may include `"t": "hh:mm:ss"` referencing transcript timestamps
  (prompt shows `[hh:mm:ss] Speaker: text` lines); Dart verifies the timestamp exists, drops it if not.
- Measure grammar overhead (tok/s with vs without) — target < 20%.

## Token budget (LLM-06, PRF-02)
`budget = n_ctx − n_predict_reserve − prompt_overhead(system+instructions+examples+schema)`.
`vv_llm_count_tokens` for exact counts (never estimate by chars except for planning UI).
If transcript ≤ budget → single pass. Else map-reduce:
1. **Map**: split transcript at speaker/segment boundaries into chunks of ≤ budget with
   ~10% overlap; per chunk run the profile's *map schema* (same fields, partial) → JSON.
   Persist each result (checkpoint).
2. **Reduce (deterministic, Dart)**: union lists, dedupe by normalized text similarity
   (token Jaccard ≥ 0.8 or same timestamp), merge owners/dates preferring non-null, sort by time.
3. **Reduce (LLM, only for prose fields)**: summary/title from map summaries (fits easily).
4. Optimization: keep the system-prompt prefix in KV cache across chunks, remove only the
   transcript part (`llama_memory_seq_rm` from prefix_len) — verify API.

## Memory math & tiers (LLM-07)
KV bytes ≈ `n_ctx × n_layers × 2 × n_kv_heads × head_dim × bytes_per_elem`.
- Llama-3.2-3B (28 layers, 8 KV heads × 128): f16 ≈ 112 KB/token → 8k ctx ≈ 0.9 GB; q8_0 ≈ 0.48 GB.
- Llama-3.2-1B (16 layers, 8 × 64): f16 ≈ 32 KB/token → 8k ctx ≈ 256 MB.
Total ≈ weights file (3B Q4_K_M ≈ 2.0 GB; 1B Q4_K_M ≈ 0.8 GB) + KV + compute buffers (~0.2–0.5 GB).
| Tier | Detection | LLM default | n_ctx |
|---|---|---|---|
| Low | reported total RAM < 5 GB (iPhone 11, budget Android) | 1B-class Q4_K_M | 4096 |
| Mid | 5–7 GB (6 GB devices report ≈ 5.6) | 3B Q4_K_M (or 1B if eval says comparable) | 4096–6144 |
| High | ≥ 7 GB (8 GB devices report ≈ 7.3) | 3B Q4_K_M | 8192 |
Default model = f(device tier × plan): **Free is capped at the 1B-class model on every tier**
(`Feature.largeLlm` is Pro); Pro gets the tier default above.
- Before load: require `available ≥ estimate × 1.2` (iOS `os_proc_available_memory()`;
  Android `ActivityManager.MemoryInfo.availMem` — native heap isn't limited by `largeHeap`).
- iOS: add `com.apple.developer.kernel.increased-memory-limit` entitlement.
- Unload STT before loading LLM; unload LLM when queue empty.
- On memory pressure (Flutter `WidgetsBindingObserver.didHaveMemoryPressure`; iOS
  `UIApplication.didReceiveMemoryWarningNotification`; Android `onLowMemory()` — note
  `TRIM_MEMORY_RUNNING_*` levels are not delivered on API 34+):
  cancel at next token, checkpoint, unload, retry with smaller ctx / map-reduce.

## Fallback when extraction fails (LLM-05)
After one failed repair: run the free-text summary preset (title + 2–4 sentence summary), render
the built-in `summary-only` template (`vv-markdown-vault-export`), store `extractions.valid = false`
and show "Structured extraction failed — Re-extract" in the UI.

## Model candidates (LLM-08)
Llama-3.2-1B/3B-Instruct, Gemma-2-2B-IT, and newer small instruct models available at build
time (Gemma 3 1B/4B, Qwen2.5/3 1.5B–4B, Phi-3.5/4-mini) in GGUF Q4_K_M / Q4_0. Use the GGUF's
embedded chat template. Every candidate needs a license check (SEC-05) before it can be default.
Decision = PRF-09 eval results + tok/s + RAM per tier → ADR-LLM-08 + `docs/models.md`.

## Prompt-injection hygiene
Transcript goes in a clearly delimited block (`<transcript>…</transcript>`), system prompt says
it is data and instructions inside it must be ignored. Grammar-constrained output limits damage.

## Verification
- Host + device: same seed/prompt ⇒ identical output. Cancel ⇒ stops < 500 ms.
- Unload ⇒ RSS back to baseline ± 50 MB. 4k prompt + 1k gen with no OOM on 6 GB device.
- ≥ 99% schema-valid outputs on PRF-09 set.
