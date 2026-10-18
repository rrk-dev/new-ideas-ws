# Extraction eval — `meeting` × `Llama-3.2-3B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6c1a2b4116103267` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/meeting/`)
- Wall time: 298 s incl. model load + Dart compile · peak RSS: 3130 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 2.5% |
| Prefill tok/s (median) | 142 |
| Decode tok/s (median) | 32.2 |
| Latency per case (median / max) | 9.2 s / 16.2 s |
| Prompt tokens (median / max) | 636 / 855 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| attendees | 100.0% | 100.0% | 100.0% | 73 | 73 | – |
| decisions | 37.1% | 81.2% | 51.0% | 16 | 35 | – |
| action_items | 72.5% | 88.1% | 79.6% | 42 | 51 | owner 91.9%, due 91.9% |
| open_questions | 50.0% | 70.0% | 58.3% | 10 | 14 | – |
| topics | 60.7% | 40.5% | 48.6% | 42 | 28 | – |

Prose fields (token-set similarity to the reference, informational): title 75.5%, summary 75.4%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.action_items.recall | ≥ 80.0% | 88.1% | ✅ |
| lists.action_items.precision | ≥ 80.0% | 72.5% | ❌ |
| lists.action_items.owner_accuracy | ≥ 70.0% | 91.9% | ✅ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| meeting-001 | ✅ | 656 | 15.8 | decisions 1/1/2, action_items 1/1/2, open_questions 0/1/0, topics 0/1/0 |
| meeting-002 | ✅ | 628 | 10.7 | action_items 0/0/1, topics 0/2/0 |
| meeting-003 | ✅ | 619 | 8.3 | decisions 0/0/1, open_questions 0/1/1, topics 0/1/0 |
| meeting-004 | ✅ | 655 | 7.5 | decisions 0/0/1, action_items 1/2/1, topics 0/1/0 |
| meeting-005 | ✅ | 615 | 7.1 | topics 0/1/0 |
| meeting-006 | ✅ | 855 | 16.2 | decisions 1/1/5, open_questions 1/1/2, topics 3/4/5 |
| meeting-007 | ✅ | 628 | 11.4 | decisions 0/0/1, action_items 1/1/2, topics 1/1/2 |
| meeting-008 | ✅ | 635 | 12.4 | decisions 1/1/2, action_items 1/1/2, topics 0/1/1 |
| meeting-009 | ✅ | 655 | 10.2 | all lists exact |
| meeting-010 | ✅ | 638 | 11.7 | topics 0/1/1 |
| meeting-011 | ✅ | 641 | 8.3 | action_items 0/0/1 |
| meeting-012 | ✅ | 616 | 7.3 | action_items 1/1/2, topics 0/1/0 |
| meeting-013 | ✅ | 629 | 10.0 | decisions 0/0/1, action_items 0/1/1, open_questions 0/0/1, topics 1/2/1 |
| meeting-014 | ✅ | 639 | 10.2 | decisions 0/0/1, action_items 2/3/3, topics 0/1/0 |
| meeting-015 | ✅ | 613 | 8.7 | decisions 0/0/1, action_items 1/1/2, topics 0/1/1 |
| meeting-016 | ✅ | 646 | 9.2 | decisions 0/0/1, action_items 1/1/3, open_questions 0/0/1, topics 1/2/4 |
| meeting-017 | ✅ | 648 | 7.8 | action_items 0/1/1, topics 0/2/0 |
| meeting-018 | ✅ | 644 | 8.8 | decisions 0/0/1, action_items 1/2/1, open_questions 0/0/1, topics 1/2/1 |
| meeting-019 | ✅ | 647 | 11.9 | decisions 1/1/2, open_questions 0/1/0, topics 0/1/1 |
| meeting-020 | ✅ | 627 | 10.2 | all lists exact |
| meeting-021 | ✅ | 635 | 10.3 | decisions 1/1/2, topics 0/1/0 |
| meeting-022 | ✅ | 602 | 6.8 | decisions 0/0/1, topics 0/1/0 |
| meeting-023 | ✅ | 744 | 9.2 | topics 0/1/0 |
| meeting-024 | ✅ | 656 | 9.3 | decisions 0/0/1, open_questions 0/0/1, topics 0/2/0 |
| meeting-025 | ✅ | 766 | 10.4 | decisions 2/3/2, topics 2/3/3 |
| meeting-026 | ✅ | 633 | 8.2 | decisions 0/1/2 |
| meeting-027 | ✅ | 589 | 6.6 | action_items 0/0/2, open_questions 0/0/1 |
| meeting-028 | ✅ | 619 | 8.8 | decisions 0/0/1 |
| meeting-029 | ✅ | 610 | 6.8 | topics 0/1/0 |
| meeting-030 | ✅ | 670 | 8.1 | decisions 0/1/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=meeting MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf`.
