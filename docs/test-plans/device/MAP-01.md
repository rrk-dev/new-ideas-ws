# Device / lab verification — MAP-01

Rows need physical devices of each tier that were unavailable when this was authored. The host measurement (Apple Silicon CPU, Llama-3.2-1B Q4_K_M) is in `tools/bench/results/` (`*-eval-mindmap-*.md`) and is informational only. Budgets are in `tasks/14-product-phase2/MAP-01-mind-map-generation.md` ("Eval targets and cost budgets"); protocol in `docs/perf.md` (QA-03).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [MAP-01/AC5] | Process a 30-minute English recording with mind maps on Auto (setting `processing.mind_map` = `auto`). Read the mind-map step duration from the job log. | High ≤ 30 s, Mid ≤ 60 s, Low ≤ 120 s. | High-tier + Mid-tier + Low-tier (Android and iPhone) | — | ⏳ | | |
| [MAP-01/AC5] | Same run: compare peak RSS during the mind-map step with the extract step (QA-03). | No increase (same loaded model). | Mid-tier Android + iPhone | — | ⏳ | | |
| [MAP-01/AC5] | Same 30-minute recording, battery delta of the mind-map step by QA-03 protocol. | High ≤ 1 %, Mid ≤ 1.5 %, Low ≤ 2 %. | High/Mid/Low tier | — | ⏳ | | |
| [MAP-01/AC4] | Force-quit the app during the Mapping state, relaunch. | The job resumes; exactly one map exists afterwards. | Any iPhone + Android | — | ⏳ | | |
