# Extraction eval — `warranty` × `SmolLM2-135M-Instruct-Q8_0.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: cpu
- Model sha256: `5a1395716f791374` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `279469c` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/warranty/`)
- Wall time: 52 s incl. model load + Dart compile · peak RSS: 677 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 39.0% |
| Prefill tok/s (median) | 949 |
| Decode tok/s (median) | 155.9 |
| Latency per case (median / max) | 1.6 s / 2.8 s |
| Prompt tokens (median / max) | 960 / 1073 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| support_contacts | 0.0% | 0.0% | 0.0% | 9 | 0 | – |

## Scalar fields

| Field | Exact | Fuzzy |
|---|---|---|
| product | 40.0% | 60.0% |
| brand | 23.3% | 40.0% |
| model | 13.3% | 33.3% |
| serial_number | 3.3% | 3.3% |
| purchase_date | 16.7% | 20.0% |
| retailer | 50.0% | 53.3% |
| price | 20.0% | 60.0% |
| warranty_period | 43.3% | 43.3% |
| **all (field accuracy)** | 26.2% | 39.2% |

Prose fields (token-set similarity to the reference, informational): notes 63.3%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| scalars.accuracy | ≥ 90.0% | 39.2% | ❌ |
| scalars.serial_number.exact | ≥ 85.0% | 3.3% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| warranty-001 | ✅ | 982 | 1.5 | all lists exact |
| warranty-002 | ✅ | 941 | 1.4 | all lists exact |
| warranty-003 | ✅ | 986 | 1.5 | support_contacts 0/1/0 |
| warranty-004 | ✅ | 954 | 1.4 | support_contacts 0/1/0 |
| warranty-005 | ✅ | 972 | 1.4 | all lists exact |
| warranty-006 | ✅ | 943 | 1.3 | all lists exact |
| warranty-007 | ✅ | 960 | 1.3 | all lists exact |
| warranty-008 | ✅ | 991 | 1.4 | support_contacts 0/1/0 |
| warranty-009 | ✅ | 896 | 1.3 | all lists exact |
| warranty-010 | ✅ | 960 | 1.4 | all lists exact |
| warranty-011 | ✅ | 942 | 1.6 | all lists exact |
| warranty-012 | ✅ | 957 | 1.6 | all lists exact |
| warranty-013 | ✅ | 969 | 1.9 | all lists exact |
| warranty-014 | ✅ | 951 | 1.5 | support_contacts 0/1/0 |
| warranty-015 | ✅ | 988 | 1.7 | all lists exact |
| warranty-016 | ✅ | 988 | 1.5 | support_contacts 0/1/0 |
| warranty-017 | ✅ | 1073 | 1.6 | support_contacts 0/1/0 |
| warranty-018 | ✅ | 939 | 2.0 | all lists exact |
| warranty-019 | ✅ | 963 | 2.0 | all lists exact |
| warranty-020 | ✅ | 958 | 2.1 | all lists exact |
| warranty-021 | ✅ | 932 | 2.0 | all lists exact |
| warranty-022 | ✅ | 997 | 1.8 | support_contacts 0/2/0 |
| warranty-023 | ✅ | 958 | 2.8 | all lists exact |
| warranty-024 | ✅ | 936 | 1.7 | all lists exact |
| warranty-025 | ✅ | 944 | 1.7 | all lists exact |
| warranty-026 | ✅ | 993 | 2.1 | all lists exact |
| warranty-027 | ✅ | 962 | 1.7 | all lists exact |
| warranty-028 | ✅ | 964 | 1.8 | all lists exact |
| warranty-029 | ✅ | 994 | 1.7 | support_contacts 0/1/0 |
| warranty-030 | ✅ | 941 | 1.9 | all lists exact |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=warranty MODEL=SmolLM2-135M-Instruct-Q8_0.gguf`.
