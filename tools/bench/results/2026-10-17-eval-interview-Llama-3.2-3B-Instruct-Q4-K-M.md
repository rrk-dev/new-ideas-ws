# Extraction eval — `interview` × `Llama-3.2-3B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6c1a2b4116103267` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `74c96a4` · llama.cpp `d812350` · profile version 1 · scored: post-processed output
- Cases: 32 (simulated transcripts (no TTS/whisper run), `tools/bench/eval/interview/`)
- Wall time: 689 s incl. model load + Dart compile · peak RSS: 3636 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 7.2% |
| Quote fidelity, post-processed / raw (31 / 31 quotes) | 100.0% / 100.0% |
| Prefill tok/s (median) | 114 |
| Decode tok/s (median) | 26.2 |
| Latency per case (median / max) | 18.9 s / 46.4 s |
| Prompt tokens (median / max) | 1177 / 1527 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| participants | 100.0% | 100.0% | 100.0% | 64 | 64 | – |
| topics | 33.3% | 28.3% | 30.6% | 106 | 90 | – |
| qa_highlights | 84.8% | 26.4% | 40.3% | 106 | 33 | answer 96.4% |
| quotes | 58.1% | 25.7% | 35.6% | 70 | 31 | speaker 100.0% |
| follow_ups | 88.9% | 37.2% | 52.5% | 43 | 18 | owner 100.0%, due 93.8% |
| open_questions | 100.0% | 20.0% | 33.3% | 5 | 1 | – |

Prose fields (token-set similarity to the reference, informational): title 79.7%, summary 48.6%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| quote_fidelity | ≥ 100.0% | 100.0% | ✅ |
| lists.qa_highlights.recall | ≥ 50.0% | 26.4% | ❌ |
| lists.qa_highlights.precision | ≥ 40.0% | 84.8% | ✅ |
| lists.follow_ups.recall | ≥ 60.0% | 37.2% | ❌ |
| lists.follow_ups.precision | ≥ 60.0% | 88.9% | ✅ |
| lists.follow_ups.owner_accuracy | ≥ 50.0% | 100.0% | ✅ |
| lists.topics.recall | ≥ 50.0% | 28.3% | ❌ |
| schema_valid | ≥ 90.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| interview-001 | ✅ | 1178 | 18.8 | topics 0/3/1, qa_highlights 1/3/1, quotes 1/2/1, follow_ups 1/2/1 |
| interview-002 | ✅ | 1177 | 16.1 | topics 2/4/4, qa_highlights 1/4/1, quotes 1/2/1 |
| interview-003 | ✅ | 1284 | 18.5 | topics 0/4/2, qa_highlights 1/4/1, quotes 1/2/1, follow_ups 1/2/1 |
| interview-004 | ✅ | 1434 | 35.4 | topics 0/6/4, qa_highlights 1/6/1, quotes 0/4/1 |
| interview-005 | ✅ | 1232 | 19.8 | topics 2/4/3, qa_highlights 1/4/1, quotes 1/3/1, follow_ups 0/2/0 |
| interview-006 | ✅ | 1162 | 16.6 | topics 0/0/2, qa_highlights 0/0/1, quotes 0/0/1, follow_ups 0/2/1 |
| interview-007 | ✅ | 1146 | 17.2 | topics 1/4/3, qa_highlights 1/4/1, quotes 1/2/1 |
| interview-008 | ✅ | 1177 | 16.6 | topics 1/3/2, qa_highlights 1/3/1, follow_ups 0/2/0 |
| interview-009 | ✅ | 1153 | 15.9 | topics 1/2/2, qa_highlights 1/2/1, quotes 0/2/0, follow_ups 0/2/0 |
| interview-010 | ✅ | 1527 | 46.4 | topics 1/6/3, qa_highlights 1/6/1, quotes 1/5/1, follow_ups 1/2/1 |
| interview-011 | ✅ | 1210 | 19.1 | topics 2/4/6, qa_highlights 1/4/1, quotes 0/4/1, follow_ups 0/1/0 |
| interview-012 | ✅ | 1140 | 18.1 | topics 1/2/3, qa_highlights 1/2/1, quotes 1/2/1, follow_ups 1/2/1 |
| interview-013 | ✅ | 1170 | 15.7 | topics 0/4/2, qa_highlights 1/4/1, quotes 1/3/1, follow_ups 0/1/0 |
| interview-014 | ✅ | 1172 | 15.9 | topics 2/4/3, qa_highlights 1/4/1, quotes 0/1/1, open_questions 0/1/0 |
| interview-015 | ✅ | 1262 | 23.1 | topics 2/4/5, qa_highlights 1/4/1, quotes 1/4/1, follow_ups 1/2/1 |
| interview-016 | ✅ | 1071 | 20.0 | topics 0/0/2, qa_highlights 0/0/1, quotes 0/0/1 |
| interview-017 | ✅ | 1458 | 24.6 | topics 1/6/2, qa_highlights 1/6/1, quotes 1/5/1, follow_ups 1/2/1 |
| interview-018 | ✅ | 1175 | 15.3 | topics 1/4/3, qa_highlights 1/4/1, quotes 1/3/1, follow_ups 0/1/0 |
| interview-019 | ✅ | 1127 | 15.5 | topics 1/2/3, qa_highlights 1/2/1, quotes 1/2/1, follow_ups 0/1/0 |
| interview-020 | ✅ | 1182 | 16.6 | topics 0/2/1, qa_highlights 1/2/1, quotes 0/2/1, open_questions 0/1/0 |
| interview-021 | ✅ | 1111 | 16.4 | topics 2/3/3, qa_highlights 1/3/1, quotes 0/1/1 |
| interview-022 | ✅ | 1184 | 25.1 | topics 1/4/3, qa_highlights 1/4/1, quotes 1/2/1, follow_ups 0/1/0 |
| interview-023 | ✅ | 1220 | 26.6 | topics 2/4/4, qa_highlights 1/4/1, quotes 1/3/1, follow_ups 1/2/1 |
| interview-024 | ✅ | 1114 | 18.6 | topics 0/0/1, qa_highlights 0/0/2, quotes 0/0/1 |
| interview-025 | ✅ | 1489 | 27.8 | topics 1/6/3, qa_highlights 0/6/1, quotes 1/5/1, follow_ups 1/2/1 |
| interview-026 | ✅ | 1183 | 19.1 | topics 2/3/3, qa_highlights 1/3/1, quotes 0/0/1, follow_ups 0/2/1 |
| interview-027 | ✅ | 1138 | 23.8 | topics 0/2/2, qa_highlights 1/2/1, quotes 0/1/1, open_questions 0/1/0 |
| interview-028 | ✅ | 1120 | 28.9 | topics 1/2/3, qa_highlights 1/2/1, quotes 0/1/2, follow_ups 1/2/1 |
| interview-029 | ✅ | 1507 | 27.0 | topics 0/6/4, qa_highlights 1/6/1, quotes 1/4/1, follow_ups 1/2/1, open_questions 0/1/0 |
| interview-030 | ✅ | 1204 | 18.0 | topics 1/4/3, qa_highlights 1/4/1, quotes 0/2/0, follow_ups 0/1/0 |
| interview-031 | ✅ | 1139 | 20.5 | topics 1/2/2, qa_highlights 1/2/1, follow_ups 1/2/1 |
| interview-032 | ✅ | 1083 | 24.5 | topics 1/2/3, qa_highlights 1/2/1, quotes 0/1/1 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=interview MODEL=Llama-3.2-3B-Instruct-Q4_K_M.gguf`.
