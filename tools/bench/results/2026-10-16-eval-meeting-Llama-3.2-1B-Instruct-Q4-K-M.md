# Extraction eval — `meeting` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-16 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `ebf4ff7` · llama.cpp `ebf4ff7` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/meeting/`)
- Wall time: 109 s incl. model load + Dart compile · peak RSS: 1180 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 0.0% |
| Prefill tok/s (median) | 2937 |
| Decode tok/s (median) | 85.5 |
| Latency per case (median / max) | 3.7 s / 1054.6 s |
| Prompt tokens (median / max) | 636 / 855 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| attendees | 100.0% | 91.8% | 95.7% | 73 | 67 | – |
| decisions | 20.0% | 81.2% | 32.1% | 16 | 65 | – |
| action_items | 54.4% | 88.1% | 67.3% | 42 | 68 | owner 67.6%, due 51.4% |
| open_questions | 15.2% | 50.0% | 23.3% | 10 | 33 | – |
| topics | 45.6% | 61.9% | 52.5% | 42 | 57 | – |

Prose fields (token-set similarity to the reference, informational): title 74.7%, summary 73.5%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.action_items.recall | ≥ 80.0% | 88.1% | ✅ |
| lists.action_items.precision | ≥ 80.0% | 54.4% | ❌ |
| lists.action_items.owner_accuracy | ≥ 70.0% | 67.6% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| meeting-001 | ✅ | 656 | 43.6 | action_items 1/1/2, open_questions 0/1/0, topics 0/1/1 |
| meeting-002 | ✅ | 628 | 1.6 | action_items 0/0/2, topics 1/2/1 |
| meeting-003 | ✅ | 619 | 10.6 | decisions 0/0/2, open_questions 0/1/1 |
| meeting-004 | ✅ | 655 | 1054.6 | decisions 0/0/1, action_items 1/2/2, open_questions 0/0/1 |
| meeting-005 | ✅ | 615 | 2.5 | decisions 1/1/3, action_items 1/1/2, topics 0/1/2 |
| meeting-006 | ✅ | 855 | 943.8 | attendees 1/6/1, action_items 2/4/3, open_questions 0/1/1, topics 3/4/6 |
| meeting-007 | ✅ | 628 | 2.1 | decisions 0/0/2, action_items 1/1/2, open_questions 0/0/1, topics 1/1/2 |
| meeting-008 | ✅ | 635 | 926.7 | decisions 1/1/2, action_items 1/1/2, open_questions 0/0/2, topics 0/1/5 |
| meeting-009 | ✅ | 655 | 1.9 | decisions 0/0/2, action_items 0/0/2, open_questions 1/2/1 |
| meeting-010 | ✅ | 638 | 1.9 | decisions 0/1/2, open_questions 0/0/2, topics 0/1/1 |
| meeting-011 | ✅ | 641 | 1045.1 | action_items 0/0/2, topics 1/2/2 |
| meeting-012 | ✅ | 616 | 923.5 | decisions 0/0/2, action_items 1/1/4, open_questions 0/1/2 |
| meeting-013 | ✅ | 629 | 2.0 | decisions 0/0/1, action_items 1/1/2, topics 1/2/1 |
| meeting-014 | ✅ | 639 | 2.0 | decisions 0/0/4, action_items 2/3/3, open_questions 0/0/1 |
| meeting-015 | ✅ | 613 | 969.4 | decisions 0/0/2, action_items 1/1/2, open_questions 0/0/2, topics 0/1/2 |
| meeting-016 | ✅ | 646 | 997.2 | decisions 0/0/1, action_items 1/1/4, open_questions 0/0/1, topics 1/2/4 |
| meeting-017 | ✅ | 648 | 2.1 | decisions 1/1/2, action_items 1/1/2, open_questions 0/0/3, topics 1/2/4 |
| meeting-018 | ✅ | 644 | 299.2 | decisions 0/0/3, open_questions 0/0/1, topics 1/2/1 |
| meeting-019 | ✅ | 647 | 2.1 | decisions 1/1/2, action_items 0/1/2, topics 0/1/3 |
| meeting-020 | ✅ | 627 | 4.8 | decisions 0/0/2, open_questions 0/0/1, topics 1/1/2 |
| meeting-021 | ✅ | 635 | 1.2 | decisions 1/1/2 |
| meeting-022 | ✅ | 602 | 1047.9 | decisions 0/0/2, action_items 1/1/2, open_questions 0/0/1 |
| meeting-023 | ✅ | 744 | 2.6 | decisions 1/1/10, open_questions 0/0/3, topics 1/1/3 |
| meeting-024 | ✅ | 656 | 918.4 | decisions 0/0/3, action_items 2/2/3, open_questions 0/0/1, topics 0/2/1 |
| meeting-025 | ✅ | 766 | 2.3 | action_items 2/2/3, topics 2/3/3 |
| meeting-026 | ✅ | 633 | 954.2 | decisions 0/1/2, action_items 2/2/3, open_questions 0/0/1 |
| meeting-027 | ✅ | 589 | 1.8 | decisions 0/0/1, action_items 0/0/2, open_questions 0/0/1 |
| meeting-028 | ✅ | 619 | 932.3 | decisions 0/0/1, open_questions 0/0/1, topics 1/1/2 |
| meeting-029 | ✅ | 610 | 1.9 | attendees 1/2/1, decisions 0/0/1, open_questions 0/0/1 |
| meeting-030 | ✅ | 670 | 1.8 | decisions 0/1/3, action_items 1/1/2 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=meeting MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
