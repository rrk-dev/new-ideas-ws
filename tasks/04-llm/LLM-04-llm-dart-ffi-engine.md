# LLM-04 — LLM Dart FFI Binding & Inference Service

**Workstream:** LLM | **Phase:** 2 | **Size:** L | **Depends on:** LLM-02, LLM-03 | **Source:** §5 Phase 2 (integrate llama.cpp FFI)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-ffi-bridge, vv-llm-inference, vv-testing

## Goal
A Dart `LlmEngine` that loads a GGUF model and runs prompts with streaming, cancellation and sampling control.

## Scope
- [ ] C bridge: load/unload model, create context (n_ctx, n_batch, KV type), tokenize, apply chat template (from GGUF metadata), generate with streaming token callback, cancel.
- [ ] Sampling params: temperature, top-p/k, min-p, repeat penalty, seed (deterministic mode for tests).
- [ ] Grammar / JSON-schema constrained decoding hook (used by LLM-05).
- [ ] Token counting API (needed for LLM-06 chunk planning).
- [ ] Run on native thread; stream tokens to Dart via ports; report prefill/decode speed to FND-07 metrics.

## Acceptance Criteria
- Streaming output appears in a debug screen; cancel stops within 500 ms.
- Same seed + prompt yields identical output (determinism test).
- Model unload returns RAM to baseline (± 50 MB).
