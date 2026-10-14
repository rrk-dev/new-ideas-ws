# Extraction eval — `warranty` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `279469c` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/warranty/`)
- Wall time: 35 s incl. model load + Dart compile · peak RSS: 1203 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 7.5% |
| Prefill tok/s (median) | 3905 |
| Decode tok/s (median) | 81.7 |
| Latency per case (median / max) | 1.0 s / 1.2 s |
| Prompt tokens (median / max) | 843 / 931 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| support_contacts | 75.0% | 33.3% | 46.2% | 9 | 4 | – |

## Scalar fields

| Field | Exact | Fuzzy |
|---|---|---|
| product | 76.7% | 96.7% |
| brand | 36.7% | 53.3% |
| model | 60.0% | 80.0% |
| serial_number | 16.7% | 16.7% |
| purchase_date | 90.0% | 96.7% |
| retailer | 56.7% | 80.0% |
| price | 33.3% | 53.3% |
| warranty_period | 90.0% | 90.0% |
| **all (field accuracy)** | 57.5% | 70.8% |

Prose fields (token-set similarity to the reference, informational): notes 47.5%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| scalars.accuracy | ≥ 90.0% | 70.8% | ❌ |
| scalars.serial_number.exact | ≥ 85.0% | 16.7% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| warranty-001 | ✅ | 861 | 1.1 | all lists exact |
| warranty-002 | ✅ | 832 | 0.9 | all lists exact |
| warranty-003 | ✅ | 863 | 1.1 | all lists exact |
| warranty-004 | ✅ | 839 | 0.9 | support_contacts 0/1/0 |
| warranty-005 | ✅ | 860 | 1.1 | all lists exact |
| warranty-006 | ✅ | 826 | 0.9 | all lists exact |
| warranty-007 | ✅ | 842 | 1.0 | all lists exact |
| warranty-008 | ✅ | 875 | 1.1 | support_contacts 0/1/0 |
| warranty-009 | ✅ | 794 | 1.0 | all lists exact |
| warranty-010 | ✅ | 843 | 1.1 | all lists exact |
| warranty-011 | ✅ | 832 | 1.1 | all lists exact |
| warranty-012 | ✅ | 843 | 1.0 | all lists exact |
| warranty-013 | ✅ | 853 | 1.0 | all lists exact |
| warranty-014 | ✅ | 835 | 0.9 | support_contacts 0/1/0 |
| warranty-015 | ✅ | 869 | 1.2 | all lists exact |
| warranty-016 | ✅ | 865 | 1.1 | all lists exact |
| warranty-017 | ✅ | 931 | 1.2 | support_contacts 0/1/0 |
| warranty-018 | ✅ | 830 | 0.9 | all lists exact |
| warranty-019 | ✅ | 849 | 0.9 | all lists exact |
| warranty-020 | ✅ | 847 | 1.1 | all lists exact |
| warranty-021 | ✅ | 823 | 1.0 | all lists exact |
| warranty-022 | ✅ | 869 | 1.2 | support_contacts 1/2/2 |
| warranty-023 | ✅ | 843 | 1.0 | all lists exact |
| warranty-024 | ✅ | 826 | 1.0 | all lists exact |
| warranty-025 | ✅ | 835 | 1.1 | all lists exact |
| warranty-026 | ✅ | 869 | 1.1 | all lists exact |
| warranty-027 | ✅ | 840 | 1.1 | all lists exact |
| warranty-028 | ✅ | 846 | 1.0 | all lists exact |
| warranty-029 | ✅ | 872 | 1.2 | support_contacts 0/1/0 |
| warranty-030 | ✅ | 831 | 1.0 | all lists exact |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=warranty MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
