# ASK-03 end-to-end Ask eval (3B, host)

Model `Llama-3.2-3B-Instruct-Q4_K_M.gguf`, n_ctx 6144, greedy, grammar-constrained, host (Apple Silicon, `libvv_native` host build). 86 questions (60 answerable, 26 unanswerable) over the 33-recording synthetic library of ASK-02. Targets pre-registered in `tasks/14-product-phase2/ASK-03-ask-engine.md` (ASK-03) and `tasks/14-product-phase2/ASK-05-ask-answer-quality.md` (ASK-05) before the first run.

Segment recall@10 here is measured on the passages given to the model: the 10 FTS5 candidates, the top three expanded by their ±1 neighbour segments, trimmed to the prompt budget; a gold item counts when one of its accepted timestamps is among them.

## Arm `base`

| Metric | Measured | Target | Kind | Verdict |
|---|---|---|---|---|
| answer_correctness | 68.3% | ≥ 70.0% | target | MISSED |
| citation_precision | 84.7% | ≥ 90.0% | gate | MISSED |
| unanswerable_refused | 73.1% | ≥ 90.0% | gate | MISSED |
| hallucination_rate | 21.7% | ≤ 15.0% | target | MISSED |
| seg_recall@10 | 85.0% | ≥ 80.0% | gate | MET |

Outcomes: {'answered': 61, 'notFound': 25}. Citations returned 72, on a gold recording 61. Latency per question (retrieval + generation, model already loaded after the first): median 10.3 s, p95 16.7 s, max 23.2 s.

| Type | n | Answer correctness | Segment recall@10 |
|---|---|---|---|
| exact | 21 | 90.5% | 95.2% |
| paraphrase | 18 | 77.8% | 77.8% |
| multi | 12 | 33.3% | 91.7% |
| date | 9 | 44.4% | 66.7% |

Answerable questions not answered: M01, D03, D05, D07, D08, D09.
Unanswerable questions answered anyway: U02, U11, U12, U13, U14, U15, U16.

Re-run: `python3 tools/bench/ask/ask_eval.py run --model <3b.gguf> --out <prefix>`.
