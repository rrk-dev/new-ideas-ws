# Extraction eval — `meeting` × `SmolLM2-135M-Instruct-Q8_0.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: cpu
- Model sha256: `5a1395716f791374` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `863fde7` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/meeting/`)
- Wall time: 734 s incl. model load + Dart compile · peak RSS: 505 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 44.6% |
| Prefill tok/s (median) | 188 |
| Decode tok/s (median) | 29.1 |
| Latency per case (median / max) | 9.6 s / 199.1 s |
| Prompt tokens (median / max) | 870 / 1136 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| attendees | 39.5% | 82.2% | 53.3% | 73 | 152 | – |
| decisions | 0.0% | 0.0% | 0.0% | 16 | 29 | – |
| action_items | 6.9% | 4.8% | 5.6% | 42 | 29 | owner 100.0%, due 50.0% |
| open_questions | 0.0% | 0.0% | 0.0% | 10 | 30 | – |
| topics | 10.3% | 7.1% | 8.5% | 42 | 29 | – |

Prose fields (token-set similarity to the reference, informational): title 51.8%, summary 44.8%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.action_items.recall | ≥ 80.0% | 4.8% | ❌ |
| lists.action_items.precision | ≥ 80.0% | 6.9% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| meeting-001 | ✅ | 889 | 55.4 | decisions 0/1/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |
| meeting-002 | ✅ | 860 | 68.5 | attendees 3/3/5, decisions 0/0/1, action_items 0/0/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-003 | ✅ | 840 | 22.4 | decisions 0/0/1, action_items 0/2/1, open_questions 0/1/2 |
| meeting-004 | ✅ | 892 | 26.8 | attendees 2/3/2, decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-005 | ✅ | 839 | 18.3 | attendees 1/1/2, decisions 0/1/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |
| meeting-006 | ✅ | 1136 | 17.5 | attendees 2/6/2, decisions 0/1/1, action_items 0/4/1, open_questions 0/1/1, topics 0/4/1 |
| meeting-007 | ✅ | 861 | 5.4 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-008 | ✅ | 863 | 3.5 | decisions 0/1/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-009 | ✅ | 891 | 6.9 | decisions 0/0/1, action_items 0/0/1, open_questions 0/2/1, topics 0/1/1 |
| meeting-010 | ✅ | 873 | 13.1 | attendees 2/2/20, decisions 0/1/1, action_items 1/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-011 | ✅ | 876 | 9.2 | decisions 0/2/1, action_items 0/0/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-012 | ✅ | 840 | 5.1 | attendees 1/2/2, decisions 0/0/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |
| meeting-013 | ✅ | 857 | 8.4 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 1/2/1 |
| meeting-014 | ✅ | 875 | 6.9 | decisions 0/0/1, action_items 0/3/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-015 | ✅ | 837 | 5.3 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-016 | ✅ | 876 | 4.1 | attendees 4/4/20, decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-017 | ✅ | 881 | 7.5 | attendees 0/3/2, decisions 0/1/1, action_items 0/1/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-018 | ✅ | 876 | 10.9 | attendees 0/2/0, action_items 0/2/0, topics 0/2/0 |
| meeting-019 | ✅ | 884 | 4.6 | decisions 0/1/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |
| meeting-020 | ✅ | 851 | 5.3 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-021 | ✅ | 867 | 6.6 | decisions 0/1/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-022 | ✅ | 829 | 6.6 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-023 | ✅ | 1004 | 9.9 | attendees 4/5/20, decisions 0/1/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-024 | ✅ | 896 | 9.8 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-025 | ✅ | 1028 | 19.7 | attendees 2/2/20, decisions 0/3/1, action_items 0/2/1, open_questions 0/1/1, topics 1/3/1 |
| meeting-026 | ✅ | 861 | 39.3 | decisions 0/1/1, action_items 1/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-027 | ✅ | 809 | 9.4 | decisions 0/0/1, action_items 0/0/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-028 | ✅ | 846 | 98.8 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-029 | ✅ | 839 | 199.1 | attendees 1/2/2, decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-030 | ✅ | 909 | 23.0 | attendees 3/3/20, decisions 0/1/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=meeting MODEL=SmolLM2-135M-Instruct-Q8_0.gguf`.
