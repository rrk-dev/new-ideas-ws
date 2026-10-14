# Extraction eval — `meeting` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `863fde7` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/meeting/`)
- Wall time: 82 s incl. model load + Dart compile · peak RSS: 1222 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 7.3% |
| Prefill tok/s (median) | 3286 |
| Decode tok/s (median) | 80.2 |
| Latency per case (median / max) | 1.9 s / 8.0 s |
| Prompt tokens (median / max) | 755 / 974 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| attendees | 98.6% | 100.0% | 99.3% | 73 | 74 | – |
| decisions | 8.6% | 75.0% | 15.5% | 16 | 139 | – |
| action_items | 52.2% | 57.1% | 54.5% | 42 | 46 | owner 66.7%, due 70.8% |
| open_questions | 5.6% | 70.0% | 10.3% | 10 | 126 | – |
| topics | 28.3% | 71.4% | 40.5% | 42 | 106 | – |

Prose fields (token-set similarity to the reference, informational): title 77.4%, summary 80.5%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.action_items.recall | ≥ 80.0% | 57.1% | ❌ |
| lists.action_items.precision | ≥ 80.0% | 52.2% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| meeting-001 | ✅ | 775 | 5.8 | decisions 0/1/30, open_questions 1/1/20, topics 0/1/10 |
| meeting-002 | ✅ | 747 | 1.3 | action_items 0/0/1, topics 1/2/1 |
| meeting-003 | ✅ | 738 | 1.8 | decisions 0/0/2, action_items 1/2/1, open_questions 0/1/1, topics 1/1/3 |
| meeting-004 | ✅ | 774 | 1.8 | decisions 0/0/1, action_items 1/2/1, open_questions 0/0/2, topics 1/1/3 |
| meeting-005 | ✅ | 734 | 1.6 | open_questions 0/1/2, topics 1/1/2 |
| meeting-006 | ✅ | 974 | 8.0 | decisions 1/1/30, action_items 4/4/5, open_questions 1/1/20, topics 3/4/10 |
| meeting-007 | ✅ | 747 | 2.0 | decisions 0/0/1, open_questions 0/0/2, topics 1/1/2 |
| meeting-008 | ✅ | 754 | 1.7 | decisions 1/1/2, action_items 0/1/1, open_questions 0/0/2, topics 0/1/1 |
| meeting-009 | ✅ | 774 | 2.0 | decisions 0/0/3, action_items 0/0/1, open_questions 2/2/3 |
| meeting-010 | ✅ | 757 | 2.4 | decisions 1/1/3, open_questions 0/0/2, topics 0/1/3 |
| meeting-011 | ✅ | 760 | 2.2 | action_items 0/0/2 |
| meeting-012 | ✅ | 735 | 1.9 | decisions 0/0/1, action_items 0/1/1, open_questions 0/1/2, topics 1/1/3 |
| meeting-013 | ✅ | 748 | 1.9 | decisions 0/0/2, action_items 0/1/1, open_questions 0/0/2 |
| meeting-014 | ✅ | 758 | 1.8 | decisions 0/0/3, action_items 1/3/1, open_questions 0/0/1, topics 1/1/3 |
| meeting-015 | ✅ | 732 | 2.1 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/2, topics 0/1/3 |
| meeting-016 | ✅ | 765 | 3.7 | decisions 0/0/4, action_items 1/1/4, open_questions 0/0/3, topics 0/2/10 |
| meeting-017 | ✅ | 767 | 2.2 | decisions 1/1/2, action_items 0/1/1, open_questions 0/0/2, topics 2/2/3 |
| meeting-018 | ✅ | 763 | 2.2 | decisions 0/0/3, action_items 1/2/1, open_questions 0/0/3, topics 1/2/4 |
| meeting-019 | ✅ | 766 | 1.7 | decisions 1/1/2, action_items 0/1/1, open_questions 1/1/2, topics 0/1/2 |
| meeting-020 | ✅ | 746 | 1.5 | decisions 0/0/2, action_items 1/2/1, open_questions 0/0/2, topics 1/1/2 |
| meeting-021 | ✅ | 754 | 1.7 | open_questions 0/0/2 |
| meeting-022 | ✅ | 721 | 1.5 | decisions 0/0/1, open_questions 0/0/1, topics 1/1/2 |
| meeting-023 | ✅ | 863 | 6.1 | decisions 1/1/4, action_items 2/2/5, open_questions 0/0/20, topics 1/1/10 |
| meeting-024 | ✅ | 775 | 5.2 | decisions 0/0/30, action_items 1/2/1, open_questions 0/0/20, topics 0/2/10 |
| meeting-025 | ✅ | 885 | 2.9 | decisions 1/3/3, action_items 0/2/3, open_questions 1/1/2, topics 3/3/4 |
| meeting-026 | ✅ | 752 | 1.9 | open_questions 0/0/1 |
| meeting-027 | ✅ | 708 | 1.5 | decisions 0/0/1, action_items 0/0/1, open_questions 0/0/2 |
| meeting-028 | ✅ | 738 | 1.8 | attendees 2/2/3, decisions 0/0/1, action_items 1/2/1, open_questions 0/0/1 |
| meeting-029 | ✅ | 729 | 2.0 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/2, topics 1/1/3 |
| meeting-030 | ✅ | 789 | 2.4 | decisions 0/1/1, open_questions 1/1/2, topics 1/1/3 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=meeting MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
