# Extraction eval — `interview` × `Llama-3.2-1B-Instruct-Q4_K_M.gguf`

- Date: 2026-10-17 · host: Darwin arm64 · backend: cpu
- Model sha256: `6f85a640a97cf2bf` · n_ctx 4096 · max_tokens 1024 · sampling: extraction preset (grammar, temp 0.2, repeat penalty 1.05, seed 42)
- Commit: `4974d12` · llama.cpp `d812350` · profile version 1 · scored: post-processed output
- Cases: 32 (simulated transcripts (no TTS/whisper run), `tools/bench/eval/interview/`)
- Wall time: 309 s incl. model load + Dart compile · peak RSS: 1844 MiB

## Summary

| Metric | Value |
|---|---|
| Schema-valid (first pass, grammar-constrained) | 100.0% |
| Repair used | n/a (harness scores the first pass) |
| Hallucination rate (ungrounded items) | 5.3% |
| Quote fidelity, post-processed / raw (43 / 46 quotes) | 100.0% / 93.5% |
| Prefill tok/s (median) | 328 |
| Decode tok/s (median) | 69.7 |
| Latency per case (median / max) | 8.7 s / 16.4 s |
| Prompt tokens (median / max) | 1177 / 1527 |

## List fields (micro-averaged, fuzzy one-to-one)

| Field | Precision | Recall | F1 | Expected | Predicted | Sub-fields |
|---|---|---|---|---|---|---|
| participants | 100.0% | 100.0% | 100.0% | 64 | 64 | – |
| topics | 18.3% | 19.8% | 19.0% | 106 | 115 | – |
| qa_highlights | 83.1% | 50.9% | 63.2% | 106 | 65 | answer 88.9% |
| quotes | 20.9% | 12.9% | 15.9% | 70 | 43 | speaker 88.9% |
| follow_ups | 61.2% | 69.8% | 65.2% | 43 | 49 | owner 80.0%, due 26.7% |
| open_questions | 2.6% | 40.0% | 4.8% | 5 | 78 | – |

Prose fields (token-set similarity to the reference, informational): title 48.6%, summary 42.2%

## Targets

| Target | Required | Actual | |
|---|---|---|---|
| quote_fidelity | ≥ 100.0% | 100.0% | ✅ |
| lists.qa_highlights.recall | ≥ 50.0% | 50.9% | ✅ |
| lists.qa_highlights.precision | ≥ 40.0% | 83.1% | ✅ |
| lists.follow_ups.recall | ≥ 60.0% | 69.8% | ✅ |
| lists.follow_ups.precision | ≥ 60.0% | 61.2% | ✅ |
| lists.follow_ups.owner_accuracy | ≥ 50.0% | 80.0% | ✅ |
| lists.topics.recall | ≥ 50.0% | 19.8% | ❌ |
| schema_valid | ≥ 90.0% | 100.0% | ✅ |

## Per case

| Case | Valid | Prompt tok | Latency s | Notes |
|---|---|---|---|---|
| interview-001 | ✅ | 1178 | 12.1 | topics 0/3/3, qa_highlights 2/3/2, quotes 1/2/1, open_questions 0/0/1 |
| interview-002 | ✅ | 1177 | 8.9 | topics 1/4/3, qa_highlights 2/4/2, quotes 1/2/1, follow_ups 0/1/1, open_questions 0/0/4 |
| interview-003 | ✅ | 1284 | 10.7 | topics 0/4/3, qa_highlights 3/4/3, quotes 0/2/2, follow_ups 1/2/2, open_questions 0/0/2 |
| interview-004 | ✅ | 1434 | 10.9 | topics 1/6/3, qa_highlights 2/6/2, quotes 0/4/1, follow_ups 1/1/2, open_questions 0/0/6 |
| interview-005 | ✅ | 1232 | 8.4 | topics 0/4/3, qa_highlights 2/4/2, quotes 1/3/1, open_questions 0/0/3 |
| interview-006 | ✅ | 1162 | 7.4 | topics 0/0/4, qa_highlights 0/0/2, quotes 0/0/2, follow_ups 1/2/1, open_questions 0/0/1 |
| interview-007 | ✅ | 1146 | 8.3 | topics 0/4/2, qa_highlights 2/4/2, quotes 1/2/1, follow_ups 0/0/2, open_questions 0/0/4 |
| interview-008 | ✅ | 1177 | 7.7 | topics 0/3/3, qa_highlights 2/3/2, quotes 0/1/1, follow_ups 1/2/1, open_questions 0/0/2 |
| interview-009 | ✅ | 1153 | 11.9 | topics 1/2/3, quotes 1/2/1, follow_ups 1/2/2, open_questions 0/0/1 |
| interview-010 | ✅ | 1527 | 16.4 | topics 0/6/3, qa_highlights 2/6/2, quotes 0/5/2, open_questions 0/0/7 |
| interview-011 | ✅ | 1210 | 10.7 | topics 0/4/4, qa_highlights 2/4/2, quotes 0/4/1 |
| interview-012 | ✅ | 1140 | 7.5 | topics 1/2/3, qa_highlights 0/2/2, quotes 0/2/1, follow_ups 1/2/1, open_questions 0/0/1 |
| interview-013 | ✅ | 1170 | 7.5 | topics 1/4/3, qa_highlights 2/4/2, quotes 0/3/2, follow_ups 0/1/1, open_questions 0/0/1 |
| interview-014 | ✅ | 1172 | 7.9 | topics 1/4/4, qa_highlights 2/4/2, quotes 0/1/1, follow_ups 0/0/1, open_questions 1/1/3 |
| interview-015 | ✅ | 1262 | 8.7 | topics 1/4/2, qa_highlights 2/4/2, quotes 0/4/0, open_questions 0/0/3 |
| interview-016 | ✅ | 1071 | 7.1 | topics 0/0/3, qa_highlights 0/0/3, quotes 0/0/2, follow_ups 0/0/1, open_questions 0/0/3 |
| interview-017 | ✅ | 1458 | 11.2 | topics 0/6/3, qa_highlights 2/6/2, quotes 1/5/2, follow_ups 0/2/2, open_questions 0/0/6 |
| interview-018 | ✅ | 1175 | 7.7 | topics 2/4/5, qa_highlights 2/4/2, quotes 1/3/1, follow_ups 0/1/1, open_questions 0/0/1 |
| interview-019 | ✅ | 1127 | 9.1 | topics 1/2/6, qa_highlights 1/2/2, quotes 1/2/2, follow_ups 1/1/2, open_questions 0/0/3 |
| interview-020 | ✅ | 1182 | 7.3 | topics 1/2/2, qa_highlights 1/2/2, quotes 0/2/2, open_questions 0/1/1 |
| interview-021 | ✅ | 1111 | 7.2 | topics 2/3/3, qa_highlights 1/3/1, quotes 0/1/1, follow_ups 0/0/1, open_questions 0/0/2 |
| interview-022 | ✅ | 1184 | 13.2 | topics 2/4/4, qa_highlights 2/4/2, quotes 0/2/0, follow_ups 0/1/2, open_questions 0/0/2 |
| interview-023 | ✅ | 1220 | 13.2 | topics 1/4/3, qa_highlights 2/4/2, quotes 1/3/1, open_questions 0/0/3 |
| interview-024 | ✅ | 1114 | 11.7 | topics 0/0/4, qa_highlights 0/0/2, quotes 0/0/3, open_questions 0/0/3 |
| interview-025 | ✅ | 1489 | 13.3 | topics 1/6/3, qa_highlights 2/6/2, quotes 0/5/2, open_questions 0/0/2 |
| interview-026 | ✅ | 1183 | 9.2 | topics 2/3/6, qa_highlights 2/3/2, quotes 0/0/1, follow_ups 1/2/2, open_questions 0/0/3 |
| interview-027 | ✅ | 1138 | 8.3 | topics 0/2/4, quotes 0/1/1, follow_ups 1/1/2, open_questions 0/1/3 |
| interview-028 | ✅ | 1120 | 6.9 | topics 1/2/3, quotes 0/1/1, follow_ups 1/2/1, open_questions 0/0/1 |
| interview-029 | ✅ | 1507 | 10.4 | topics 0/6/10, qa_highlights 2/6/2, quotes 0/4/2, open_questions 0/1/1 |
| interview-030 | ✅ | 1204 | 8.6 | topics 1/4/4, qa_highlights 2/4/2, quotes 0/2/1, follow_ups 1/1/2, open_questions 0/0/1 |
| interview-031 | ✅ | 1139 | 8.3 | topics 0/2/3, quotes 0/1/2, open_questions 0/0/1 |
| interview-032 | ✅ | 1083 | 7.7 | topics 0/2/3, quotes 0/1/1, open_questions 0/0/2 |

List notes are `tp/expected/predicted`. Regenerate: `make eval PROFILE=interview MODEL=Llama-3.2-1B-Instruct-Q4_K_M.gguf`.
