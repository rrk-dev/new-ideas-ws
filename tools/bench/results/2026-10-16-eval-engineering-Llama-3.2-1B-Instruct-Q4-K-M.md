# Extraction eval — `engineering` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-16 · host: Darwin arm64 · backend: gpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `ebf4ff7` · llama.cpp `ebf4ff7` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/engineering/`)
- Wall time: 129 s incl. model load + Dart compile · peak RSS: 1072 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 5.9% |
| Prefill tok/s (median) | 3704 |
| Decode tok/s (median) | 97.6 |
| Latency per case (median / max) | 4.1 s / 6.6 s |
| Prompt tokens (median / max) | 810 / 904 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| concepts | 32.5% | 75.0% | 45.4% | 36 | 83 | – |
| api_designs | 2.8% | 22.2% | 4.9% | 9 | 72 | – |
| tradeoffs | 35.8% | 75.0% | 48.5% | 32 | 67 | – |
| decisions | 22.7% | 84.6% | 35.8% | 26 | 97 | – |
| todos | 40.3% | 78.1% | 53.2% | 32 | 62 | owner 72.0% |
| open_questions | 6.5% | 66.7% | 11.9% | 9 | 92 | – |

Prose fields (token-set similarity to the reference, informational): title 72.8%, context 76.3%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.todos.recall | ≥ 80.0% | 78.1% | ❌ |
| lists.tradeoffs.recall | ≥ 70.0% | 75.0% | ✅ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| engineering-001 | ✅ | 814 | 3.3 | concepts 0/1/2, api_designs 0/0/2, decisions 1/1/2, todos 1/1/2, open_questions 0/1/1 |
| engineering-002 | ✅ | 814 | 4.3 | concepts 0/0/3, api_designs 0/1/3, tradeoffs 0/0/3, decisions 1/1/3, todos 0/1/2, open_questions 0/0/1 |
| engineering-003 | ✅ | 853 | 4.5 | concepts 1/2/3, api_designs 0/0/2, decisions 1/1/4, todos 1/1/2, open_questions 0/0/4 |
| engineering-004 | ✅ | 787 | 4.1 | concepts 0/0/2, api_designs 0/0/2, decisions 0/0/2, todos 0/0/2, open_questions 1/1/5 |
| engineering-005 | ✅ | 775 | 6.4 | concepts 1/1/4, api_designs 0/0/2, tradeoffs 0/0/5, decisions 0/0/3, todos 1/1/3, open_questions 0/0/3 |
| engineering-006 | ✅ | 852 | 5.2 | concepts 1/2/3, api_designs 0/0/5, tradeoffs 1/2/2, decisions 1/1/5, todos 1/1/2, open_questions 0/1/2 |
| engineering-007 | ✅ | 795 | 4.0 | concepts 0/1/2, api_designs 0/1/2, decisions 1/1/4, todos 1/1/2, open_questions 0/0/3 |
| engineering-008 | ✅ | 780 | 4.1 | concepts 0/0/8, api_designs 0/0/2, tradeoffs 0/0/2, decisions 0/0/2, todos 2/3/2, open_questions 0/0/3 |
| engineering-009 | ✅ | 839 | 5.5 | concepts 2/2/3, api_designs 0/0/3, tradeoffs 1/1/3, decisions 1/1/4, todos 1/1/3, open_questions 1/1/3 |
| engineering-010 | ✅ | 798 | 3.3 | concepts 1/1/2, api_designs 0/0/2, tradeoffs 0/0/2, decisions 0/1/3, todos 1/1/2, open_questions 0/0/3 |
| engineering-011 | ✅ | 812 | 3.3 | concepts 1/1/2, api_designs 0/1/1, decisions 1/1/4, todos 0/1/1, open_questions 0/0/5 |
| engineering-012 | ✅ | 810 | 4.6 | concepts 2/3/3, api_designs 0/0/3, tradeoffs 0/0/3, decisions 0/0/3, todos 0/0/3, open_questions 0/1/1 |
| engineering-013 | ✅ | 826 | 4.1 | concepts 2/2/4, api_designs 0/0/3, tradeoffs 1/1/3, decisions 1/1/3, todos 1/1/2, open_questions 0/0/3 |
| engineering-014 | ✅ | 819 | 4.0 | concepts 2/2/3, decisions 1/1/3, todos 1/1/3, open_questions 0/0/3 |
| engineering-015 | ✅ | 782 | 3.7 | concepts 1/1/3, api_designs 0/0/2, tradeoffs 0/0/2, decisions 1/1/4, todos 1/2/2, open_questions 1/1/4 |
| engineering-016 | ✅ | 803 | 4.5 | concepts 1/1/3, api_designs 0/0/2, tradeoffs 1/2/2, decisions 0/1/5, todos 1/1/2, open_questions 0/0/4 |
| engineering-017 | ✅ | 904 | 5.8 | concepts 3/3/4, api_designs 0/1/5, tradeoffs 0/1/2, decisions 0/2/6, todos 2/2/3, open_questions 1/1/4 |
| engineering-018 | ✅ | 796 | 2.7 | concepts 0/1/2, api_designs 0/0/2, tradeoffs 0/0/2, decisions 1/1/2, open_questions 0/0/2 |
| engineering-019 | ✅ | 844 | 4.0 | concepts 1/2/2, api_designs 0/0/2, tradeoffs 1/2/2, decisions 1/1/4, todos 1/1/3, open_questions 1/1/6 |
| engineering-020 | ✅ | 810 | 4.5 | concepts 0/1/3, api_designs 1/1/5, tradeoffs 0/0/1, decisions 1/1/3, todos 1/1/2, open_questions 0/0/3 |
| engineering-021 | ✅ | 805 | 3.0 | concepts 1/1/2, api_designs 0/0/1, tradeoffs 1/1/2, decisions 1/1/4, open_questions 0/0/6 |
| engineering-022 | ✅ | 745 | 6.6 | concepts 0/0/1, tradeoffs 0/0/1, todos 0/0/1 |
| engineering-023 | ✅ | 801 | 3.8 | concepts 1/1/2, api_designs 0/0/3, tradeoffs 1/1/2, decisions 1/1/3, todos 1/1/2, open_questions 0/0/3 |
| engineering-024 | ✅ | 827 | 3.6 | concepts 1/1/2, api_designs 0/0/2, decisions 1/1/3, todos 2/2/3, open_questions 0/0/4 |
| engineering-025 | ✅ | 806 | 4.1 | concepts 0/0/3, api_designs 0/1/3, tradeoffs 1/2/3, decisions 1/1/4, todos 0/1/2, open_questions 0/0/3 |
| engineering-026 | ✅ | 794 | 3.5 | concepts 2/2/3, api_designs 0/0/3, tradeoffs 1/1/3, decisions 1/1/2, todos 1/1/2, open_questions 0/0/6 |
| engineering-027 | ✅ | 826 | 3.1 | api_designs 0/0/2, tradeoffs 1/1/2, decisions 1/1/2, todos 0/1/2 |
| engineering-028 | ✅ | 784 | 2.5 | concepts 0/0/2, api_designs 0/0/2, tradeoffs 0/2/2, decisions 1/1/2, todos 0/1/1, open_questions 0/0/2 |
| engineering-029 | ✅ | 813 | 3.4 | concepts 0/1/2, api_designs 0/1/3, tradeoffs 0/1/2, decisions 1/1/3, todos 1/1/2, open_questions 0/0/3 |
| engineering-030 | ✅ | 817 | 4.8 | concepts 1/1/3, api_designs 0/1/2, tradeoffs 0/0/2, decisions 1/1/5, todos 1/1/2, open_questions 0/0/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=engineering MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
