# Extraction eval — `lecture` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `b30e084` · llama.cpp `d812350` · profile version 1 · scored: post-processed output
- Cases: 30 (simulated transcripts (no TTS/whisper run), `tools/bench/eval/lecture/`)
- Wall time: 292 s incl. model load + Dart compile · peak RSS: 1857 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 1.2% |
| Prefill tok/s (median) | 256 |
| Decode tok/s (median) | 51.8 |
| Latency per case (median / max) | 8.3 s / 28.1 s |
| Prompt tokens (median / max) | 916 / 2225 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| key_concepts | 96.7% | 95.1% | 95.9% | 61 | 60 | – |
| outline | 57.7% | 53.6% | 55.6% | 84 | 78 | – |
| assignments | 47.1% | 88.9% | 61.5% | 27 | 51 | due 83.3% |
| questions | 96.0% | 80.0% | 87.3% | 30 | 25 | – |
| references | 56.2% | 90.0% | 69.2% | 20 | 32 | – |

Prose fields (token-set similarity to the reference, informational): title 95.3%, summary 94.0%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| lists.key_concepts.recall | ≥ 50.0% | 95.1% | ✅ |
| lists.assignments.recall | ≥ 60.0% | 88.9% | ✅ |
| lists.assignments.precision | ≥ 60.0% | 47.1% | ❌ |
| schema_valid | ≥ 90.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| lecture-001 | ✅ | 909 | 9.4 | assignments 1/1/2 |
| lecture-002 | ✅ | 889 | 9.1 | outline 2/2/3, assignments 0/0/2, references 0/0/2 |
| lecture-003 | ✅ | 924 | 8.4 | outline 1/2/2, questions 0/1/0 |
| lecture-004 | ✅ | 949 | 7.5 | outline 1/2/1, questions 0/1/0 |
| lecture-005 | ✅ | 905 | 11.2 | outline 2/2/3, assignments 0/0/1, references 0/0/1 |
| lecture-006 | ✅ | 2225 | 28.1 | key_concepts 3/3/4, outline 3/8/5 |
| lecture-007 | ✅ | 890 | 8.1 | key_concepts 1/2/2, outline 1/2/1, assignments 1/1/2, references 0/0/1 |
| lecture-008 | ✅ | 918 | 8.4 | outline 1/2/2, assignments 0/0/2, questions 0/1/0 |
| lecture-009 | ✅ | 908 | 8.6 | assignments 0/1/2 |
| lecture-010 | ✅ | 930 | 8.4 | assignments 1/2/1 |
| lecture-011 | ✅ | 892 | 7.6 | assignments 0/0/1, references 0/0/1 |
| lecture-012 | ✅ | 928 | 9.2 | outline 1/2/2, assignments 1/1/2 |
| lecture-013 | ✅ | 879 | 10.1 | outline 1/2/1, assignments 1/1/3, references 0/0/2 |
| lecture-014 | ✅ | 960 | 7.0 | outline 1/2/4, assignments 1/1/2, references 0/0/1 |
| lecture-015 | ✅ | 2193 | 15.9 | outline 2/8/4 |
| lecture-016 | ✅ | 909 | 6.1 | assignments 0/0/2 |
| lecture-017 | ✅ | 937 | 5.6 | assignments 1/1/2 |
| lecture-018 | ✅ | 909 | 4.8 | outline 1/2/1, assignments 1/2/1, questions 0/1/0 |
| lecture-019 | ✅ | 913 | 6.5 | outline 1/2/4, questions 0/1/0 |
| lecture-020 | ✅ | 890 | 7.9 | key_concepts 0/2/0, outline 0/2/1, assignments 0/0/1, references 0/0/1 |
| lecture-021 | ✅ | 2200 | 20.1 | outline 1/8/2, assignments 1/1/2, references 0/1/0 |
| lecture-022 | ✅ | 927 | 11.2 | outline 2/2/3, assignments 1/1/3, questions 1/1/2, references 1/1/3 |
| lecture-023 | ✅ | 904 | 8.2 | assignments 1/1/3 |
| lecture-024 | ✅ | 916 | 11.0 | outline 2/2/7, references 0/0/1 |
| lecture-025 | ✅ | 926 | 8.1 | outline 2/2/3, questions 0/1/0 |
| lecture-026 | ✅ | 888 | 5.9 | outline 1/2/5, assignments 1/1/2 |
| lecture-027 | ✅ | 901 | 6.0 | outline 1/2/3, assignments 1/1/2 |
| lecture-028 | ✅ | 916 | 7.8 | outline 2/2/3, assignments 1/1/2, references 0/1/1 |
| lecture-029 | ✅ | 2175 | 15.2 | outline 0/8/2, assignments 1/1/2 |
| lecture-030 | ✅ | 933 | 6.3 | references 0/0/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=lecture MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
