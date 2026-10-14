# ADR-LLM-01 — On-device LLM runtime: llama.cpp (vs ExecuTorch, MLC-LLM)

- **Status:** Proposed (host-measured only; target-device rows ⏳ in `docs/test-plans/device/LLM-01.md`)
- **Date:** 2026-10-13
- **Task:** LLM-01
- **Deciders:** Claude Code (implementer); pending independent verifier + device numbers
- **Supersedes:** —

## Context
VaultVoice extracts structured JSON from meeting transcripts with a local LLM on iOS 16+ and
Android 26+ arm64. Hard constraints (AGENTS.md): fully offline, no telemetry, Dart talks only to
the `native/bridge` C ABI, STT and LLM never resident together, Free tier capped at a 1B-class
model, license must allow commercial redistribution. Extraction output must be schema-valid
(LLM-05), which makes **constrained decoding** a first-class requirement, not a nice-to-have.
whisper.cpp is already integrated (FND-06) on a single ggml shared with llama.cpp.

The task's default expectation is llama.cpp unless a competitor is **≥ 1.5× faster on target
devices**.

## Options
1. **llama.cpp** (pinned `v0.6.0` → `d812350`, MIT) — GGUF, ggml backends Metal / CPU (NEON,
   dotprod, i8mm, KleidiAI) / Vulkan / OpenCL (Adreno), GBNF grammars + JSON-schema→GBNF.
2. **ExecuTorch** (`v1.5.1`, 2026-09-23, BSD-3-Clause) — PyTorch `torch.export` → `.pte`;
   backends XNNPACK (CPU), Core ML, MPS, Vulkan, Qualcomm QNN, MediaTek; C++ LLM runner
   (`extension/llm/runner`) with Swift/Java bindings.
3. **MLC-LLM** (no GitHub release since `v0.1.dev0`; tags up to `v0.26.dev0`, last commit
   2026-10-06, Apache-2.0) — Apache TVM compiles a model-specific library per model + quant
   (`q4f16_1`); Swift (`MLCSwift`) / Android (`mlc4j`) SDKs with an OpenAI-style API; JSON mode
   via XGrammar.
4. *(rejected without spike)* NPU paths — Core ML LLM conversion, Qualcomm QNN / NNAPI. See
   "Out of scope".

## Criteria (weights fixed before measuring)
| Criterion | Weight | How measured |
|---|---|---|
| Decode + prefill speed on target devices | 30% | device rows (⏳); host numbers as sanity only |
| Peak RAM / model size (jetsam / LMK headroom) | 15% | `phys_footprint` peak, file size |
| Constrained decoding (grammar / JSON schema) | 15% | API exists at the pinned version, overhead measured |
| Integration effort (Flutter FFI, shared ggml, build) | 15% | build + C ABI fit, extra toolchains |
| License & maintenance health | 10% | license file, release cadence, activity |
| Model ecosystem / flexibility (LLM-08 candidates) | 10% | formats, conversion cost per model |
| Privacy / network behaviour, testability | 5% | network code in the runtime; host build for CI |

## Evidence

### Host measurements — llama.cpp (HOST, *not* a target device)
Environment: Apple M3 Pro (6P+6E), 18 GB, macOS 27.0.1; llama.cpp `v0.6.0` (`d812350`) built by
`tools/spikes/LLM-01-runtime/build.sh` (Release, `GGML_NATIVE=OFF`, `GGML_OPENMP=OFF`,
Metal + Accelerate BLAS, same flags policy as `native/CMakeLists.txt`). Harness
`tools/spikes/LLM-01-runtime/llm_spike.cpp`: cold model load (fresh process; OS page cache warm
after the first run), chat-templated synthetic meeting transcript (~2.2k tokens), `n_ctx 4096`,
`n_batch/n_ubatch 512`, greedy, 256 decode tokens (EOG banned) or GBNF `meeting.gbnf`.
n = 3 per row, median (min–max). **The host was shared with several parallel build agents
(load average 70–130 during the runs), so absolute numbers — especially CPU rows — are
pessimistic and noisy.** Full table + model sha256: `tools/bench/results/2026-10-13-llm01-host.md`
(raw: `.json`).

| Model (file size) | Config | Prefill tok/s | Decode tok/s | Cold load ms | Peak footprint MiB |
|---|---|---|---|---|---|
| Llama-3.2-3B-Instruct Q4_K_M (1.93 GiB) | Metal, f16 KV | 655 (602–664) | 28.4 (27.6–28.6) | 493 (418–508) | 668 |
| Llama-3.2-3B-Instruct Q4_K_M | Metal, q8_0 KV, FA auto | 633 (593–785) | 35.1 (29.3–38.9) | 469 (432–660) | 461 |
| Llama-3.2-3B-Instruct Q4_K_M | Metal, q8_0 KV + GBNF | 807 (804–809) | 21.7 (21.3–21.9)¹ | 394 (378–467) | 551 |
| Llama-3.2-3B-Instruct Q4_K_M | CPU 4 threads, q8_0 KV | 18.9 (14.2–34.2)² | 3.8 (1.0–5.3)² | 8266 (5675–20116) | 2331 |
| Llama-3.2-3B-Instruct Q4_0 (1.79 GiB) | Metal, q8_0 KV | 668 (531–682) | 28.5 (28.3–29.6) | 678 (556–988) | 461 |
| Llama-3.2-3B-Instruct Q4_0 | CPU 4 threads, q8_0 KV | 26.0 (25.9–31.6)² | 4.1 (3.2–5.9)² | 5267 (3728–8508) | 2298 |
| Llama-3.2-1B-Instruct Q4_K_M (0.75 GiB) | Metal, f16 KV | 1806 (1155–1824) | 68.2 (62.2–69.9) | 364 (354–471) | 336 |
| Llama-3.2-1B-Instruct Q4_K_M | Metal, q8_0 KV | 1503 (1448–1768) | 58.7 (33.7–70.2) | 374 (294–619) | 275 |
| Llama-3.2-1B-Instruct Q4_K_M | Metal, q8_0 KV + GBNF | 1684 (1675–1744) | 19.8 (17.2–21.2) | 549 (366–884) | 362 |
| Llama-3.2-1B-Instruct Q4_K_M | CPU 4 threads, q8_0 KV | 48.8 (43.0–61.6)² | 16.4 (5.9–16.9)² | 2427 (2323–2884) | 1000 |
| SmolLM2-135M-Instruct Q8_0 (test model) | Metal, q8_0 KV | 13055 | 219.8 | 46 | 194 |

¹ the grammar stopped at a valid JSON after 27–29 tokens for the 3B models (EOG allowed by
the grammar), so the 3B GBNF decode rate includes grammar start-up; the 1B row ran the full 256
tokens. ² CPU rows ran while other agents were compiling on all cores — treat as a lower bound.
All rows deterministic (identical greedy output hash across the 3 runs). Sanity check with
`llama-bench` (same build, Metal, depth 0, n = 3): 3B Q4_K_M pp512 849 ± 1, tg128 47.4 ± 1.0;
1B Q4_K_M pp512 2431 ± 12, tg128 113.6 ± 5.6 — our ~2.1k-token-deep decode is lower, as expected.

Observations:

- **Metal + mmap keeps the jetsam footprint small**: the 3B Q4_K_M peaks at ~0.46 GiB
  `phys_footprint` with q8_0 KV (file-backed weights are not charged), vs ~2.3 GiB on the CPU
  path, where weights are repacked into anonymous buffers. LLM-07's RAM estimate must use the
  CPU figure for the iOS background/CPU path and for Android.
- **q8_0 KV** cut the footprint by ~200 MiB at 4k context (3B) with no decode slowdown on Metal
  (flash attention auto-enabled); f16 → q8_0 is the default for LLM-02/LLM-07.
- **GBNF overhead is large**: 1B decode 58.7 → 19.8 tok/s (−66%) with `meeting.gbnf`; grammar
  work runs on the CPU over Llama-3.2's 128k vocabulary and was hurt by the CPU contention.
  This is above the vv-llm-inference target (< 20%) and is an input to LLM-05 (lazy grammar,
  sampling top-k before grammar, smaller schema grammars) — not a runtime blocker: the other
  options either lack grammars (ExecuTorch) or would need the same masking work.
- **Q4_0 vs Q4_K_M** on Metal: no win for Q4_0 (28.5 vs 35.1 tok/s). The Q4_0 ARM repack
  advantage only applies to CPU builds with dotprod/i8mm — decided with Android device numbers
  (LLM-03).
- Same greedy output across runs everywhere → the determinism requirement of LLM-04 holds
  on this runtime.

### Target devices ⏳ (rows in `docs/test-plans/device/LLM-01.md`)
| Device | Model / config | Prefill tok/s | Decode tok/s | Load ms | Peak MiB |
|---|---|---|---|---|---|
| iPhone 15 Pro / 16 (VV-IOS-16) | 3B Q4_K_M, Metal, q8_0 KV | ⏳ | ⏳ (target ≥ 15) | ⏳ | ⏳ |
| iPhone 11 (VV-IOS-11) | 1B Q4_K_M, Metal, q8_0 KV | ⏳ | ⏳ | ⏳ | ⏳ |
| Snapdragon 8 Gen 3 / 8 Elite (VV-AND-FLG) | 3B Q4_0, CPU dotprod build | ⏳ | ⏳ (target ≥ 10) | ⏳ | ⏳ |
| Snapdragon 7-series (VV-AND-7) | 3B Q4_0, CPU | ⏳ | ⏳ | ⏳ | ⏳ |

### ExecuTorch and MLC-LLM — assessed from official repos/docs, **not built**
Building either needs toolchains this host does not have (Xcode + iOS SDK, Android NDK) and,
for meaningful numbers, the target phones; their LLM paths have no Metal-equivalent macOS
host runner that would say anything about iPhone/Android performance. Their host builds would
not change the decision (below), so the spike does not build them. Sources verified 2026-10-13:
`pytorch/executorch` (LICENSE, `extension/llm/runner/irunner.h`, `extension/llm/sampler/logit_processor.h`,
docs "LLMs → getting started"), `mlc-ai/mlc-llm` (`python/mlc_llm/protocol/openai_api_protocol.py`,
docs "deploy/ios"), GitHub metadata via `gh api`.

| Criterion | llama.cpp | ExecuTorch | MLC-LLM |
|---|---|---|---|
| Model format | GGUF (any HF model via `convert_hf_to_gguf.py`; pre-quantized GGUFs widely published) | `.pte` per model × backend × quant, exported with PyTorch; tokenizer shipped separately | TVM-compiled model lib per model × quant × target + MLC weight shards |
| Constrained decoding | **Yes**: `llama_sampler_init_grammar` (GBNF) in the core lib; JSON-schema→GBNF converter in `common/` (LLM-05 `vv_jsg`) | **No** at v1.5.1: `GenerationConfig.grammar` is a "reserved" field; only an `ET_EXPERIMENTAL` `LogitProcessor` hook — we would have to integrate a grammar engine ourselves | **Yes**: `response_format {type: json_object, schema}` via XGrammar in the engine |
| Shares ggml with whisper.cpp | **Yes** (one ggml already linked in `vv_native`, FND-06) | No — second ML runtime + kernels in the binary | No — TVM runtime + tokenizers-cpp + sentencepiece (+ Rust toolchain for tokenizers) |
| Flutter / C-ABI fit | C API, already linked into `vv_native`; Dart only sees `vv_*` | C++ API (no C ABI); wrap in `vv_*`; Swift/Java demo apps | Swift/Java SDKs with async OpenAI-style API; C++ engine is JSON-RPC-ish; FFI wrapping is non-trivial |
| Extra build toolchain | CMake only | Python + PyTorch export pipeline per model; Buck/CMake runtime build | Python `mlc_llm` + TVM compile per model, Rust/Cargo, Git-LFS |
| GPU / accelerators | Metal; Vulkan, OpenCL (Adreno) optional; CPU dotprod/i8mm/KleidiAI | Core ML/MPS (iOS), Vulkan, QNN/MediaTek NPUs (vendor SDKs, licences) | Metal, Vulkan/OpenCL via TVM codegen |
| Vendor-reported mobile speed | (measure: LLM-02/03) | Llama-3.2-1B SpinQuant/QAT on OnePlus 12 (SD 8 Gen 3): **50.2 tok/s decode, 260 tok/s prefill** (PyTorch blog, prompt 64) — special Meta-quantized checkpoints, not a generic 4-bit GGUF | no current official mobile benchmark table found in docs/README |
| License | MIT | BSD-3-Clause (+ backend SDK licences, e.g. QNN) | Apache-2.0 (TVM Apache-2.0) |
| Health (2026-10-13) | 131k ★, last push today, tagged releases (pinned v0.6.0) | 5.1k ★, v1.5.1 (2026-09-23), 1.3k open issues | 23k ★, last commit 2026-10-06, no stable release (dev tags only) |
| Network code in runtime | download/HTTP code only in `llama-common` — excluded (`LLAMA_BUILD_COMMON=OFF`) | none in runtime | SDK apps download weights from Hugging Face by default (must be disabled; `bundle_weight` / local path) |
| Host testability (CI) | same bridge on macOS/Linux (`native/build.sh host`) | possible (XNNPACK host) but different kernels/backends than iOS Core ML | possible with a host-compiled lib, different target codegen |

### Shared ggml
llama.cpp and whisper.cpp at the FND-06 pins have **identical ggml trees**, and both already
link into one `vv_native` that exports only `vv_*` (FND-06 ctest `vv_exports`). Adding llama.cpp
costs no new runtime, no new toolchain, and no second copy of CPU/GPU kernels. Either competitor
adds a second inference runtime (binary size, two sets of backend quirks, two memory models)
next to ggml, which whisper.cpp needs anyway.

## Decision
We choose **llama.cpp** (pinned in `native/VERSIONS.md`, linked into the shared `vv_native`).

Reasons, in criterion order:
1. **Speed**: no evidence that a competitor is ≥ 1.5× faster on our targets at a comparable
   generic 4-bit quant. The only official competitor number (ExecuTorch 1B, 50 tok/s on SD 8 Gen 3)
   uses Meta's QAT/SpinQuant checkpoints that do not exist for most LLM-08 candidates. This is
   **unverified on devices**; the 1.5× rule is re-checked against the LLM-02/LLM-03 device rows.
2. **Constrained decoding** is built in (GBNF) and measured working here; ExecuTorch has none
   at v1.5.1, MLC has it via XGrammar.
3. **Integration**: already linked, one ggml with whisper.cpp, C API behind `vv_*`, CMake-only
   build, identical host build for CI and evals (`vv-benchmark-eval`).
4. **Ecosystem**: GGUF is the de-facto distribution format for every LLM-08 candidate; the other
   two need a per-model export/compile step owned by us.
5. **License/health**: MIT, very active, tagged releases we can pin.

### Out of scope for v1 (recorded per task scope)
NPU / Core ML LLM paths (master plan §4.2): NNAPI is deprecated (Android 15), Core ML LLM
conversion has no path from GGUF and would need per-model conversion and ANE-specific quants;
Qualcomm QNN / MediaTek NeuroPilot need vendor SDKs with their own licences. Revisit only via a
new ADR if device numbers show llama.cpp missing the LLM-02/03 targets by a wide margin.

### Re-open triggers
- LLM-02 (iPhone 15 Pro, 3B Q4_K_M ≥ 15 tok/s) or LLM-03 (SD 8 Gen 3 3B Q4 ≥ 10 tok/s) misses
  its target by > 1.5× → prototype ExecuTorch on that platform (follow-up LLM-09).
- Grammar overhead stays > 20% on devices after LLM-05 optimisation → evaluate XGrammar-style
  token-mask caching (either inside llama.cpp or as a sampler) before switching runtimes.

## Consequences
- Positive: one native stack (ggml) for STT + LLM; GBNF for LLM-05; host benches == app code;
  GGUF catalog for MDL-*; no new toolchains.
- Negative / risks:
  - llama.cpp API churn (e.g. `use_mmap` → `load_mode` and the new `llama_batch_ext` API at
    this pin) — mitigated by pinning and keeping llama.h behind `native/bridge/vv_llama.*`.
  - Static Android build has CPU features fixed at compile time (`ggml_cpu_has_dotprod()` is a
    compile-time check at this pin) → the FND-06 armv8-a baseline gets no dotprod/i8mm kernels
    and no Q4_0 repacking. Decided in LLM-03.
  - Grammar sampling cost grows with vocab size (Llama-3.2 128k); see observations and LLM-05.
  - Device numbers are missing → status stays **Proposed** until LLM-01 device rows are run.
- Follow-up tasks: LLM-02/LLM-03 reference this ADR; LLM-09 (proposed, only if a re-open
  trigger fires): ExecuTorch device prototype.
