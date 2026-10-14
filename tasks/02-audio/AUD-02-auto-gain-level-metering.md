# AUD-02 — Auto-Gain Control & Level Metering

**Workstream:** Audio | **Phase:** 1 | **Size:** S | **Depends on:** AUD-01 | **Source:** §3.1.1
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-benchmark-eval, vv-testing

## Goal
Keep speech at a usable level for STT across quiet rooms and loud conference tables.

## Scope
- [ ] Evaluate platform AGC / noise suppression (`record` `autoGain`, `noiseSuppress`, `echoCancel`; Android `AutomaticGainControl`; iOS voice-processing IO) and their effect on Whisper WER.
- [ ] Software AGC fallback (RMS-target with attack/release, limiter to prevent clipping).
- [ ] Real-time RMS/peak level stream for the UI meter (APP waveform in AUD-08).
- [ ] Clipping detection with user hint ("move phone further away").
- [ ] Setting to disable processing (raw capture) for power users.

## Acceptance Criteria
- AGC/NS on vs off and software-AGC fallback are switchable via settings, with unit tests on the software AGC (gain limits, limiter at −1 dBFS).
- Default is provisional (platform AGC on); the data-driven WER comparison that confirms or changes it is done in QA-02.
- Meter updates ≥ 15 Hz without UI jank.

## Follow-ups
- From AUD-01: also measure the iOS audio-session **mode** (`.default` today vs `.measurement` /
  `.spokenAudio`) and the Android source (`VOICE_RECOGNITION` default vs `MIC`) on the QA-02
  corpus; set them in `buildRecordConfig` / the AUD-04 session code (ADR-AUD-01).
