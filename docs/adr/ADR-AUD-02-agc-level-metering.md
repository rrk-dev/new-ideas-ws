# ADR-AUD-02 — Gain control, noise suppression and level metering

- **Status:** Proposed (provisional default) — QA-02 confirms or changes the default with WER data
- **Date:** 2026-10-14
- **Task:** AUD-02
- **Deciders:** Claude Code (implementer); pending independent verifier and QA-02 numbers
- **Builds on:** ADR-AUD-01-recording-service (`record` PCM stream → Dart chunk writer)

## Context
Speech must reach whisper.cpp at a usable level both in a quiet room (one speaker, phone
on the table) and at a loud conference table. Platform voice processing (AGC, noise suppression,
echo cancellation) is cheap but tuned for near-field calls, and it can hurt far-field meeting
audio. The task requires the processing to be switchable (including a raw-capture power-user
switch), a software AGC fallback, a ≥ 15 Hz meter and a clipping hint. **Which default gives the
lower WER is a measurement, made on the QA-02 corpus — not in this task.**

## What the platforms actually do (verified against the pinned sources)
- **record_android 2.2.0** `AudioEffectsManager`: creates `AutomaticGainControl`,
  `NoiseSuppressor` and `AcousticEchoCanceler` on the `AudioRecord` session when
  `X.isAvailable()`, enabled by `autoGain` / `noiseSuppress` / `echoCancel`. Availability varies
  by device, so the app asks the same `isAvailable()` (new `audioEffects` method on the existing
  `vaultvoice/storage_info` channel, `StorageInfoPlugin.kt`).
- **record_ios 2.1.1** `RecorderStreamDelegate.setVoiceProcessing`:
  `inputNode.setVoiceProcessingEnabled(echoCancel)` and
  `inputNode.isVoiceProcessingAGCEnabled = autoGain`; `noiseSuppress` is **ignored**. On iOS
  AGC and noise suppression only exist inside the voice-processing I/O unit, so the app maps
  "AGC or NS wanted" → `echoCancel: true` (VPIO on) and `autoGain` → VPIO AGC.
- `AudioSource.VOICE_RECOGNITION` (our default, ADR-AUD-01) has no AGC on most Android devices —
  the effect has to be attached explicitly, which `record` does.

## Options considered
1. **Platform effects by default, software AGC as fallback / opt-in, raw switch (chosen).**
   Cheapest at runtime, uses hardware DSP where present; the fallback keeps behaviour consistent
   on devices without AGC.
2. Software AGC always, platform effects off. Same behaviour everywhere, but no noise
   suppression and it ignores device-specific tuning; may be better far-field — QA-02 decides.
3. Raw capture always. Best for whisper.cpp on clean far-field audio according to some reports,
   worst for quiet speakers. Available as the raw-capture switch.

## Decision
- Settings (Settings → Audio, `SettingKeys`): `audio.agc` (platform AGC, default **on**),
  `audio.noise_suppression` (default **on**), `audio.software_agc` (new, default off: app AGC
  replaces the platform AGC), `audio.raw_capture` (new, default off: no processing at all).
  The defaults are **provisional** (task AC2); QA-02 runs the corpus with each combination
  (platform on/off, software AGC, raw) and updates the defaults here.
- `resolveAudioProcessing(settings, effects)`:
  raw → nothing; software chosen → platform AGC off + software AGC; platform AGC wanted but
  unavailable → software AGC (fallback); iOS → VPIO via `echoCancel`; echo cancellation is
  otherwise never requested (nothing is played back while recording).
- Settings are re-read before every open/resume, so a change applies from the next segment.
- **Software AGC** (`SoftwareAgc`, Dart, per segment, after resampling, before the chunk writer):
  50 ms mean-square RMS level; target −20 dBFS RMS; gain clamped to [−12 dB, +20 dB]; gain moves
  down with a 10 ms (attack) and up with a 500 ms (release) time constant; noise gate at −60 dBFS
  (gain held, silence never boosted); peak limiter at −1 dBFS (gain cut to fit, instant attack).
  Sample count unchanged (chunk timing / AUD-07 recovery unaffected). Cost: one multiply and a
  few compares per sample (16 k samples/s) on the UI isolate — same order as `PcmConverter`.
- **Meter** (`LevelMeter`): RMS + peak in dBFS per 50 ms window of written audio → 20 readings per
  second of audio (≥ 15 Hz), streamed as `RecordCaptureBackend.levels` → `recordingLevelsProvider`;
  `AudioLevel.silent` on pause/stop. The UI widget (`LevelMeterBar`) rebuilds only itself inside a
  `RepaintBoundary`.
- **Clipping** (`ClipDetector`): ≥ 0.5 % of samples at |x| ≥ 32 000 within a sliding 1 s window,
  measured on the input **before** software gain → `AudioLevel.clipping` → hint "Too loud — move
  the phone further away."

## Consequences
- Defaults may change after QA-02; changing a default is a one-line change in
  `AppSettings` + this ADR (stored user choices are kept).
- iOS VPIO may change the input format and adds processing latency; the AUD-01 converter already
  handles format changes. VPIO also ducks other audio — acceptable while recording.
- Follow-up from AUD-01 stays with QA-02: iOS session mode (`.default` vs `.measurement`) and the
  Android source (`VOICE_RECOGNITION` vs `MIC`) are measured on the same corpus.
- Device-only evidence (meter smoothness, real effect behaviour): docs/test-plans/device/AUD-02.md.
