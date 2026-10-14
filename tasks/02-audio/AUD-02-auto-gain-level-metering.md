# AUD-02 — Auto-Gain Control & Level Metering

**Workstream:** Audio | **Phase:** 1 | **Size:** S | **Depends on:** AUD-01 | **Source:** §3.1.1
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-benchmark-eval, vv-testing

## Goal
Keep speech at a usable level for STT across quiet rooms and loud conference tables.

## Scope
- [x] Evaluate platform AGC / noise suppression (`record` `autoGain`, `noiseSuppress`, `echoCancel`; Android `AutomaticGainControl`; iOS voice-processing IO) and their effect on Whisper WER. (API behaviour verified in ADR-AUD-02; the WER numbers are QA-02's per AC2.)
- [x] Software AGC fallback (RMS-target with attack/release, limiter to prevent clipping).
- [x] Real-time RMS/peak level stream for the UI meter (APP waveform in AUD-08).
- [x] Clipping detection with user hint ("move phone further away").
- [x] Setting to disable processing (raw capture) for power users.

## Acceptance Criteria
- AGC/NS on vs off and software-AGC fallback are switchable via settings, with unit tests on the software AGC (gain limits, limiter at −1 dBFS).
- Default is provisional (platform AGC on); the data-driven WER comparison that confirms or changes it is done in QA-02.
- Meter updates ≥ 15 Hz without UI jank.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/AUD-02-agc-level-metering · **Date:** 2026-10-14
- **Summary:** `SoftwareAgc` (−20 dBFS RMS target, 10 ms attack / 500 ms release, gain −12…+20 dB,
  −60 dBFS gate, −1 dBFS peak limiter), `LevelMeter` (RMS/peak dBFS per 50 ms = 20 Hz) +
  `ClipDetector` (≥ 0.5 % ≥ 32 000 in a sliding 1 s, on the pre-gain input), wired into
  `RecordCaptureBackend` (`levels` stream, `AudioLevel.silent` on pause/stop) →
  `recordingLevelsProvider` → `LevelMeterBar` (meter + "Too loud — move the phone further away."
  hint; on the dev Recording debug screen now, AUD-08 reuses it). Settings → Audio gains
  *App gain control* (`audio.software_agc`) and *Raw capture* (`audio.raw_capture`);
  `resolveAudioProcessing` maps settings × device effects (Android `AutomaticGainControl` /
  `NoiseSuppressor.isAvailable()` via a new `audioEffects` method on `StorageInfoPlugin.kt`; iOS
  VPIO through `record`'s `echoCancel`) to the `record` flags, re-read before every open/resume.
  Key files: `app/lib/features/recording/domain/{software_agc,level_meter,audio_processing}.dart`,
  `app/lib/features/recording/data/platform_audio_effects_probe.dart`,
  `app/lib/features/recording/presentation/level_meter_bar.dart`.
- **Acceptance evidence:**
  - AC1: ✅ test: [AUD-02/AC1]
  - AC2: ✅ test: [AUD-02/AC2]; artifact: docs/adr/ADR-AUD-02-agc-level-metering.md
  - AC3: ⏳ test: [AUD-02/AC3]; device: docs/test-plans/device/AUD-02.md
- **Decisions:** ADR-AUD-02-agc-level-metering (Proposed; QA-02 confirms the default).
  PRODUCT-DECISIONs: new settings default off (software AGC, raw capture); the software AGC is
  used automatically when the platform has no AGC; echo cancellation never requested on Android.
- **Stacking:** based on origin/main (AUD-01 in `review`).
- **Follow-ups:** none new (WER comparison → QA-02, per AC2).

## Follow-ups
- From AUD-01: also measure the iOS audio-session **mode** (`.default` today vs `.measurement` /
  `.spokenAudio`) and the Android source (`VOICE_RECOGNITION` default vs `MIC`) on the QA-02
  corpus; set them in `buildRecordConfig` / the AUD-04 session code (ADR-AUD-01).
