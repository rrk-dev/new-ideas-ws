# Device / lab verification — TPL-04

Rows need a physical mid-tier device that was unavailable when this was authored. The host measurement (Apple Silicon CPU, Llama-3.2-1B Q4_K_M) is in `tools/bench/results/2026-10-17-eval-classify-Llama-3-2-1B-Instruct-Q4-K-M.md` and is informational only.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [TPL-04/AC2] | Record or import a 10-minute English recording on Auto with the six built-in profiles installed. Time the classify step (keyword stage + LLM, ≈1500-token sample) from the job log. Repeat for a transcript that the keyword stage does not decide. | < 10 s added to the job. | Mid-tier Android + iPhone | — | ⏳ | | |
