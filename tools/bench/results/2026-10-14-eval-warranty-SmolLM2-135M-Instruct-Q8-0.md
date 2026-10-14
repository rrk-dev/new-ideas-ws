# Extraction eval — `warranty` × `SmolLM2-135M-Instruct-Q8_0.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: cpu
- Model sha256: `5a1395716f791374` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `863fde7` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/warranty/`)
- Wall time: 213 s incl. model load + Dart compile · peak RSS: 611 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 41.0% |
| Prefill tok/s (median) | 222 |
| Decode tok/s (median) | 81.1 |
| Latency per case (median / max) | 6.6 s / 33.0 s |
| Prompt tokens (median / max) | 929 / 1042 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| support_contacts | 0.0% | 0.0% | 0.0% | 9 | 0 | – |

## Scalar fields

| Field | Exact | Fuzzy |
|---|---|---|
| product | 43.3% | 56.7% |
| brand | 20.0% | 36.7% |
| model | 13.3% | 33.3% |
| serial_number | 3.3% | 3.3% |
| purchase_date | 13.3% | 16.7% |
| retailer | 40.0% | 46.7% |
| price | 20.0% | 60.0% |
| warranty_period | 46.7% | 46.7% |
| **all (field accuracy)** | 25.0% | 37.5% |

Prose fields (token-set similarity to the reference, informational): notes 63.3%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| scalars.accuracy | ≥ 90.0% | 37.5% | ❌ |
| scalars.serial_number.exact | ≥ 85.0% | 3.3% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| warranty-001 | ✅ | 951 | 7.2 | all lists exact |
| warranty-002 | ✅ | 910 | 8.5 | all lists exact |
| warranty-003 | ✅ | 955 | 15.8 | support_contacts 0/1/0 |
| warranty-004 | ✅ | 923 | 8.2 | support_contacts 0/1/0 |
| warranty-005 | ✅ | 941 | 13.1 | all lists exact |
| warranty-006 | ✅ | 912 | 10.8 | all lists exact |
| warranty-007 | ✅ | 929 | 10.7 | all lists exact |
| warranty-008 | ✅ | 960 | 12.4 | support_contacts 0/1/0 |
| warranty-009 | ✅ | 865 | 9.2 | all lists exact |
| warranty-010 | ✅ | 929 | 33.0 | all lists exact |
| warranty-011 | ✅ | 911 | 8.6 | all lists exact |
| warranty-012 | ✅ | 926 | 12.9 | all lists exact |
| warranty-013 | ✅ | 938 | 8.2 | all lists exact |
| warranty-014 | ✅ | 920 | 8.0 | support_contacts 0/1/0 |
| warranty-015 | ✅ | 957 | 7.7 | all lists exact |
| warranty-016 | ✅ | 957 | 5.9 | support_contacts 0/1/0 |
| warranty-017 | ✅ | 1042 | 3.9 | support_contacts 0/1/0 |
| warranty-018 | ✅ | 908 | 2.3 | all lists exact |
| warranty-019 | ✅ | 932 | 2.0 | all lists exact |
| warranty-020 | ✅ | 927 | 2.5 | all lists exact |
| warranty-021 | ✅ | 901 | 3.9 | all lists exact |
| warranty-022 | ✅ | 966 | 2.1 | support_contacts 0/2/0 |
| warranty-023 | ✅ | 927 | 1.6 | all lists exact |
| warranty-024 | ✅ | 905 | 1.6 | all lists exact |
| warranty-025 | ✅ | 913 | 1.7 | all lists exact |
| warranty-026 | ✅ | 962 | 1.4 | all lists exact |
| warranty-027 | ✅ | 931 | 1.5 | all lists exact |
| warranty-028 | ✅ | 933 | 1.6 | all lists exact |
| warranty-029 | ✅ | 963 | 1.4 | support_contacts 0/1/0 |
| warranty-030 | ✅ | 910 | 1.3 | all lists exact |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=warranty MODEL=SmolLM2-135M-Instruct-Q8_0.gguf`.
