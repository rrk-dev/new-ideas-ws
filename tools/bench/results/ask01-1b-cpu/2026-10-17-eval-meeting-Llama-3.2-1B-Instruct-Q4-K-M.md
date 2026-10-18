# Extraction eval — `meeting` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/meeting/`)
- Wall time: 225 s incl. model load + Dart compile · peak RSS: 1987 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 0.0% |
| Prefill tok/s (median) | 252 |
| Decode tok/s (median) | 48.2 |
| Latency per case (median / max) | 6.6 s / 18.6 s |
| Prompt tokens (median / max) | 636 / 855 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| attendees | 100.0% | 98.6% | 99.3% | 73 | 72 | – |
| decisions | 18.3% | 81.2% | 29.9% | 16 | 71 | – |
| action_items | 56.5% | 92.9% | 70.3% | 42 | 69 | owner 69.2%, due 59.0% |
| open_questions | 25.8% | 80.0% | 39.0% | 10 | 31 | – |
| topics | 51.9% | 66.7% | 58.3% | 42 | 54 | – |

Prose fields (token-set similarity to the reference, informational): title 76.9%, summary 71.7%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.action_items.recall | ≥ 80.0% | 92.9% | ✅ |
| lists.action_items.precision | ≥ 80.0% | 56.5% | ❌ |
| lists.action_items.owner_accuracy | ≥ 70.0% | 69.2% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| meeting-001 | ✅ | 656 | 5.4 | action_items 1/1/3, open_questions 0/1/0, topics 0/1/1 |
| meeting-002 | ✅ | 628 | 18.6 | decisions 0/0/2, action_items 0/0/2, open_questions 0/0/2, topics 1/2/1 |
| meeting-003 | ✅ | 619 | 10.8 | attendees 1/2/1, decisions 0/0/2, open_questions 0/1/1 |
| meeting-004 | ✅ | 655 | 5.9 | decisions 0/0/2, open_questions 0/0/1 |
| meeting-005 | ✅ | 615 | 5.9 | decisions 0/1/1, action_items 1/1/2, topics 0/1/1 |
| meeting-006 | ✅ | 855 | 11.0 | decisions 1/1/7, action_items 3/4/4, topics 2/4/6 |
| meeting-007 | ✅ | 628 | 7.7 | decisions 0/0/3, action_items 0/1/3, open_questions 0/0/1, topics 1/1/5 |
| meeting-008 | ✅ | 635 | 6.0 | decisions 1/1/2, action_items 1/1/2, open_questions 0/0/2 |
| meeting-009 | ✅ | 655 | 6.6 | decisions 0/0/1, action_items 0/0/2 |
| meeting-010 | ✅ | 638 | 6.6 | decisions 0/1/2, open_questions 0/0/2, topics 0/1/1 |
| meeting-011 | ✅ | 641 | 6.2 | action_items 0/0/2, topics 2/2/3 |
| meeting-012 | ✅ | 616 | 5.0 | decisions 0/0/2, action_items 1/1/2, open_questions 1/1/2 |
| meeting-013 | ✅ | 629 | 9.3 | decisions 0/0/1, action_items 1/1/2, topics 1/2/1 |
| meeting-014 | ✅ | 639 | 7.0 | decisions 0/0/4, open_questions 0/0/1 |
| meeting-015 | ✅ | 613 | 5.5 | decisions 0/0/1, action_items 1/1/2, topics 0/1/1 |
| meeting-016 | ✅ | 646 | 7.0 | decisions 0/0/1, action_items 1/1/4, open_questions 0/0/1, topics 1/2/3 |
| meeting-017 | ✅ | 648 | 5.6 | decisions 1/1/2, action_items 1/1/2, open_questions 0/0/3, topics 2/2/5 |
| meeting-018 | ✅ | 644 | 4.6 | decisions 0/0/3, open_questions 0/0/1, topics 1/2/1 |
| meeting-019 | ✅ | 647 | 6.9 | decisions 1/1/2, action_items 0/1/2, topics 0/1/2 |
| meeting-020 | ✅ | 627 | 4.8 | decisions 0/0/2, open_questions 0/0/1 |
| meeting-021 | ✅ | 635 | 8.6 | decisions 1/1/3, action_items 1/1/3, open_questions 0/0/1 |
| meeting-022 | ✅ | 602 | 5.8 | decisions 0/0/1, action_items 1/1/2, topics 1/1/2 |
| meeting-023 | ✅ | 744 | 11.7 | decisions 1/1/9, open_questions 0/0/3, topics 1/1/3 |
| meeting-024 | ✅ | 656 | 7.9 | decisions 0/0/2, topics 0/2/2 |
| meeting-025 | ✅ | 766 | 8.1 | action_items 2/2/3, topics 2/3/3 |
| meeting-026 | ✅ | 633 | 5.8 | decisions 1/1/2, open_questions 0/0/1 |
| meeting-027 | ✅ | 589 | 6.6 | decisions 0/0/1, action_items 0/0/2, open_questions 0/0/1 |
| meeting-028 | ✅ | 619 | 6.6 | decisions 0/0/3 |
| meeting-029 | ✅ | 610 | 5.9 | decisions 0/0/1 |
| meeting-030 | ✅ | 670 | 7.6 | decisions 0/1/3, action_items 1/1/2 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=meeting MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
