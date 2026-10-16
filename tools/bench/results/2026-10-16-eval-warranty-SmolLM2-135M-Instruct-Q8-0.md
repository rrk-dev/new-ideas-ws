# Extraction eval — `warranty` × `SmolLM2-135M-Instruct-Q8_0.gguf`

- Date: 2026-10-16 · host: Darwin arm64 · backend: gpu
- Model sha256: `5a1395716f791374` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `ebf4ff7` · llama.cpp `ebf4ff7` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/warranty/`)
- Wall time: 25 s incl. model load + Dart compile · peak RSS: 530 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 36.7% |
| Prefill tok/s (median) | 21715 |
| Decode tok/s (median) | 245.1 |
| Latency per case (median / max) | 0.6 s / 1044.9 s |
| Prompt tokens (median / max) | 776 / 889 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| support_contacts | 9.6% | 55.6% | 16.4% | 9 | 52 | – |

## Scalar fields

| Field | Exact | Fuzzy |
|---|---|---|
| product | 20.0% | 33.3% |
| brand | 13.3% | 26.7% |
| model | 13.3% | 43.3% |
| serial_number | 6.7% | 6.7% |
| purchase_date | 0.0% | 0.0% |
| retailer | 36.7% | 70.0% |
| price | 3.3% | 43.3% |
| warranty_period | 3.3% | 3.3% |
| **all (field accuracy)** | 12.1% | 28.3% |

Prose fields (token-set similarity to the reference, informational): notes 37.0%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| scalars.accuracy | ≥ 90.0% | 28.3% | ❌ |
| scalars.serial_number.exact | ≥ 85.0% | 6.7% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| warranty-001 | ✅ | 798 | 0.7 | support_contacts 0/0/1 |
| warranty-002 | ✅ | 757 | 0.5 | support_contacts 0/0/2 |
| warranty-003 | ✅ | 802 | 0.8 | support_contacts 1/1/3 |
| warranty-004 | ✅ | 770 | 1019.1 | all lists exact |
| warranty-005 | ✅ | 788 | 0.8 | support_contacts 0/0/2 |
| warranty-006 | ✅ | 759 | 0.5 | support_contacts 0/0/3 |
| warranty-007 | ✅ | 776 | 0.6 | support_contacts 0/0/2 |
| warranty-008 | ✅ | 807 | 0.7 | support_contacts 0/1/2 |
| warranty-009 | ✅ | 712 | 0.6 | support_contacts 0/0/2 |
| warranty-010 | ✅ | 776 | 0.6 | support_contacts 0/0/1 |
| warranty-011 | ✅ | 758 | 1002.1 | support_contacts 0/0/2 |
| warranty-012 | ✅ | 773 | 0.7 | support_contacts 0/0/2 |
| warranty-013 | ✅ | 785 | 0.5 | support_contacts 0/0/1 |
| warranty-014 | ✅ | 767 | 0.8 | all lists exact |
| warranty-015 | ✅ | 804 | 0.6 | support_contacts 0/0/2 |
| warranty-016 | ✅ | 804 | 0.6 | all lists exact |
| warranty-017 | ✅ | 889 | 0.8 | support_contacts 0/1/1 |
| warranty-018 | ✅ | 755 | 1001.9 | support_contacts 0/0/2 |
| warranty-019 | ✅ | 779 | 0.6 | support_contacts 0/0/2 |
| warranty-020 | ✅ | 774 | 0.7 | support_contacts 0/0/2 |
| warranty-021 | ✅ | 748 | 0.6 | support_contacts 0/0/3 |
| warranty-022 | ✅ | 813 | 0.8 | support_contacts 1/2/1 |
| warranty-023 | ✅ | 774 | 0.5 | support_contacts 0/0/1 |
| warranty-024 | ✅ | 752 | 0.6 | support_contacts 0/0/2 |
| warranty-025 | ✅ | 760 | 0.5 | support_contacts 0/0/1 |
| warranty-026 | ✅ | 809 | 1044.9 | support_contacts 0/0/2 |
| warranty-027 | ✅ | 778 | 0.6 | support_contacts 0/0/2 |
| warranty-028 | ✅ | 780 | 0.6 | support_contacts 0/0/2 |
| warranty-029 | ✅ | 810 | 0.6 | support_contacts 0/1/1 |
| warranty-030 | ✅ | 757 | 0.6 | support_contacts 0/0/2 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=warranty MODEL=SmolLM2-135M-Instruct-Q8_0.gguf`.
