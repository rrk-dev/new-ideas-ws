# Performance report

Status: **no device has been measured yet.** Every row is ⏳ until a tester runs the
[protocol](perf.md) on the device (see [device/QA-03.md](test-plans/device/QA-03.md)).
Regenerate the table with `perf_report.py report`. Budgets are in
`tools/bench/perf/budgets.json`.

## Device classes

| Device | Role | Tier | Time min/60 | Budget | Battery %/h | Budget | Peak thermal | Result |
|---|---|---|---|---|---|---|---|---|
| VV-IOS-16 (iPhone 16) | Newest iPhone | High | ⏳ | 15 | ⏳ | 10 | ⏳ | ⏳ |
| VV-AND-FLG (Galaxy S24/S25) | Flagship | High | ⏳ | 15 | ⏳ | 10 | ⏳ | ⏳ |
| VV-IOS-14 (iPhone 14) | 6 GB iPhone | Mid | ⏳ | 22 | ⏳ | 14 | ⏳ | ⏳ |
| VV-AND-PIX (Pixel 8/9) | Reference Android | Mid or High | ⏳ | 22 / 15 | ⏳ | 14 / 10 | ⏳ | ⏳ |
| VV-AND-7 (Snapdragon 7-series) | Budget Android target | Mid | ⏳ | 22 | ⏳ | 14 | ⏳ | ⏳ |
| VV-IOS-11 (iPhone 11) | Budget iPhone target | Low | ⏳ | 30 | ⏳ | 18 | ⏳ | ⏳ |
| VV-AND-4G (4 GB MediaTek) | Low-RAM Android | Low | ⏳ | 30 | ⏳ | 18 | ⏳ | ⏳ |

## Sustained 30 minute thermal run

| Device | Start state | Peak state | Threads | Pacing | Result |
|---|---|---|---|---|---|
| VV-IOS-11 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| VV-AND-7 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |

## Required details per row

Device and OS, build flags, app/whisper/llama commits, model files and sha256,
parameters, thermal start state, number of runs with median and min/max, wall time
with and without model load (the reporting rules in `vv-benchmark-eval`).

## Adjustments

None yet. When a budget is missed, list the tier default change (LLM-07) or the ADR
here.
