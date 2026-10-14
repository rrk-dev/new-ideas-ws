# Device verification — LLM-01 LLM runtime selection spike

ADR-LLM-01 is **Proposed** until these rows exist. No phone was available when this was
authored; only the host (Apple M3 Pro, macOS) was measured
(`tools/bench/results/2026-10-13-llm01-host.md`).

The llama.cpp numbers come from the bridge benchmark that LLM-02/LLM-03 add
(`vv_llm_bench`, run by `app/integration_test/llm_backend_bench_test.dart`) — the same
measurement as the host spike (`tools/spikes/LLM-01-runtime/llm_spike.cpp`): cold load,
prefill tok/s, decode tok/s for 256 tokens, peak footprint, n = 3, median (min–max). Start each
run at nominal thermal state, airplane mode, charger unplugged (vv-benchmark-eval).

ExecuTorch / MLC-LLM rows run **only if a re-open trigger in ADR-LLM-01 fires** (llama.cpp misses
the LLM-02/LLM-03 target by > 1.5×): build their official Llama demo apps at the versions named in
the ADR with Llama-3.2-3B-Instruct 4-bit, same prompt length, and record the same metrics.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [LLM-01/AC1] | 1. Run the LLM-02 device rows on VV-IOS-16 (3B Q4_K_M, Metal, q8_0 KV). 2. Copy prefill/decode/load/peak into the ADR "Device" table. | Row added to ADR-LLM-01; decode ≥ 15 tok/s keeps the decision (else re-open trigger). | iPhone 15 Pro / 16 (VV-IOS-16) | iOS 18+ | | | |
| [LLM-01/AC1] | 1. Run the LLM-03 device rows on VV-AND-FLG (3B Q4_0, CPU dotprod build). 2. Copy numbers into the ADR. | Row added; decode ≥ 10 tok/s keeps the decision. | Snapdragon 8 Gen 3 / 8 Elite (VV-AND-FLG) | Android 14+ | | | |
| [LLM-01/AC1] | Only if triggered: ExecuTorch Llama demo app (v1.5.1, XNNPACK / Core ML) with Llama-3.2-3B 4-bit on the device that missed its target; same prompt length. | Competitor decode tok/s recorded; ≥ 1.5× llama.cpp ⇒ new ADR superseding ADR-LLM-01. | the device that missed | — | | | |

## Notes / evidence
Host-only evidence and spike code: `tools/spikes/LLM-01-runtime/` (`build.sh`, `run.py`,
`llm_spike.cpp`, `meeting.gbnf`).
