# LLM-01 — LLM Runtime Selection Spike (llama.cpp vs ExecuTorch vs MLC-LLM)

**Workstream:** LLM | **Phase:** 2 (Week 4) | **Size:** M | **Depends on:** FND-06 | **Source:** §3.1.3, §4.2 (open decision)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-llm-inference, vv-decision-records, vv-benchmark-eval

## Goal
Choose one inference runtime for v1 based on measured data, not assumption.

## Scope
- [ ] Prototype each runtime with Llama-3.2-3B-Instruct (4-bit) on one iOS + one Android device.
- [ ] Compare: prefill & decode tokens/sec, peak RAM, model file size/format, load time, constrained-decoding/grammar support, Flutter/FFI integration effort, license, community health.
- [ ] Assess sharing ggml with whisper.cpp (favors llama.cpp: single dependency, GGUF ecosystem, GBNF grammars).
- [ ] Record that NPU/Core ML LLM paths (master plan §4.2) are out of scope for v1 unless the spike shows a clear win (NNAPI deprecated; Core ML LLM conversion immature for GGUF models).
- [ ] Write ADR-LLM-01 with decision. **Default expectation: llama.cpp** unless a competitor is ≥ 1.5× faster on target devices.

## Acceptance Criteria
- Benchmark table + ADR-LLM-01 committed; subsequent LLM tasks reference the chosen runtime.
