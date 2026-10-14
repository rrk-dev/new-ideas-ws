# Extraction eval — `warranty` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `863fde7` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/warranty/`)
- Wall time: 37 s incl. model load + Dart compile · peak RSS: 1124 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 8.9% |
| Prefill tok/s (median) | 3700 |
| Decode tok/s (median) | 77.1 |
| Latency per case (median / max) | 1.1 s / 1.4 s |
| Prompt tokens (median / max) | 814 / 902 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| support_contacts | 100.0% | 11.1% | 20.0% | 9 | 1 | – |

## Scalar fields

| Field | Exact | Fuzzy |
|---|---|---|
| product | 76.7% | 93.3% |
| brand | 36.7% | 53.3% |
| model | 53.3% | 80.0% |
| serial_number | 13.3% | 13.3% |
| purchase_date | 90.0% | 96.7% |
| retailer | 56.7% | 80.0% |
| price | 40.0% | 66.7% |
| warranty_period | 90.0% | 90.0% |
| **all (field accuracy)** | 57.1% | 71.7% |

Prose fields (token-set similarity to the reference, informational): notes 49.6%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| scalars.accuracy | ≥ 90.0% | 71.7% | ❌ |
| scalars.serial_number.exact | ≥ 85.0% | 13.3% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| warranty-001 | ✅ | 832 | 1.2 | all lists exact |
| warranty-002 | ✅ | 803 | 1.1 | all lists exact |
| warranty-003 | ✅ | 834 | 1.3 | support_contacts 0/1/0 |
| warranty-004 | ✅ | 810 | 1.0 | support_contacts 0/1/0 |
| warranty-005 | ✅ | 831 | 1.3 | all lists exact |
| warranty-006 | ✅ | 797 | 1.0 | all lists exact |
| warranty-007 | ✅ | 813 | 1.1 | all lists exact |
| warranty-008 | ✅ | 846 | 1.2 | support_contacts 0/1/0 |
| warranty-009 | ✅ | 765 | 1.1 | all lists exact |
| warranty-010 | ✅ | 814 | 1.1 | all lists exact |
| warranty-011 | ✅ | 803 | 1.1 | all lists exact |
| warranty-012 | ✅ | 814 | 1.1 | all lists exact |
| warranty-013 | ✅ | 824 | 1.2 | all lists exact |
| warranty-014 | ✅ | 806 | 1.1 | support_contacts 0/1/0 |
| warranty-015 | ✅ | 840 | 1.4 | all lists exact |
| warranty-016 | ✅ | 836 | 1.2 | all lists exact |
| warranty-017 | ✅ | 902 | 1.2 | support_contacts 0/1/0 |
| warranty-018 | ✅ | 801 | 1.1 | all lists exact |
| warranty-019 | ✅ | 820 | 1.2 | all lists exact |
| warranty-020 | ✅ | 818 | 1.3 | all lists exact |
| warranty-021 | ✅ | 794 | 1.1 | all lists exact |
| warranty-022 | ✅ | 840 | 1.3 | support_contacts 0/2/0 |
| warranty-023 | ✅ | 814 | 1.0 | all lists exact |
| warranty-024 | ✅ | 797 | 1.1 | all lists exact |
| warranty-025 | ✅ | 806 | 1.1 | all lists exact |
| warranty-026 | ✅ | 840 | 0.9 | all lists exact |
| warranty-027 | ✅ | 811 | 1.0 | all lists exact |
| warranty-028 | ✅ | 817 | 1.1 | all lists exact |
| warranty-029 | ✅ | 843 | 1.1 | support_contacts 0/1/0 |
| warranty-030 | ✅ | 802 | 1.0 | all lists exact |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=warranty MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
