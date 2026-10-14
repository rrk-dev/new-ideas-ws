# QA-02 — STT Benchmark Corpus & WER Harness

**Workstream:** Quality | **Phase:** 2 | **Size:** M | **Depends on:** STT-03 | **Source:** §5 Phase 2 (benchmark transcription) + Gap
**Status:** in-progress
**Skills:** vv-task-workflow, vv-benchmark-eval, vv-whisper-stt

## Goal
Measure transcription accuracy and speed objectively across models, settings and devices.

## Scope
- [ ] Corpus: public sets (LibriSpeech test-clean/other, AMI meeting subset for multi-speaker, noisy samples) + consented internal recordings (accents, conference rooms, phone-in-pocket).
- [ ] Metrics: WER (normalized), real-time factor, peak RAM, energy (QA-03).
- [ ] Desktop + on-device runners producing comparable reports.
- [ ] Diarization DER on AMI subset (STT-05).
- [ ] AGC/noise-suppression on vs off WER comparison (AUD-02 default) and VAD trimming impact (AUD-03); record results and update the AUD-02 default.

## Acceptance Criteria
- One-command report comparing ≥ 2 models; baselines committed to `tools/bench/results/`.
