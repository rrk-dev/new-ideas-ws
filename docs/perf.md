# Performance, battery and thermal protocol (QA-03)

Budgets live in `tools/bench/perf/budgets.json`. The harness is
`tools/bench/perf/perf_report.py`. Results are published in
[perf-report.md](perf-report.md) and tracked per release in
`tools/bench/results/perf-history.md`.

## Budgets

| Tier | Time to process 60 min of audio | Battery per hour of audio |
|---|---|---|
| High | ≤ 15 min | ≤ 10% |
| Mid | ≤ 22 min (placeholder) | ≤ 14% (placeholder) |
| Low | ≤ 30 min | ≤ 18% (placeholder) |

Time covers transcribe through write. The app must never reach iOS `critical` or
Android `severe` thermal status during a 30 minute sustained run at room temperature.
A tier that misses a budget gets lower defaults (LLM-07) or the budget is revised
through an ADR. A regression above 10% against the previous release blocks the
release.

## Devices

Roles and tiers come from [device-matrix.md](device-matrix.md): VV-IOS-11 (iPhone 11)
and VV-AND-7 (Snapdragon 7-series) are the budget targets; VV-IOS-16 and VV-AND-FLG
cover High; VV-AND-4G covers Low.

## Run protocol

1. Charge to 100%, unplug, enable airplane mode, fix screen brightness, let the phone
   cool to nominal thermal state (record it).
2. Use the same 60 minute meeting clip from `tools/bench/corpus` (synthetic or
   consented, never real user audio) and the tier's default models.
3. Import the clip and process it end to end. Run at least 3 times; report the median.
4. Keep the app foreground for the first run and screen-off for a second run with
   background processing (see [background-processing.md](background-processing.md)).
5. For the sustained test, loop extractions for at least 30 minutes and log battery and
   thermal every 30 s (the in-app job metrics already record both).
6. Export the diagnostics zip (metrics only) and wrap the JobMetrics lines into a run
   file (header documented in `perf_report.py`).

### iOS

- Xcode Instruments on a device: Time Profiler, Metal System Trace and Energy Log.
- `MetricKit` payloads in dev builds when available.
- Note the thermal state transitions from the metrics file.

### Android

```bash
bash tools/bench/perf/android_capture.sh out/VV-AND-7 start
# unplug, run the job, plug in
bash tools/bench/perf/android_capture.sh out/VV-AND-7 stop
```

Open `bugreport.zip` in Battery Historian, and capture a Perfetto trace for CPU
frequency and thermal. `thermal-*.txt` has the `dumpsys thermalservice` output.

## Commands

```bash
python3 tools/bench/perf/perf_report.py check runs/*.json            # budgets, exit 1 if missed
python3 tools/bench/perf/perf_report.py report runs/*.json --out report.md
python3 tools/bench/perf/perf_report.py compare --history tools/bench/results/perf-history.json runs/*.json
python3 tools/bench/perf/perf_report.py record  --history tools/bench/results/perf-history.json runs/*.json
```

The files in `tools/bench/perf/fixtures/` are synthetic and exist only to test the
harness. Do not quote them as measurements.

## Thread counts and pacing

If thermal reaches `serious` (iOS) or `moderate` (Android) before 30 minutes, reduce
threads or insert pacing between chunks, re-run, and record the table (threads, time,
peak thermal) in the perf report. Tier defaults are then updated under LLM-07.
