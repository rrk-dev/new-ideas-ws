# ADR-LLM-08 — Default LLM per tier: Llama-3.2-1B (Free/Low), Llama-3.2-3B expected for Mid/High

- **Status:** Proposed (only Llama-3.2-1B has real PRF-09 host numbers; candidates 3B, Gemma, Qwen, Phi are `needs-eval`; device rows ⏳ in `docs/test-plans/device/LLM-08.md`)
- **Date:** 2026-10-15
- **Task:** LLM-08
- **Deciders:** Copilot (implementer); pending independent verifier, device numbers and SEC-05 licence sign-off
- **Supersedes:** —

## Context
Extraction runs on-device (llama.cpp, ADR-LLM-01, grammar-constrained JSON). The Free plan is
capped at the 1B class (`kSmallLlmMaxBytes` 1.2 GB), larger models are Pro; device tiers follow
RAM (LLM-07: Low < 5 GiB, Mid 5–7, High ≥ 7). The catalog (MDL-01) lists models; this ADR
decides which. Model weights are not available offline in this build environment, so the
decision is made by a reproducible harness and filled in as numbers arrive.

## Options
Llama-3.2-1B / 3B-Instruct, Gemma-2-2B-IT, Gemma-3-1B / 4B-IT, Qwen2.5-0.5B / 1.5B / 3B,
Qwen3-1.7B / 4B, Phi-4-mini (Q4_K_M; Q4_0 as a speed variant). Full list, sizes and licences:
`tools/bench/llm_select/candidates.json`.

## Criteria (weights fixed before measuring, `candidates.json`)
| Criterion | Weight | Measure |
|---|---|---|
| Extraction quality | 40% | mean target attainment over meeting/warranty/engineering (PRF-09 targets) |
| Schema validity | 15% | first-pass, grammar-constrained |
| Hallucination | 10% | ungrounded items (ceiling 15%) |
| Speed | 15% | median decode tok/s vs 90 |
| RAM | 10% | peak RSS vs tier budget |
| Licence & maintenance | 10% | commercial redistribution (hard gate) + maintenance |

Hard gates: commercial licence, Free size cap, tier RAM budget, schema validity ≥ 90%.
Unmeasured candidates are never selected (`make llm-select`, `tools/bench/llm_select/rank.py`).

## Evidence
Environment: Apple Silicon host, Metal, llama.cpp `d812350`, seed 42, 30 synthetic cases per
profile (PRF-09). Report: `tools/bench/results/2026-10-15-llm08-selection.md`.

| Model | Quality | Schema-valid | Halluc. | Decode tok/s | Peak RSS MiB |
|---|---|---|---|---|---|
| Llama-3.2-1B Q4_K_M | 64% | 96.7% | 10.8% | 93 | 1203 |
| SmolLM2-135M Q8_0 (CI model, not a candidate) | 16% | 100% | 40.9% | 156 | 677 |

Not measured (weights not available here): the rest of the list. Licence check done from the
model cards (SEC-05 to confirm): Qwen2.5-3B is under the Qwen Research License and is rejected
for a commercial app; Llama 3.2 needs "Built with Llama" attribution + AUP pass-through; Gemma
needs ToU pass-through; Qwen2.5-0.5B/1.5B, Qwen3, SmolLM2 Apache-2.0; Phi-4-mini MIT.

## Decision (provisional)
- **Free / Low:** Llama-3.2-1B-Instruct Q4_K_M — the only measured eligible model, but it misses
  the PRF-04 targets (action-item P/R 60/52%, 96.7% valid), so the repair path and prompt work
  (PRF-02) matter more than a model swap; re-rank once Gemma-3-1B and Qwen2.5-1.5B (1066 MiB,
  just under the Free cap) are measured. Fallback: Qwen2.5-0.5B (in the catalog).
- **Mid / High:** Llama-3.2-3B-Instruct Q4_K_M is the expected default (the plan's §4.2
  candidate; fits the Mid budget at ≈ 2.4 GiB). This is an expectation, **not** a measured result.
  Gemma-3-4B / Qwen3-4B / Phi-4-mini exceed the Mid budget (> 2.8 GiB) and are High candidates only.

## Consequences
- Positive: selection is reproducible and refreshes automatically from new eval JSON.
- Negative / risks: Mid/High defaults are unproven; host speed ≠ device speed.
- Follow-ups: run `make eval-all` for each candidate plus the device rows; move this ADR to
  Accepted and update the MDL-01 catalog + `docs/models.md`; long-transcript ablations
  (LLM-06 notes) on the chosen default.
