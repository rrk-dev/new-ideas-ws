# Extraction eval — `engineering` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/engineering/`)
- Wall time: 348 s incl. model load + Dart compile · peak RSS: 1728 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 5.8% |
| Prefill tok/s (median) | 256 |
| Decode tok/s (median) | 53.1 |
| Latency per case (median / max) | 10.6 s / 18.7 s |
| Prompt tokens (median / max) | 810 / 904 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| concepts | 31.3% | 72.2% | 43.7% | 36 | 83 | – |
| api_designs | 4.2% | 33.3% | 7.4% | 9 | 72 | – |
| tradeoffs | 40.6% | 81.2% | 54.2% | 32 | 64 | – |
| decisions | 19.8% | 69.2% | 30.8% | 26 | 91 | – |
| todos | 40.0% | 81.2% | 53.6% | 32 | 65 | owner 73.1% |
| open_questions | 7.6% | 77.8% | 13.9% | 9 | 92 | – |

Prose fields (token-set similarity to the reference, informational): title 75.5%, context 69.4%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.todos.recall | ≥ 80.0% | 81.2% | ✅ |
| lists.tradeoffs.recall | ≥ 70.0% | 81.2% | ✅ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| engineering-001 | ✅ | 814 | 12.2 | concepts 0/1/2, api_designs 0/0/2, decisions 0/1/2, open_questions 0/1/1 |
| engineering-002 | ✅ | 814 | 11.6 | concepts 0/0/3, api_designs 0/1/3, tradeoffs 0/0/3, decisions 1/1/3, todos 0/1/2, open_questions 0/0/3 |
| engineering-003 | ✅ | 853 | 9.5 | concepts 2/2/3, api_designs 0/0/2, tradeoffs 2/2/3, decisions 1/1/2, todos 1/1/2, open_questions 0/0/4 |
| engineering-004 | ✅ | 787 | 14.4 | concepts 0/0/2, api_designs 0/0/2, decisions 0/0/4, todos 0/0/2, open_questions 1/1/2 |
| engineering-005 | ✅ | 775 | 16.0 | concepts 1/1/4, api_designs 0/0/3, tradeoffs 0/0/1, decisions 0/0/3, todos 1/1/3, open_questions 0/0/2 |
| engineering-006 | ✅ | 852 | 10.8 | concepts 1/2/2, api_designs 0/0/4, decisions 1/1/2, todos 1/1/2, open_questions 1/1/2 |
| engineering-007 | ✅ | 795 | 9.8 | concepts 0/1/2, api_designs 0/1/2, decisions 0/1/2, todos 0/1/2, open_questions 0/0/1 |
| engineering-008 | ✅ | 780 | 13.8 | concepts 0/0/8, api_designs 0/0/1, tradeoffs 0/0/1, decisions 0/0/4, open_questions 0/0/1 |
| engineering-009 | ✅ | 839 | 10.8 | concepts 1/2/3, api_designs 0/0/2, tradeoffs 1/1/2, decisions 1/1/4, todos 1/1/3, open_questions 1/1/3 |
| engineering-010 | ✅ | 798 | 8.9 | concepts 1/1/2, api_designs 0/0/2, tradeoffs 0/0/2, decisions 0/1/4, todos 1/1/2, open_questions 0/0/6 |
| engineering-011 | ✅ | 812 | 10.0 | concepts 1/1/2, api_designs 0/1/2, decisions 0/1/2, todos 1/1/2, open_questions 0/0/2 |
| engineering-012 | ✅ | 810 | 9.5 | concepts 2/3/3, api_designs 0/0/3, tradeoffs 0/0/3, decisions 0/0/3, todos 0/0/3, open_questions 0/1/3 |
| engineering-013 | ✅ | 826 | 10.4 | concepts 2/2/5, api_designs 0/0/2, tradeoffs 1/1/2, decisions 1/1/6, todos 1/1/2, open_questions 0/0/5 |
| engineering-014 | ✅ | 819 | 15.0 | concepts 2/2/3, api_designs 1/1/3, decisions 1/1/5, todos 1/1/2, open_questions 0/0/6 |
| engineering-015 | ✅ | 782 | 12.1 | concepts 1/1/3, api_designs 0/0/1, tradeoffs 0/0/1, decisions 0/1/2, todos 0/2/2, open_questions 1/1/3 |
| engineering-016 | ✅ | 803 | 18.7 | concepts 1/1/3, api_designs 0/0/2, tradeoffs 2/2/4, decisions 1/1/3, todos 1/1/3, open_questions 0/0/3 |
| engineering-017 | ✅ | 904 | 13.3 | concepts 2/3/4, api_designs 0/1/3, tradeoffs 1/1/3, decisions 2/2/8, todos 2/2/3, open_questions 1/1/3 |
| engineering-018 | ✅ | 796 | 14.2 | concepts 0/1/2, api_designs 0/0/4, tradeoffs 0/0/4, decisions 0/1/1, todos 1/1/2, open_questions 0/0/5 |
| engineering-019 | ✅ | 844 | 9.4 | concepts 1/2/2, api_designs 0/0/3, tradeoffs 1/2/2, decisions 0/1/1, todos 1/1/3, open_questions 1/1/6 |
| engineering-020 | ✅ | 810 | 10.5 | concepts 0/1/2, api_designs 1/1/5, tradeoffs 0/0/2, decisions 1/1/2, todos 1/1/2, open_questions 0/0/2 |
| engineering-021 | ✅ | 805 | 8.4 | concepts 1/1/2, api_designs 0/0/2, tradeoffs 1/1/2, decisions 1/1/4, todos 1/1/2, open_questions 0/0/3 |
| engineering-022 | ✅ | 745 | 7.8 | concepts 0/0/2, tradeoffs 0/0/2, decisions 0/0/1, open_questions 0/0/1 |
| engineering-023 | ✅ | 801 | 8.5 | concepts 1/1/2, api_designs 0/0/2, tradeoffs 1/1/2, decisions 1/1/3, todos 1/1/2, open_questions 0/0/3 |
| engineering-024 | ✅ | 827 | 10.3 | concepts 1/1/2, api_designs 0/0/2, decisions 1/1/3, todos 2/2/3, open_questions 0/0/3 |
| engineering-025 | ✅ | 806 | 16.1 | concepts 0/0/3, api_designs 0/1/3, tradeoffs 0/2/1, decisions 0/1/2, todos 1/1/2, open_questions 0/0/1 |
| engineering-026 | ✅ | 794 | 9.4 | concepts 2/2/3, api_designs 0/0/2, tradeoffs 1/1/2, decisions 1/1/2, todos 1/1/2, open_questions 0/0/6 |
| engineering-027 | ✅ | 826 | 11.2 | api_designs 0/0/3, tradeoffs 1/1/2, decisions 1/1/3, todos 1/1/2, open_questions 1/1/2 |
| engineering-028 | ✅ | 784 | 9.1 | concepts 0/0/2, api_designs 0/0/2, tradeoffs 0/2/2, decisions 1/1/2, todos 0/1/2, open_questions 0/0/1 |
| engineering-029 | ✅ | 813 | 9.6 | concepts 0/1/2, api_designs 0/1/3, tradeoffs 0/1/2, decisions 1/1/3, todos 1/1/2, open_questions 0/0/3 |
| engineering-030 | ✅ | 817 | 13.4 | concepts 1/1/3, api_designs 1/1/2, tradeoffs 0/0/2, decisions 1/1/5, todos 0/1/2, open_questions 0/0/6 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=engineering MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
