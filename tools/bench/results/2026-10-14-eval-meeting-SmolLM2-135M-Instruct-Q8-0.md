# Extraction eval — `meeting` × `SmolLM2-135M-Instruct-Q8_0.gguf`

- Date: 2026-10-14 · host: Darwin arm64 · backend: cpu
- Model sha256: `5a1395716f791374` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, seed 42)
- Commit: `279469c` · llama.cpp `d81235049` · profile version 1
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/meeting/`)
- Wall time: 117 s incl. model load + Dart compile · peak RSS: 620 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 33.9% |
| Prefill tok/s (median) | 651 |
| Decode tok/s (median) | 94.3 |
| Latency per case (median / max) | 3.4 s / 6.9 s |
| Prompt tokens (median / max) | 901 / 1167 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| attendees | 35.7% | 83.6% | 50.0% | 73 | 171 | – |
| decisions | 1.7% | 6.2% | 2.7% | 16 | 59 | – |
| action_items | 3.3% | 2.4% | 2.8% | 42 | 30 | owner 0.0%, due 100.0% |
| open_questions | 0.0% | 0.0% | 0.0% | 10 | 49 | – |
| topics | 6.7% | 4.8% | 5.6% | 42 | 30 | – |

Prose fields (token-set similarity to the reference, informational): title 52.8%, summary 43.2%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.action_items.recall | ≥ 80.0% | 2.4% | ❌ |
| lists.action_items.precision | ≥ 80.0% | 3.3% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| meeting-001 | ✅ | 920 | 6.9 | decisions 0/1/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |
| meeting-002 | ✅ | 891 | 5.1 | attendees 3/3/20, decisions 0/0/1, action_items 0/0/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-003 | ✅ | 871 | 6.7 | attendees 2/2/3, decisions 0/0/1, action_items 1/2/1, open_questions 0/1/1 |
| meeting-004 | ✅ | 923 | 4.6 | attendees 2/3/2, decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-005 | ✅ | 870 | 2.7 | attendees 1/1/2, decisions 0/1/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |
| meeting-006 | ✅ | 1167 | 4.2 | attendees 2/6/2, decisions 0/1/1, action_items 0/4/1, open_questions 0/1/1, topics 0/4/1 |
| meeting-007 | ✅ | 892 | 2.9 | attendees 2/2/3, decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-008 | ✅ | 894 | 2.2 | decisions 0/1/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-009 | ✅ | 922 | 2.8 | decisions 0/0/1, action_items 0/0/1, open_questions 0/2/1, topics 0/1/1 |
| meeting-010 | ✅ | 904 | 2.9 | attendees 2/2/20, decisions 0/1/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-011 | ✅ | 907 | 6.3 | decisions 1/2/30, action_items 0/0/1, open_questions 0/0/20, topics 0/2/1 |
| meeting-012 | ✅ | 871 | 4.7 | attendees 1/2/2, decisions 0/0/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |
| meeting-013 | ✅ | 888 | 6.2 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-014 | ✅ | 906 | 6.0 | decisions 0/0/1, action_items 0/3/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-015 | ✅ | 868 | 5.9 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-016 | ✅ | 907 | 2.4 | attendees 4/4/20, decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-017 | ✅ | 912 | 5.6 | attendees 0/3/2, decisions 0/1/1, action_items 0/1/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-018 | ✅ | 907 | 2.2 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-019 | ✅ | 915 | 1.5 | decisions 0/1/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |
| meeting-020 | ✅ | 882 | 1.6 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-021 | ✅ | 898 | 1.8 | decisions 0/1/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-022 | ✅ | 860 | 1.4 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-023 | ✅ | 1035 | 2.0 | attendees 5/5/20, decisions 0/1/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-024 | ✅ | 927 | 1.6 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/2/1 |
| meeting-025 | ✅ | 1059 | 2.8 | attendees 2/2/20, decisions 0/3/1, action_items 0/2/1, open_questions 0/1/1, topics 1/3/1 |
| meeting-026 | ✅ | 892 | 5.1 | attendees 0/2/2, decisions 0/1/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-027 | ✅ | 840 | 3.6 | decisions 0/0/1, action_items 0/0/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-028 | ✅ | 877 | 3.7 | decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-029 | ✅ | 870 | 3.2 | attendees 1/2/2, decisions 0/0/1, action_items 0/2/1, open_questions 0/0/1, topics 0/1/1 |
| meeting-030 | ✅ | 940 | 3.8 | attendees 3/3/20, decisions 0/1/1, action_items 0/1/1, open_questions 0/1/1, topics 0/1/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=meeting MODEL=SmolLM2-135M-Instruct-Q8_0.gguf`.
