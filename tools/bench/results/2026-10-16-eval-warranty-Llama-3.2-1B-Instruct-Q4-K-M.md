# Extraction eval — `warranty` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-16 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `ebf4ff7` · llama.cpp `ebf4ff7` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/warranty/`)
- Wall time: 61 s incl. model load + Dart compile · peak RSS: 1103 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 33.9% |
| Prefill tok/s (median) | 3244 |
| Decode tok/s (median) | 96.2 |
| Latency per case (median / max) | 1.7 s / 1038.8 s |
| Prompt tokens (median / max) | 700 / 788 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| support_contacts | 14.5% | 88.9% | 25.0% | 9 | 55 | – |

## Scalar fields

| Field | Exact | Fuzzy |
|---|---|---|
| product | 23.3% | 63.3% |
| brand | 40.0% | 56.7% |
| model | 43.3% | 70.0% |
| serial_number | 33.3% | 33.3% |
| purchase_date | 43.3% | 56.7% |
| retailer | 60.0% | 83.3% |
| price | 36.7% | 90.0% |
| warranty_period | 80.0% | 80.0% |
| **all (field accuracy)** | 45.0% | 66.7% |

Prose fields (token-set similarity to the reference, informational): notes 30.9%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| scalars.accuracy | ≥ 90.0% | 66.7% | ❌ |
| scalars.serial_number.exact | ≥ 85.0% | 33.3% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| warranty-001 | ✅ | 718 | 1.7 | support_contacts 0/0/1 |
| warranty-002 | ✅ | 689 | 1.6 | support_contacts 0/0/3 |
| warranty-003 | ✅ | 720 | 1025.6 | all lists exact |
| warranty-004 | ✅ | 696 | 1.4 | all lists exact |
| warranty-005 | ✅ | 717 | 1.8 | support_contacts 0/0/3 |
| warranty-006 | ✅ | 683 | 939.0 | support_contacts 0/0/3 |
| warranty-007 | ✅ | 699 | 1.4 | support_contacts 0/0/1 |
| warranty-008 | ✅ | 732 | 1.5 | all lists exact |
| warranty-009 | ✅ | 651 | 984.2 | support_contacts 0/0/1 |
| warranty-010 | ✅ | 700 | 1.7 | support_contacts 0/0/3 |
| warranty-011 | ✅ | 689 | 1.4 | support_contacts 0/0/1 |
| warranty-012 | ✅ | 700 | 1.2 | support_contacts 0/0/1 |
| warranty-013 | ✅ | 710 | 1038.8 | support_contacts 0/0/3 |
| warranty-014 | ✅ | 692 | 1.3 | all lists exact |
| warranty-015 | ✅ | 726 | 256.1 | support_contacts 0/0/3 |
| warranty-016 | ✅ | 722 | 1.8 | support_contacts 0/1/3 |
| warranty-017 | ✅ | 788 | 4.3 | all lists exact |
| warranty-018 | ✅ | 687 | 984.2 | support_contacts 0/0/3 |
| warranty-019 | ✅ | 706 | 1.5 | support_contacts 0/0/1 |
| warranty-020 | ✅ | 704 | 1.9 | support_contacts 0/0/3 |
| warranty-021 | ✅ | 680 | 230.0 | support_contacts 0/0/1 |
| warranty-022 | ✅ | 726 | 1.3 | all lists exact |
| warranty-023 | ✅ | 700 | 2.9 | support_contacts 0/0/1 |
| warranty-024 | ✅ | 683 | 3.6 | all lists exact |
| warranty-025 | ✅ | 692 | 935.7 | support_contacts 0/0/2 |
| warranty-026 | ✅ | 726 | 1.6 | support_contacts 0/0/3 |
| warranty-027 | ✅ | 697 | 1.4 | support_contacts 0/0/3 |
| warranty-028 | ✅ | 703 | 1003.5 | support_contacts 0/0/3 |
| warranty-029 | ✅ | 729 | 1.5 | all lists exact |
| warranty-030 | ✅ | 688 | 1.3 | support_contacts 0/0/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=warranty MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
