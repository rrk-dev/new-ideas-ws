# Extraction eval — `engineering` × `Llama-3.2-3B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6c1a2b4116103267` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 2 · scored: post-processed output
- Cases: 30 (synthetic TTS → whisper transcripts, `tools/bench/eval/engineering/`)
- Wall time: 383 s incl. model load + Dart compile · peak RSS: 3700 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 0.6% |
| Prefill tok/s (median) | 109 |
| Decode tok/s (median) | 23.2 |
| Latency per case (median / max) | 12.0 s / 19.5 s |
| Prompt tokens (median / max) | 810 / 904 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| concepts | 38.0% | 83.3% | 52.2% | 36 | 79 | – |
| api_designs | 13.0% | 33.3% | 18.8% | 9 | 23 | – |
| tradeoffs | 75.0% | 9.4% | 16.7% | 32 | 4 | – |
| decisions | 60.0% | 69.2% | 64.3% | 26 | 30 | – |
| todos | 79.3% | 71.9% | 75.4% | 32 | 29 | owner 87.0% |
| open_questions | 80.0% | 44.4% | 57.1% | 9 | 5 | – |

Prose fields (token-set similarity to the reference, informational): title 89.8%, context 69.7%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.todos.recall | ≥ 80.0% | 71.9% | ❌ |
| lists.tradeoffs.recall | ≥ 70.0% | 9.4% | ❌ |
| schema_valid | ≥ 99.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| engineering-001 | ✅ | 814 | 13.1 | concepts 1/1/2, tradeoffs 0/2/0, open_questions 0/1/1 |
| engineering-002 | ✅ | 814 | 15.9 | concepts 0/0/3, api_designs 0/1/3, decisions 0/1/1 |
| engineering-003 | ✅ | 853 | 12.1 | concepts 1/2/3, tradeoffs 0/2/0 |
| engineering-004 | ✅ | 787 | 10.9 | concepts 0/0/4, tradeoffs 0/2/0, decisions 0/0/1, open_questions 0/1/0 |
| engineering-005 | ✅ | 775 | 12.1 | concepts 1/1/2 |
| engineering-006 | ✅ | 852 | 18.6 | concepts 1/2/2 |
| engineering-007 | ✅ | 795 | 19.5 | concepts 1/1/3, api_designs 0/1/2, tradeoffs 0/2/0, todos 1/1/2 |
| engineering-008 | ✅ | 780 | 13.6 | concepts 0/0/3, decisions 0/0/1, todos 1/3/1 |
| engineering-009 | ✅ | 839 | 17.1 | api_designs 0/0/2, tradeoffs 0/1/0, todos 1/1/2 |
| engineering-010 | ✅ | 798 | 13.4 | concepts 0/1/3, api_designs 0/0/1, decisions 0/1/1, todos 0/1/1 |
| engineering-011 | ✅ | 812 | 14.0 | concepts 1/1/2, api_designs 0/1/2, tradeoffs 0/2/0, todos 0/1/0 |
| engineering-012 | ✅ | 810 | 10.9 | decisions 0/0/1, open_questions 0/1/0 |
| engineering-013 | ✅ | 826 | 12.4 | tradeoffs 0/1/0 |
| engineering-014 | ✅ | 819 | 14.0 | concepts 2/2/3, api_designs 0/1/1, tradeoffs 0/2/0 |
| engineering-015 | ✅ | 782 | 11.8 | concepts 1/1/3, decisions 0/1/1, todos 1/2/1, open_questions 0/1/0 |
| engineering-016 | ✅ | 803 | 15.4 | concepts 1/1/3, api_designs 0/0/2, tradeoffs 0/2/0, decisions 1/1/2 |
| engineering-017 | ✅ | 904 | 17.5 | concepts 3/3/4, api_designs 1/1/2, tradeoffs 0/1/0, decisions 1/2/1 |
| engineering-018 | ✅ | 796 | 11.8 | concepts 0/1/2 |
| engineering-019 | ✅ | 844 | 13.8 | concepts 2/2/3, tradeoffs 0/2/0, decisions 1/1/2, todos 1/1/2 |
| engineering-020 | ✅ | 810 | 10.9 | concepts 0/1/3, api_designs 1/1/2, decisions 0/1/1 |
| engineering-021 | ✅ | 805 | 11.6 | concepts 1/1/2, tradeoffs 1/1/2 |
| engineering-022 | ✅ | 745 | 6.8 | concepts 0/0/1, decisions 0/0/1 |
| engineering-023 | ✅ | 801 | 10.1 | concepts 1/1/3, api_designs 0/0/1, tradeoffs 0/1/0 |
| engineering-024 | ✅ | 827 | 9.5 | concepts 1/1/3, tradeoffs 0/2/0, todos 1/2/1 |
| engineering-025 | ✅ | 806 | 10.2 | concepts 0/0/2, api_designs 0/1/2, tradeoffs 0/2/0, decisions 0/1/1, todos 0/1/1 |
| engineering-026 | ✅ | 794 | 8.4 | concepts 2/2/3, tradeoffs 0/1/0, decisions 0/1/0 |
| engineering-027 | ✅ | 826 | 10.2 | concepts 2/2/3, tradeoffs 0/1/0, todos 0/1/0, open_questions 0/1/0 |
| engineering-028 | ✅ | 784 | 11.7 | concepts 0/0/2, tradeoffs 0/2/0, decisions 0/1/1, todos 0/1/1 |
| engineering-029 | ✅ | 813 | 10.9 | concepts 0/1/2, api_designs 1/1/2, tradeoffs 0/1/0 |
| engineering-030 | ✅ | 817 | 10.4 | concepts 1/1/3, api_designs 0/1/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=engineering MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf`.
