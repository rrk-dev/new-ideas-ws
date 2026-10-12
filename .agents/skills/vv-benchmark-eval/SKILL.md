---
name: vv-benchmark-eval
description: "Measuring quality and speed: STT WER/RTF corpus, diarization DER, LLM extraction eval harness, runtime/model comparisons, on-device perf/battery/thermal protocol, budgets and regressions. Use when a decision or acceptance criterion needs numbers."
---

# Benchmarks & Evals

All harnesses live in `tools/bench/` and run on the **host build** of the same bridge
(`native/build.sh host`) for iteration, plus an on-device runner for final numbers.
Results go to `tools/bench/results/<date>-<what>.md` (+ raw JSON). Never commit real user audio.

## Reporting rules (any number you write in an ADR or task)
State: device + OS, build flags, commit of whisper/llama/bridge, model file + sha256, params,
thermal start state, n runs (≥ 3, report median and min/max), wall time incl./excl. model load.

## STT (QA-02)
- Corpus `tools/bench/corpus/`: manifest `corpus.jsonl` lines
  `{"id","audio","ref","speakers?","tags":["clean|noisy|far|accent|meeting"]}`.
  Sources: LibriSpeech test-clean/test-other subsets (CC BY 4.0), AMI meeting subset (CC BY 4.0)
  for multi-speaker + DER, plus consented internal recordings (signed consent, stored outside
  the repo; manifest references a private path).
- Normalize before WER: lowercase, strip punctuation, numbers→words or both sides consistent,
  collapse whitespace (Whisper EnglishTextNormalizer equivalent — keep identical across runs).
  `python3 .agents/skills/vv-benchmark-eval/scripts/wer.py ref.txt hyp.txt` gives a dependency-free WER for quick checks; use `jiwer`
  in the full harness if available.
- Metrics: WER, RTF (= processing time / audio duration), peak RSS, load time, energy (below).
- DER (STT-05): `pyannote.metrics` or `dscore` on AMI RTTM; collar 0.25 s.

## LLM extraction eval (PRF-09)
- Dataset `tools/bench/eval/<profile_id>/<case_id>/{transcript.txt, expected.json, meta.json}`;
  ≥ 30 cases per built-in profile: short/long, 1–6 speakers, noisy STT output (use real
  Whisper output, not clean text), edge cases (no action items, conflicting owners, relative dates).
- Creating cases without real people: write a scripted dialogue (`script.md` with speaker
  turns) → synthesize audio per speaker (macOS `say -v <voice> -o x.aiff`, or Piper TTS — check
  its license) → mix to 16 kHz mono with sox/ffmpeg (dev tools only, not in the app) → run the
  **host whisper build** to get a realistic `transcript.txt` (keep the ASR errors) → hand-write
  `expected.json` from the script.
- Entry point: `make eval PROFILE=meeting MODEL=<gguf>` (root `Makefile` target wrapping the
  runner); CI wrapper `tools/ci/eval.sh`.
- Runner: `tools/bench/eval/run.py --profile meeting --model <gguf> [--device]` → uses the
  exact prompt builder logic (export prompts from Dart via a CLI entrypoint
  `app/tool/render_prompt.dart` so host eval and app use identical prompts).
- Metrics per case and aggregate:
  - schema_valid (%), repair_used (%)
  - scalar fields: exact match after normalization; dates compared after resolution
  - list fields: precision / recall / F1 with fuzzy matching (token-set ratio ≥ 0.8 or
    embedding-free Jaccard ≥ 0.6) one-to-one (greedy by score)
  - owner accuracy on matched action items
  - hallucination rate: extracted items with no supporting span in transcript (fuzzy ≥ 0.5)
  - latency: prefill tok/s, decode tok/s, total s, peak RAM
- Output a diff vs baseline (`results/baseline-<profile>.json`); a prompt PR must not reduce
  F1 by > 2 points or schema validity below 99% without explicit approval.

## Runtime / model comparison (LLM-01, LLM-08, STT-07)
Same prompts, same quant class (≈4-bit), same context; measure cold load, prefill tok/s on a
2k-token prompt, decode tok/s for 256 tokens, peak RSS, and eval F1. Use `llama-bench` /
`whisper-bench` from the pinned commits for raw speed sanity checks, then our harness for
end-to-end.

## On-device performance, battery, thermal (QA-03)
- Budgets (initial, revise via ADR): 60-min meeting processed end-to-end ≤ 15 min High tier,
  ≤ 30 min Low tier; ≤ 10% battery per hour of audio processed (High tier); app never
  reaches iOS `.critical` / Android `THERMAL_STATUS_SEVERE` in a 30-min run at room temp.
- iOS: Instruments (Time Profiler, Metal System Trace, Energy Log via device), or
  `MetricKit` reports in dev builds. Android: Perfetto traces, `dumpsys batterystats`
  (reset → run → dump) / Battery Historian, `dumpsys thermalservice`.
- Protocol: 100% → unplugged, airplane mode, brightness fixed, screen off where possible,
  start at nominal thermal state, log battery % and thermal every 30 s from the app's FND-07 metrics.
- Track per release in `tools/bench/results/perf-history.md`; > 10% regression blocks release.

## In-app metrics collection (FND-07)
Per job record: STT real-time factor (wall time / audio duration), LLM prefill & decode tok/s
(from bridge callbacks), peak RSS (`vv_proc_memory`: iOS `task_vm_info.phys_footprint` /
Android `/proc/self/status` VmHWM), battery % before/after (`battery_plus` or platform query),
thermal state transitions. Stored locally in `settings`/a metrics table; exported only via the
diagnostics zip.

## Data-driven defaults
AGC/NS on vs off (AUD-02), VAD thresholds (AUD-03), beam vs greedy and thread counts (STT),
KV quantization and ctx per tier (LLM-07): each decided by a table in the task's Completion
Notes produced with this methodology.
