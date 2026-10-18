# Extraction eval — `warranty` × `Llama-3.2-3B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6c1a2b4116103267` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/warranty/`)
- Wall time: 267 s incl. model load + Dart compile · peak RSS: 3718 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 13.6% |
| Prefill tok/s (median) | 145 |
| Decode tok/s (median) | 32.7 |
| Latency per case (median / max) | 8.0 s / 13.0 s |
| Prompt tokens (median / max) | 700 / 788 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| support_contacts | 26.7% | 88.9% | 41.0% | 9 | 30 | – |

## Scalar fields

| Field | Exact | Fuzzy |
|---|---|---|
| product | 70.0% | 96.7% |
| brand | 30.0% | 53.3% |
| model | 50.0% | 80.0% |
| serial_number | 76.7% | 76.7% |
| purchase_date | 43.3% | 93.3% |
| retailer | 66.7% | 93.3% |
| price | 40.0% | 93.3% |
| warranty_period | 90.0% | 90.0% |
| **all (field accuracy)** | 58.3% | 84.6% |

Prose fields (token-set similarity to the reference, informational): notes 18.6%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| scalars.accuracy | ≥ 90.0% | 84.6% | ❌ |
| scalars.serial_number.exact | ≥ 85.0% | 76.7% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| warranty-001 | ✅ | 718 | 13.0 | support_contacts 0/0/1 |
| warranty-002 | ✅ | 689 | 11.0 | support_contacts 0/0/1 |
| warranty-003 | ✅ | 720 | 11.2 | all lists exact |
| warranty-004 | ✅ | 696 | 9.5 | all lists exact |
| warranty-005 | ✅ | 717 | 11.3 | support_contacts 0/0/1 |
| warranty-006 | ✅ | 683 | 9.5 | support_contacts 0/0/1 |
| warranty-007 | ✅ | 699 | 6.9 | support_contacts 0/0/1 |
| warranty-008 | ✅ | 732 | 8.9 | all lists exact |
| warranty-009 | ✅ | 651 | 6.0 | all lists exact |
| warranty-010 | ✅ | 700 | 7.2 | support_contacts 0/0/1 |
| warranty-011 | ✅ | 689 | 7.5 | support_contacts 0/0/1 |
| warranty-012 | ✅ | 700 | 6.7 | support_contacts 0/0/1 |
| warranty-013 | ✅ | 710 | 11.7 | support_contacts 0/0/1 |
| warranty-014 | ✅ | 692 | 10.9 | all lists exact |
| warranty-015 | ✅ | 726 | 11.1 | support_contacts 0/0/1 |
| warranty-016 | ✅ | 722 | 10.9 | all lists exact |
| warranty-017 | ✅ | 788 | 10.4 | all lists exact |
| warranty-018 | ✅ | 687 | 7.1 | support_contacts 0/0/1 |
| warranty-019 | ✅ | 706 | 7.2 | support_contacts 0/0/1 |
| warranty-020 | ✅ | 704 | 7.7 | support_contacts 0/0/1 |
| warranty-021 | ✅ | 680 | 6.8 | support_contacts 0/0/1 |
| warranty-022 | ✅ | 726 | 7.8 | support_contacts 1/2/2 |
| warranty-023 | ✅ | 700 | 7.2 | support_contacts 0/0/1 |
| warranty-024 | ✅ | 683 | 6.7 | support_contacts 0/0/1 |
| warranty-025 | ✅ | 692 | 6.9 | support_contacts 0/0/1 |
| warranty-026 | ✅ | 726 | 8.1 | support_contacts 0/0/1 |
| warranty-027 | ✅ | 697 | 7.0 | support_contacts 0/0/1 |
| warranty-028 | ✅ | 703 | 7.0 | support_contacts 0/0/1 |
| warranty-029 | ✅ | 729 | 10.1 | all lists exact |
| warranty-030 | ✅ | 688 | 9.5 | support_contacts 0/0/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=warranty MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf`.
