# LLM-01 — LLM Runtime Selection Spike (llama.cpp vs ExecuTorch vs MLC-LLM)

**Workstream:** LLM | **Phase:** 2 (Week 4) | **Size:** M | **Depends on:** FND-06 | **Source:** §3.1.3, §4.2 (open decision)
**Status:** review
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


## Verification Report
- **Verifier:** Codex · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (387 files, 0 changed) · analyze ✅ (zero issues) · Flutter tests ✅ (785 passed, 24 skipped; coverage 93.3%, gate 80%) · pytest ✅ (66 passed) · native host ✅ (fresh native/build.sh host; model-backed ctest 21 passed, 2 explicitly skipped) · egress ✅ · recording policy ✅ · tasks validate ✅ (85 tasks, 0 problems) · CI run: local. No Xcode/NDK/mobile SDKs; no mobile/device reruns.
- **Acceptance criteria:**
  - AC1: ✅ ADR-LLM-01, host benchmark table/raw JSON and spike source exist; later LLM task Notes reference llama.cpp. Recomputed all 16 raw decode medians, verified three runs and matching output hashes per row against the table. Target-device comparisons remain explicitly Proposed/⏳.
- **Mutation sanity check:** Temporarily removed ADR-LLM-01-runtime.md: tasks.py verify detected the missing AC1 artifact; restored with git checkout. This is an artifact criterion with no tagged runtime test, not a claim that the spike was benchmarked anew.
- **Adversarial checks:** Read runtime spike, weighted decision, comparator limitations and re-open triggers. Host table is internally consistent; competitor device prototypes were explicitly deferred. No competitor performance win is established.
- **Device evidence:** Reviewed every row in `docs/test-plans/device/LLM-01.md`. Result/date/tester cells are unfilled; no physical run is represented as PASS. The user explicitly permits a provisional verifier PASS with these rows pending.
- **Skill/rule compliance:** Read AGENTS.md, verifier prompt, workflow/verification skills and all task-listed skills; reviewed the merged implementation at main (no unmerged task diff). Pins checked against local headers. RTK.md is referenced by the supplied instructions but absent. Product code/tests unchanged after temporary mutations; no criteria weakened, GitHub API/gh, pushes, git config edits or model commits.
- **Issues found:** none in the verified host implementation; physical acceptance remains pending.
- **Pending for done:** LLM-01: FAIL AC1: still pending (⏳) — cannot be done | LLM-01: FAIL AC1: device row in docs/test-plans/device/LLM-01.md has no PASS result with a date | LLM-01: FAIL dependency FND-06 is not done | LLM-01: FAIL FND-03 (CI / test framework) must be done before any non-bootstrap task | LLM-01: FAIL QA-01 (CI / test framework) must be done before any non-bootstrap task | refusing to set LLM-01 to done: 5 problem(s) (see vv-task-verify)
