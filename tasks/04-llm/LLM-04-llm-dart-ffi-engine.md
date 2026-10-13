# LLM-04 — LLM Dart FFI Binding & Inference Service

**Workstream:** LLM | **Phase:** 2 | **Size:** L | **Depends on:** LLM-02, LLM-03 | **Source:** §5 Phase 2 (integrate llama.cpp FFI)
**Status:** review
**Skills:** vv-task-workflow, vv-ffi-bridge, vv-llm-inference, vv-testing

## Goal
A Dart `LlmEngine` that loads a GGUF model and runs prompts with streaming, cancellation and sampling control.

## Scope
- [x] C bridge: load/unload model, create context (n_ctx, n_batch, KV type), tokenize, apply chat template (from GGUF metadata), generate with streaming token callback, cancel. `native/bridge/vv_llama_engine.cpp`: `vv_llm_create/get_info/count_tokens/apply_chat_template/generate_async/cancel/destroy`, `vv_free_string`, `vv_proc_memory`; context params via the LLM-02/03 `vv_llm_backend_params` (GPU→CPU, q8_0→f16 fallbacks).
- [x] Sampling params: temperature, top-p/k, min-p, repeat penalty, seed (deterministic mode for tests). `vv_gen_params` + `vv_llm_default_gen_params` (extraction preset); Dart presets `LlmGenParams.extraction/deterministic/summary/classification`, app-level `LlmSampling`/`LlmPreset` on `LlmRequest`.
- [x] Grammar / JSON-schema constrained decoding hook (used by LLM-05). `vv_gen_params.grammar` (GBNF, parse failure → `VV_E_INVALID_ARG` synchronously); JSON-schema→GBNF is LLM-05.
- [x] Token counting API (needed for LLM-06 chunk planning). `vv_llm_count_tokens` / `VvLlm.countTokens` / `LlmSession.countTokens`.
- [x] Run on native thread; stream tokens to Dart via ports; report prefill/decode speed to FND-07 metrics. One worker `std::thread` per generation, `NativeCallable.listener` text/done callbacks (batched every 4 tokens / 50 ms, UTF-8-safe, `n_chunks` in done for cross-port ordering), atomic cancel + llama abort callback; `LlmService.onStats` → `LlmRunStats` (prompt/gen tokens, prefill/decode durations) for the FND-07 `JobMetrics` writer.

## Acceptance Criteria
- Streaming output appears in a debug screen; cancel stops within 500 ms.
- Same seed + prompt yields identical output (determinism test).
- Model unload returns RAM to baseline (± 50 MB).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/LLM-04-llm-ffi-engine (stacked on task/LLM-03-llama-android → task/LLM-02-llama-ios-metal) · **Date:** 2026-10-13
- **Summary:** Native streaming engine `native/bridge/vv_llama_engine.cpp` (+ `vv_llama_internal.h`, API in `vv_llama.h`); Dart FFI `packages/vv_native/lib/src/llm_engine.dart` (`VvLlm.load/generate/cancel/destroy`, `LlmGenParams` presets); app `LlmEngine` implementation `app/lib/features/extraction/domain/llm_service.dart` over `LlmRuntime` (`llm_runtime.dart`; real `data/ffi_llm_runtime.dart`, fake `test/fakes/fake_llm_runtime.dart`); `LlmRequest` gained `systemPrompt`, `sampling` (`LlmPreset`), `templated`. Backgrounding hook: `LlmService.onBackgrounded()` stops a running GPU generation and re-runs the request on a CPU session (also on a mid-run `VV_E_BACKEND` from the GPU), `onRestart` lets UIs drop partial text; `dev_llm_engine.dart` wires it to `AppLifecycleListener` in the dev flavor. Dev-only debug screen `presentation/llm_debug_screen.dart` (Settings → "LLM debug (dev)", `--dart-define=VV_DEV_LLM_MODEL=…`). Device tests `app/integration_test/llm_engine_test.dart`.
- **Host numbers (M3 Pro, SmolLM2-135M):** cancel → done 0.1–1.3 ms (C) / < 500 ms incl. 50 ms CancelToken polling (Dart end-to-end); unload: first load leaves ~90 MiB of one-time process state (Metal device + compiled pipelines), every further load/generate/unload cycle returns within 3 MiB of that warm baseline (GPU and CPU).
- **Acceptance evidence:**
  - AC1: ⏳ test: [LLM-04/AC1]; device: docs/test-plans/device/LLM-04.md
  - AC2: ✅ test: [LLM-04/AC2]
  - AC3: ⏳ test: [LLM-04/AC3]; device: docs/test-plans/device/LLM-04.md
- **Decisions:** none new (ADR-LLM-01/03)
- **Follow-ups:** see below

## Follow-ups
- Metal prefill cancel latency: the llama abort callback only interrupts CPU graphs; if the `[LLM-04/AC1]` prefill row exceeds 500 ms on iPhone 11, decode prompts in smaller slices (e.g. 128 tokens) when a run is cancellable.
- Production wiring of `llmEngineProvider` (active model from MDL-*, tier/plan defaults, Android GPU guard) — LLM-07.
- `JobMetrics` writing from `LlmService.onStats` in the pipeline extract step (FND-05 / PRF-02 owner).
