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

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist). `use_mmap` no longer exists at the pin (use `load_mode`); llama.h also has the new `llama_batch_ext`/`llama_process` API next to `llama_decode`.

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


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** FAIL
- **Gates:** format ✅ (387 files, 0 changed) · analyze ✅ (zero issues) · Flutter tests ✅ (785 passed, 24 skipped; coverage 93.3%, gate 80%) · pytest ✅ (66 passed) · native host ✅ (fresh native/build.sh host; model-backed ctest 21 passed, 2 explicitly skipped) · egress ✅ · recording policy ✅ · tasks validate ✅ (85 tasks, 0 problems) · CI run: local. No Xcode/NDK/mobile SDKs; no mobile/device reruns.
- **Acceptance criteria:**
  - AC1: ✅ tagged debug widget/real host FFI tests assert partial streaming, CancelledFailure and <500 ms. ❌ background during asynchronous load is unsafe (reproduced below). Device decode/prefill cancel remains ⏳.
  - AC2: ✅ native and Dart host tests assert identical same-seed output and different sampled output with another seed.
  - AC3: ✅ host native/Dart unload loops enforce <50 MiB above a warm baseline; phone memory rows remain ⏳.
- **Mutation sanity check:** Disabled _output.write(t) in the debug screen: tagged `[LLM-04/AC1]` streaming widget test failed; restored with git checkout.
- **Adversarial checks:** All real host engine C/Dart tests passed (busy, bad grammar, cancellation, deterministic generation, memory). Temporary external Flutter test delayed FakeLlmRuntime.load, backgrounded the service before completion, then resumed loading: the generated run still used GPU (expected false, actual true).
- **Device evidence:** Reviewed every row in `docs/test-plans/device/LLM-04.md`. Result/date/tester cells are unfilled; no physical run is represented as PASS. The user explicitly permits a provisional verifier PASS with these rows pending.
- **Skill/rule compliance:** Read AGENTS.md, verifier prompt, workflow/verification skills and all task-listed skills; reviewed the merged implementation at main (no unmerged task diff). Pins checked against local headers. RTK.md is referenced by the supplied instructions but absent. Product code/tests unchanged after temporary mutations; no criteria weakened, GitHub API/gh, pushes, git config edits or model commits.
- **Issues found:**
  1. `LlmService.onBackgrounded()` returns when `_session == null`, including while `_loading` is active. `_ensureSession()` later installs the in-flight GPU session and generation starts without rechecking background state. Repro: delayed runtime load → service.generate → background flag false + onBackgrounded → complete load → session.usedGpu is true. Track lifecycle during load and cancel/dispose/reload or pause before generation. This violates the no-GPU-in-background rule.

## Rework
- **Agent:** Claude Code · **Branch:** task/LLM-04-rework-1 (from origin/integration/wave-4) · **Date:** 2026-10-14 — answers the Codex FAIL report above (report left unchanged).
- **Issue 1 (GPU generation after backgrounding during an asynchronous load):** reproduced first with failing tests, then fixed in
  `app/lib/features/extraction/domain/llm_service.dart`:
  - `onBackgrounded()` now always sets the force-CPU flag — also when no session exists yet or a load is in flight (before, it
    returned early on `_session == null`). The same gap made `ActiveLlmEngine._current()`'s `if (!_foreground) service.onBackgrounded()`
    a no-op for a service created while backgrounded; that path is now covered too.
  - `_ensureSession()` re-checks after every (possibly shared) load: a GPU session that finished loading after the app was
    backgrounded is disposed unused and the model is reloaded on the CPU; every caller that awaited the same in-flight load
    re-checks, so no caller (generate or token counting) ever receives a GPU session while backgrounded. Generation starts
    synchronously after `_ensureSession` returns, so there is no further await between the check and `session.generate`.
  - Tests (`app/test/fakes/fake_llm_runtime.dart` gained `loadDelay` to hold the load open):
    `[LLM-04/AC1] backgrounded while the GPU model is still loading -> no GPU generation; the run uses a CPU session`
    (the verifier's repro: delayed load → generate → background → complete load; asserts the only session that ran is CPU and the
    GPU session was disposed), `[LLM-04/AC1] backgrounded before any load -> the first load is CPU; the next foreground load uses the GPU`,
    `[LLM-04/AC1] concurrent callers awaiting a GPU load that finishes in the background never get the GPU session`
    (`app/test/unit/extraction/llm_service_test.dart`), and `[LLM-04/AC1] a service created while backgrounded with a GPU policy
    loads on the CPU` (`app/test/unit/pipeline/active_engines_test.dart`).
  - Mutation check: with the original `llm_service.dart` restored, `--plain-name "LLM-04/AC1"` on those two files → 4 failed
    (`Expected: false, Actual: <true>` for `usedGpu`); with the fix → 4 passed.
- **Behaviour note:** a loaded CPU session is kept after returning to the foreground (unchanged); the next load uses the GPU again.
  No new product decision.
- **Still needed (⏳):** device rows in `docs/test-plans/device/LLM-04.md` (prefill/decode cancel < 500 ms on iPhone 11 +
  Snapdragon 7-series, unload deltas, the "press Home during a long generation" iOS row, and a new row: press Home while the model is still loading).
