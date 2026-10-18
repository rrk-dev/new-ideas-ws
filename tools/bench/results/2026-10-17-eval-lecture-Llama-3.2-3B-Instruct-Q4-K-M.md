# Extraction eval — `lecture` × `Llama-3.2-3B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6c1a2b4116103267` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 1 · scored: post-processed output
- Cases: 30 (simulated transcripts (no TTS/whisper run), `tools/bench/eval/lecture/`)
- Wall time: 920 s incl. model load + Dart compile · peak RSS: 2856 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 96.7% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 2.8% |
| Prefill tok/s (median) | 108 |
| Decode tok/s (median) | 22.6 |
| Latency per case (median / max) | 23.8 s / 74.0 s |
| Prompt tokens (median / max) | 916 / 2225 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| key_concepts | 54.0% | 88.5% | 67.1% | 61 | 100 | – |
| outline | 71.9% | 82.1% | 76.7% | 84 | 96 | – |
| assignments | 80.0% | 88.9% | 84.2% | 27 | 30 | due 100.0% |
| questions | 100.0% | 73.3% | 84.6% | 30 | 22 | – |
| references | 25.0% | 5.0% | 8.3% | 20 | 4 | – |

Prose fields (token-set similarity to the reference, informational): title 89.6%, summary 67.3%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.key_concepts.recall | ≥ 50.0% | 88.5% | ✅ |
| lists.assignments.recall | ≥ 60.0% | 88.9% | ✅ |
| lists.assignments.precision | ≥ 60.0% | 80.0% | ✅ |
| schema_valid | ≥ 90.0% | 96.7% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| lecture-001 | ✅ | 909 | 23.8 | key_concepts 2/2/3, outline 2/2/3, references 0/1/0 |
| lecture-002 | ✅ | 889 | 21.1 | outline 2/2/3, assignments 0/0/1 |
| lecture-003 | ✅ | 924 | 41.0 | key_concepts 2/2/10, references 0/1/0 |
| lecture-004 | ✅ | 949 | 29.6 | key_concepts 2/2/7, references 0/2/0 |
| lecture-005 | ❌ | 905 | 45.0 | key_concepts 0/2/0, outline 0/2/0, questions 0/1/0 |
| lecture-006 | ✅ | 2225 | 72.5 | key_concepts 3/3/8, outline 8/8/9, questions 0/1/0, references 0/1/0 |
| lecture-007 | ✅ | 890 | 20.5 | all lists exact |
| lecture-008 | ✅ | 918 | 14.5 | key_concepts 1/2/1, outline 1/2/1, assignments 0/0/1, references 0/1/0 |
| lecture-009 | ✅ | 908 | 16.7 | key_concepts 1/2/1, outline 1/2/1, references 0/1/0 |
| lecture-010 | ✅ | 930 | 27.7 | key_concepts 2/2/5, outline 2/2/3, assignments 1/2/1, references 0/1/0 |
| lecture-011 | ✅ | 892 | 19.6 | assignments 0/0/1 |
| lecture-012 | ✅ | 928 | 29.7 | key_concepts 1/2/1, outline 2/2/3, references 0/1/0 |
| lecture-013 | ✅ | 879 | 15.7 | key_concepts 2/2/3, outline 1/2/4 |
| lecture-014 | ✅ | 960 | 16.3 | all lists exact |
| lecture-015 | ✅ | 2193 | 40.5 | key_concepts 2/2/3, outline 5/8/9, questions 0/1/0, references 0/1/0 |
| lecture-016 | ✅ | 909 | 24.2 | outline 1/2/4, assignments 0/0/1, references 1/1/4 |
| lecture-017 | ✅ | 937 | 20.1 | key_concepts 2/2/5, references 0/1/0 |
| lecture-018 | ✅ | 909 | 15.0 | outline 2/2/3, assignments 1/2/1, questions 0/1/0 |
| lecture-019 | ✅ | 913 | 18.1 | key_concepts 2/2/3, outline 2/2/3, references 0/1/0 |
| lecture-020 | ✅ | 890 | 13.8 | outline 2/2/3, assignments 0/0/1 |
| lecture-021 | ✅ | 2200 | 45.2 | key_concepts 2/2/4, outline 7/8/9, questions 0/1/0, references 0/1/0 |
| lecture-022 | ✅ | 927 | 23.8 | outline 1/2/3, references 0/1/0 |
| lecture-023 | ✅ | 904 | 20.8 | references 0/1/0 |
| lecture-024 | ✅ | 916 | 16.6 | key_concepts 1/2/1, assignments 0/0/1 |
| lecture-025 | ✅ | 926 | 42.0 | outline 2/2/3, assignments 1/2/1, references 0/1/0 |
| lecture-026 | ✅ | 888 | 22.7 | key_concepts 1/2/1, outline 1/2/3, questions 0/1/0 |
| lecture-027 | ✅ | 901 | 74.0 | key_concepts 2/2/4, outline 0/2/1, references 0/1/0 |
| lecture-028 | ✅ | 916 | 30.3 | key_concepts 2/2/3, outline 2/2/3, questions 0/1/0, references 0/1/0 |
| lecture-029 | ✅ | 2175 | 66.2 | key_concepts 2/2/6, questions 0/1/0, references 0/1/0 |
| lecture-030 | ✅ | 933 | 48.8 | key_concepts 2/2/11, outline 1/2/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=lecture MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf`.
