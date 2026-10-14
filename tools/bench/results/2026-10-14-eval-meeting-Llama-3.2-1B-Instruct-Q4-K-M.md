# Extraction eval — `meeting` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `279469c` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/meeting/`)
- Wall time: 74 s incl. model load + Dart compile · peak RSS: 1151 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 96.7% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 5.5% |
| Prefill tok/s (median) | 3627 |
| Decode tok/s (median) | 92.8 |
| Latency per case (median / max) | 1.7 s / 10.9 s |
| Prompt tokens (median / max) | 784 / 1003 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| attendees | 100.0% | 90.4% | 95.0% | 73 | 66 | – |
| decisions | 12.9% | 68.8% | 21.8% | 16 | 85 | – |
| action_items | 59.5% | 52.4% | 55.7% | 42 | 37 | owner 54.5%, due 77.3% |
| open_questions | 5.4% | 60.0% | 9.8% | 10 | 112 | – |
| topics | 31.8% | 64.3% | 42.5% | 42 | 85 | – |

Prose fields (token-set similarity to the reference, informational): title 75.1%, summary 76.5%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.action_items.recall | ≥ 80.0% | 52.4% | ❌ |
| lists.action_items.precision | ≥ 80.0% | 59.5% | ❌ |
| schema_valid | ≥ 99.0% | 96.7% | ❌ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| meeting-001 | ✅ | 804 | 6.4 | decisions 0/1/30, open_questions 1/1/20, topics 0/1/10 |
| meeting-002 | ✅ | 776 | 3.4 | decisions 0/0/1, action_items 0/0/1, open_questions 0/0/20, topics 1/2/1 |
| meeting-003 | ✅ | 767 | 1.7 | decisions 0/0/3, action_items 1/2/1, open_questions 0/1/1 |
| meeting-004 | ✅ | 803 | 1.8 | decisions 0/0/1, action_items 1/2/1, open_questions 0/0/2, topics 1/1/3 |
| meeting-005 | ✅ | 763 | 1.5 | open_questions 0/1/2, topics 1/1/2 |
| meeting-006 | ❌ | 1003 | 10.9 | attendees 0/6/0, decisions 0/1/0, action_items 0/4/0, open_questions 0/1/0, topics 0/4/0 |
| meeting-007 | ✅ | 776 | 1.7 | decisions 0/0/1, open_questions 0/0/2, topics 1/1/2 |
| meeting-008 | ✅ | 783 | 1.4 | decisions 0/1/2, open_questions 0/0/2, topics 0/1/2 |
| meeting-009 | ✅ | 803 | 1.6 | decisions 0/0/2, action_items 0/0/1, open_questions 1/2/2 |
| meeting-010 | ✅ | 786 | 1.7 | decisions 1/1/2, action_items 1/2/1, open_questions 0/0/2, topics 0/1/2 |
| meeting-011 | ✅ | 789 | 1.5 | action_items 0/0/1, open_questions 0/0/1 |
| meeting-012 | ✅ | 764 | 1.8 | decisions 0/0/2, open_questions 1/1/2, topics 1/1/3 |
| meeting-013 | ✅ | 777 | 1.6 | decisions 0/0/2, action_items 0/1/1, open_questions 0/0/2 |
| meeting-014 | ✅ | 787 | 1.7 | decisions 0/0/3, action_items 1/3/1, open_questions 0/0/2, topics 1/1/4 |
| meeting-015 | ✅ | 761 | 1.9 | decisions 0/0/2, open_questions 0/0/2, topics 0/1/3 |
| meeting-016 | ✅ | 794 | 2.7 | attendees 3/4/3, decisions 0/0/4, action_items 1/1/4, open_questions 0/0/4, topics 0/2/4 |
| meeting-017 | ✅ | 796 | 1.7 | decisions 1/1/2, open_questions 0/0/2, topics 1/2/3 |
| meeting-018 | ✅ | 792 | 2.1 | decisions 0/0/3, action_items 0/2/1, open_questions 0/0/3, topics 1/2/6 |
| meeting-019 | ✅ | 795 | 1.6 | decisions 1/1/2, action_items 0/1/1, open_questions 1/1/2, topics 0/1/2 |
| meeting-020 | ✅ | 775 | 1.4 | decisions 0/0/2, action_items 1/2/1, open_questions 0/0/2, topics 1/1/3 |
| meeting-021 | ✅ | 783 | 1.4 | decisions 1/1/2, open_questions 0/0/2, topics 1/1/2 |
| meeting-022 | ✅ | 750 | 1.4 | decisions 0/0/1, open_questions 0/0/2, topics 1/1/3 |
| meeting-023 | ✅ | 892 | 2.0 | action_items 1/2/1, open_questions 0/0/1 |
| meeting-024 | ✅ | 804 | 1.7 | decisions 0/0/2, open_questions 0/0/2, topics 1/2/3 |
| meeting-025 | ✅ | 914 | 5.0 | decisions 2/3/5, action_items 0/2/4, open_questions 1/1/20, topics 3/3/5 |
| meeting-026 | ✅ | 781 | 1.9 | open_questions 0/0/2, topics 1/1/6 |
| meeting-027 | ✅ | 737 | 1.2 | decisions 0/0/1, action_items 0/0/1, open_questions 0/0/2 |
| meeting-028 | ✅ | 767 | 1.9 | decisions 0/0/3, action_items 1/2/1, open_questions 0/0/3, topics 1/1/4 |
| meeting-029 | ✅ | 758 | 1.4 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1 |
| meeting-030 | ✅ | 818 | 1.7 | decisions 0/1/1, open_questions 1/1/2, topics 1/1/3 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=meeting MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
