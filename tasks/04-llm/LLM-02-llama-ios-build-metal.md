# LLM-02 — llama.cpp iOS Build (Metal)

**Workstream:** LLM | **Phase:** 2 | **Size:** M | **Depends on:** LLM-01, FND-06 | **Source:** §4.2
**Status:** review
**Skills:** vv-task-workflow, vv-native-build, vv-llm-inference, vv-benchmark-eval, vv-testing

## Goal
llama.cpp runs on iOS with full Metal offload.

## Scope
- [x] Add llama.cpp to the shared xcframework (shared ggml with whisper — FND-06). llama.cpp was already linked into `vv_native` (FND-06); the new `native/bridge/vv_llama.*` makes its code reachable (host dylib 6.5 → 9.6 MB, exports still only `vv_*`). `native/build.sh ios` flags re-checked against llama.cpp v0.6.0 `build-xcframework.sh`: same Metal/embed/BLAS/OpenMP/native settings; only difference is the FND-06 iOS 16.0 minimum (script: 16.4). iOS build itself not run (no Xcode) → device rows setup.
- [x] Full GPU layer offload (`n_gpu_layers = 99`), flash attention evaluation, KV-cache quantization (q8_0) to reduce RAM. Default `vv_llm_backend_params`: all layers (`-1`) + KQV on the GPU, flash attention AUTO, q8_0 K/V with automatic f16 retry (quantized V needs FA). Host evaluation in Completion Notes.
- [x] Memory-mapped model loading; verify behaviour under iOS jetsam limits (enable `com.apple.developer.kernel.increased-memory-limit` entitlement). `load_mode = LLAMA_LOAD_MODE_MMAP` (the pin removed `use_mmap`); `app/ios/Runner/Runner.entitlements` wired into all six Runner configs; peak `phys_footprint` reported by `vv_llm_bench`. Jetsam behaviour on a 6 GB iPhone: ⏳ device row.
- [x] CPU fallback for background execution. `LlmBackendPolicy` (iOS background ⇒ CPU) and a CPU mode that attaches **no** GPU device (empty `devices` list, `op_offload`/`offload_kqv` off); the bridge also falls back GPU → CPU when GPU load/context init fails.

## Acceptance Criteria
- Llama-3.2-3B Q4_K_M: ≥ 15 tok/s decode on iPhone 15 Pro; iPhone 11 numbers recorded (likely needs 1B model — LLM-07).
- No jetsam kills during a 4k-token prompt + 1k-token generation on a 6 GB device.

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist).

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/LLM-02-llama-ios-metal · **Date:** 2026-10-13
- **Summary:** LLM backend bridge `native/bridge/vv_llama.{h,cpp}` (+ `vv_error.h`): `vv_llm_default_backend_params`, `vv_llm_gpu_device_count/info`, `vv_cpu_perf_cores`, `vv_llm_bench` (load with GPU→CPU and q8_0→f16 fallback chain, synthetic prefill, greedy decode, peak footprint, determinism hash). Dart: `packages/vv_native` bindings (ffigen) + `VvNative.llmBench/gpuDevices/perfCores`; `app/lib/features/extraction/domain/llm_backend_policy.dart` (iOS foreground Metal / background CPU). iOS: `Runner.entitlements` (increased-memory-limit) in all Runner configs. On-device benchmark tests `app/integration_test/llm_ios_metal_test.dart` (+ `llm_bench_support.dart`). Host tests: ctest `vv_llm_backend` (model-free checks + SmolLM2 GPU/CPU/KV-fallback/determinism checks), `packages/vv_native` host FFI tests, `app/test/unit/extraction/llm_backend_policy_test.dart`, `llm_ios_config_test.dart`.
- **Host evaluation (Apple M3 Pro, Metal, llama.cpp v0.6.0, Llama-3.2-3B Q4_K_M, `llama-bench` n = 3):** flash attention off → on: pp512 802 → 837, tg128 43.0 → 43.4; at depth 2048 pp512 635 → 685, tg128 37.4 → 39.7 tok/s; q8_0 KV + FA at depth 2048: pp512 715, tg128 39.8 (no loss vs f16). 4164-token prompt + 1024 generated (LLM-01 `llm_spike`): peak `phys_footprint` 538 MiB q8_0 KV vs 814 MiB f16, decode 37.5 tok/s. ⇒ defaults FA auto + q8_0 KV. Host numbers only — not iPhone evidence.
- **Acceptance evidence:**
  - AC1: ⏳ test: [LLM-02/AC1]; device: docs/test-plans/device/LLM-02.md
  - AC2: ⏳ test: [LLM-02/AC2]; device: docs/test-plans/device/LLM-02.md
- **Decisions:** none new (runtime: ADR-LLM-01; build layout: ADR-FND-06)
- **Follow-ups:** see below

## Follow-ups
- LLM-04: build the streaming engine on `vv_llama.cpp`'s fallback chain; a job that starts in the foreground on Metal and is backgrounded mid-generation will get a failed GPU command buffer — checkpoint, reload with `use_gpu = 0` and resume (pipeline, FND-05).
- CI (owner FND-03/FND-06): run ctest with `VV_TEST_MODELS_DIR` so the `vv_llm_backend` model cases do not SKIP; let `tools/ci/check_bindings.py` scan `vv_llama.h` too (it reads only `vv_bridge.h`, which now includes it).
- `native/VERSIONS.md` size table (REL-03): host dylib grew from 6.5 MB to 9.6 MB once llama.cpp code became reachable; iOS slice size still ⏳ (Xcode).
