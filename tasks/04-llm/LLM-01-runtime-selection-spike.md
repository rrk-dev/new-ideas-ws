# LLM-01 — LLM Runtime Selection Spike (llama.cpp vs ExecuTorch vs MLC-LLM)

**Workstream:** LLM | **Phase:** 2 (Week 4) | **Size:** M | **Depends on:** FND-06 | **Source:** §3.1.3, §4.2 (open decision)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-llm-inference, vv-decision-records, vv-benchmark-eval

## Goal
Choose one inference runtime for v1 based on measured data, not assumption.

## Scope
- [~] Prototype each runtime with Llama-3.2-3B-Instruct (4-bit) on one iOS + one Android device. deferred → LLM-02, LLM-03 (llama.cpp device rows; no device/SDK available — llama.cpp prototyped on the host instead) and LLM-09 (ExecuTorch device prototype, only if an ADR-LLM-01 re-open trigger fires)
- [x] Compare: prefill & decode tokens/sec, peak RAM, model file size/format, load time, constrained-decoding/grammar support, Flutter/FFI integration effort, license, community health.
- [x] Assess sharing ggml with whisper.cpp (favors llama.cpp: single dependency, GGUF ecosystem, GBNF grammars).
- [x] Record that NPU/Core ML LLM paths (master plan §4.2) are out of scope for v1 unless the spike shows a clear win (NNAPI deprecated; Core ML LLM conversion immature for GGUF models).
- [x] Write ADR-LLM-01 with decision. **Default expectation: llama.cpp** unless a competitor is ≥ 1.5× faster on target devices.

## Acceptance Criteria
- Benchmark table + ADR-LLM-01 committed; subsequent LLM tasks reference the chosen runtime.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/LLM-01-runtime-spike · **Date:** 2026-10-13
- **Summary:** Runtime decision ADR (llama.cpp, Proposed) with a weighted comparison of llama.cpp / ExecuTorch / MLC-LLM, host benchmark of llama.cpp at the FND-06 pin (Llama-3.2-1B/3B Q4_K_M + 3B Q4_0 + SmolLM2, Metal vs CPU, f16 vs q8_0 KV, with/without GBNF; n = 3, median/min/max, sha256 of every model) and spike code `tools/spikes/LLM-01-runtime/` (`build.sh`, `llm_spike.cpp`, `run.py`, `meeting.gbnf`). ExecuTorch and MLC-LLM were assessed from their official repos/docs at v1.5.1 / v0.26.dev0 (not built: no Xcode/NDK/devices). LLM-02…LLM-08 `## Notes` and `tasks/README.md` Open Decisions reference ADR-LLM-01.
- **Acceptance evidence:**
  - AC1: ⏳ artifact: docs/adr/ADR-LLM-01-runtime.md; artifact: tools/bench/results/2026-10-13-llm01-host.md; artifact: tools/spikes/LLM-01-runtime/llm_spike.cpp; device: docs/test-plans/device/LLM-01.md
- **Decisions:** ADR-LLM-01-runtime (Proposed — host-measured only)
- **Follow-ups:** LLM-09 (proposed below)

## Follow-ups
- LLM-09 (proposed, not filed): ExecuTorch (v1.5.x, XNNPACK/Core ML) device prototype with Llama-3.2-3B 4-bit — only if LLM-02 or LLM-03 misses its decode target by > 1.5× (ADR-LLM-01 re-open trigger).
- Re-run `tools/spikes/LLM-01-runtime/run.py` on an idle host: the CPU rows were measured while parallel agents saturated all cores.
