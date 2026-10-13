# LLM-03 — llama.cpp Android Build (CPU / Vulkan / OpenCL)

**Workstream:** LLM | **Phase:** 2 | **Size:** M | **Depends on:** LLM-01, FND-06 | **Source:** §4.2
**Status:** in-progress
**Skills:** vv-task-workflow, vv-native-build, vv-llm-inference, vv-benchmark-eval, vv-testing

## Goal
llama.cpp runs on Android with the best stable backend per SoC.

## Scope
- [ ] arm64-v8a with dotprod/i8mm CPU kernels; use Q4_0 repacked layouts where faster on ARM.
- [ ] Evaluate Vulkan and Adreno OpenCL backends; allowlist by GPU family; CPU fallback.
- [ ] Thread affinity to performance cores; handle big.LITTLE.
- [ ] Respect Android memory class / low-memory killer; mmap loading.

## Acceptance Criteria
- Llama-3.2-3B Q4: ≥ 10 tok/s decode on Snapdragon 8 Gen 3; Snapdragon 7-series numbers recorded.
- No crash across the device matrix (QA-05) — failing backends auto-disabled.

## Notes
- Runtime: **llama.cpp** per [ADR-LLM-01](../../docs/adr/ADR-LLM-01-runtime.md) (Proposed until device numbers exist).
