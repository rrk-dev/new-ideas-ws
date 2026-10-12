# LLM-02 — llama.cpp iOS Build (Metal)

**Workstream:** LLM | **Phase:** 2 | **Size:** M | **Depends on:** LLM-01, FND-06 | **Source:** §4.2
**Status:** todo
**Skills:** vv-task-workflow, vv-native-build, vv-llm-inference, vv-benchmark-eval, vv-testing

## Goal
llama.cpp runs on iOS with full Metal offload.

## Scope
- [ ] Add llama.cpp to the shared xcframework (shared ggml with whisper — FND-06).
- [ ] Full GPU layer offload (`n_gpu_layers = 99`), flash attention evaluation, KV-cache quantization (q8_0) to reduce RAM.
- [ ] Memory-mapped model loading; verify behaviour under iOS jetsam limits (enable `com.apple.developer.kernel.increased-memory-limit` entitlement).
- [ ] CPU fallback for background execution.

## Acceptance Criteria
- Llama-3.2-3B Q4_K_M: ≥ 15 tok/s decode on iPhone 15 Pro; iPhone 11 numbers recorded (likely needs 1B model — LLM-07).
- No jetsam kills during a 4k-token prompt + 1k-token generation on a 6 GB device.
