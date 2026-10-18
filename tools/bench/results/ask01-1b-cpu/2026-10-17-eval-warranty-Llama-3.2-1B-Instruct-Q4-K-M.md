# Extraction eval — `warranty` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/warranty/`)
- Wall time: 193 s incl. model load + Dart compile · peak RSS: 1829 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 34.4% |
| Prefill tok/s (median) | 256 |
| Decode tok/s (median) | 47.1 |
| Latency per case (median / max) | 5.8 s / 12.0 s |
| Prompt tokens (median / max) | 700 / 788 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| support_contacts | 16.4% | 100.0% | 28.1% | 9 | 55 | – |

## Scalar fields

| Field | Exact | Fuzzy |
|---|---|---|
| product | 26.7% | 66.7% |
| brand | 30.0% | 43.3% |
| model | 46.7% | 70.0% |
| serial_number | 20.0% | 20.0% |
| purchase_date | 36.7% | 46.7% |
| retailer | 50.0% | 80.0% |
| price | 26.7% | 80.0% |
| warranty_period | 73.3% | 73.3% |
| **all (field accuracy)** | 38.8% | 60.0% |

Prose fields (token-set similarity to the reference, informational): notes 27.0%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| scalars.accuracy | ≥ 90.0% | 60.0% | ❌ |
| scalars.serial_number.exact | ≥ 85.0% | 20.0% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| warranty-001 | ✅ | 718 | 12.0 | support_contacts 0/0/2 |
| warranty-002 | ✅ | 689 | 11.1 | support_contacts 0/0/1 |
| warranty-003 | ✅ | 720 | 8.1 | all lists exact |
| warranty-004 | ✅ | 696 | 6.1 | all lists exact |
| warranty-005 | ✅ | 717 | 5.6 | support_contacts 0/0/2 |
| warranty-006 | ✅ | 683 | 4.6 | support_contacts 0/0/2 |
| warranty-007 | ✅ | 699 | 5.6 | support_contacts 0/0/1 |
| warranty-008 | ✅ | 732 | 4.6 | all lists exact |
| warranty-009 | ✅ | 651 | 4.7 | support_contacts 0/0/1 |
| warranty-010 | ✅ | 700 | 4.4 | support_contacts 0/0/3 |
| warranty-011 | ✅ | 689 | 4.2 | support_contacts 0/0/1 |
| warranty-012 | ✅ | 700 | 5.5 | support_contacts 0/0/3 |
| warranty-013 | ✅ | 710 | 6.3 | support_contacts 0/0/3 |
| warranty-014 | ✅ | 692 | 4.1 | all lists exact |
| warranty-015 | ✅ | 726 | 5.9 | support_contacts 0/0/3 |
| warranty-016 | ✅ | 722 | 6.3 | all lists exact |
| warranty-017 | ✅ | 788 | 5.7 | all lists exact |
| warranty-018 | ✅ | 687 | 6.0 | support_contacts 0/0/3 |
| warranty-019 | ✅ | 706 | 8.3 | support_contacts 0/0/3 |
| warranty-020 | ✅ | 704 | 8.2 | support_contacts 0/0/2 |
| warranty-021 | ✅ | 680 | 6.6 | support_contacts 0/0/1 |
| warranty-022 | ✅ | 726 | 7.9 | all lists exact |
| warranty-023 | ✅ | 700 | 8.5 | support_contacts 0/0/1 |
| warranty-024 | ✅ | 683 | 7.6 | support_contacts 0/0/2 |
| warranty-025 | ✅ | 692 | 7.2 | support_contacts 0/0/3 |
| warranty-026 | ✅ | 726 | 5.1 | support_contacts 0/0/3 |
| warranty-027 | ✅ | 697 | 4.6 | support_contacts 0/0/3 |
| warranty-028 | ✅ | 703 | 4.4 | support_contacts 0/0/2 |
| warranty-029 | ✅ | 729 | 4.5 | all lists exact |
| warranty-030 | ✅ | 688 | 4.1 | support_contacts 0/0/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=warranty MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
