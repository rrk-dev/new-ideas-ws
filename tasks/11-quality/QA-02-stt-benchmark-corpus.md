# QA-02 — STT Benchmark Corpus & WER Harness

**Workstream:** Quality | **Phase:** 2 | **Size:** M | **Depends on:** STT-03 | **Source:** §5 Phase 2 (benchmark transcription) + Gap
**Status:** review
**Skills:** vv-task-workflow, vv-benchmark-eval, vv-whisper-stt

## Goal
Measure transcription accuracy and speed objectively across models, settings and devices.

## Scope
- [x] Corpus (LibriSpeech test-clean subset + synthetic accents/meetings/noisy variants; AMI → STT-05; consented internal recordings: none exist yet — `run.py --corpus <private manifest>` takes them from outside the repo): public sets (LibriSpeech test-clean/other, AMI meeting subset for multi-speaker, noisy samples) + consented internal recordings (accents, conference rooms, phone-in-pocket).
- [x] Metrics (WER, RTF, cold load, peak RSS on host; energy is QA-03): WER (normalized), real-time factor, peak RAM, energy (QA-03).
- [~] deferred → QA-06 (proposed: on-device corpus runner in the dev build writing the same JSONL schema). Desktop runner done; device numbers via `docs/test-plans/device/QA-02.md`.
- [~] deferred → STT-05 (diarization does not exist yet; DER on AMI belongs with it).
- [x] AGC/noise-suppression on vs off WER comparison (AUD-02 default) and VAD trimming impact (AUD-03); record results and update the AUD-02 default.

## Acceptance Criteria
- One-command report comparing ≥ 2 models; baselines committed to `tools/bench/results/`.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/QA-02-stt-benchmark-corpus (base origin/main) ·
  **Date:** 2026-10-14
- **Summary:**
  - Corpus `tools/bench/corpus/`: `corpus.jsonl` (48 items: 8 synthetic scripts in `scripts/` —
    our own text, macOS `say` US/UK/IE/IN/AU voices, 1–3 speakers — and 40 LibriSpeech
    test-clean utterances, CC BY 4.0, refs in `librispeech-test-clean.jsonl`).
    `make_corpus.py` builds the audio **outside the repo** (`$VV_BENCH_CORPUS_DIR`), downloads
    LibriSpeech with a pinned sha256. No audio or personal data committed.
  - Harness `tools/bench/stt_wer/`: `bridge.py` (ctypes on the app's `vv_stt_*` C ABI with the
    app's default params, host build), `wer.py` (fixed English normalizer + S/D/I alignment),
    `audio.py` (noise/level conditions, port of AUD-02 `SoftwareAgc`, pause padding),
    `run.py` — one command: `python3 tools/bench/stt_wer/run.py` → models × corpus (3 runs,
    RTF median), software AGC off/on under 5 conditions, VAD trimming (untrimmed / oracle /
    energy VAD via `vv_stt_transcribe_ranges`).
  - Baseline: `tools/bench/results/2026-10-14-qa02-stt-wer.{md,jsonl}` — tiny.en 3.68 %,
    base.en-q5_1 2.61 %, small.en-q5_1 1.48 % WER; RTF 0.017 / 0.040 / 0.106 (M3 Pro, CPU).
  - Defaults fed back: software AGC **off** (no gain, slightly worse in noise) — AUD-02's
    provisional default stands, platform AGC/NS on/off needs the device rows; VAD trimming
    **on** (−35 % processing, fewer silence insertions; keep ≥ 200 ms padding) for AUD-03.
    AUD-02/AUD-03 live on other branches, so their ADRs are not edited here — the integration
    agent should copy the two recommendations into ADR-AUD-02 / ADR-AUD-03.
- **Acceptance evidence:**
  - AC1: ✅ test: [QA-02/AC1]; artifact: tools/bench/results/2026-10-14-qa02-stt-wer.md
- **Decisions:** none (methodology per vv-benchmark-eval). Device plan:
  `docs/test-plans/device/QA-02.md` (platform AGC/NS, device RTF — ⏳, not an AC).
- **Follow-ups:** QA-06 (proposed, on-device corpus runner); DER on AMI with STT-05.
