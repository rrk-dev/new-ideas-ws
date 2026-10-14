# ADR-AUD-01 — Recording service: `record` PCM stream → Dart chunk writer

- **Status:** Accepted (engineering); device numbers pending (docs/test-plans/device/AUD-01.md)
- **Date:** 2026-10-13
- **Task:** AUD-01
- **Deciders:** Claude Code (implementer); pending independent verifier
- **Builds on:** ADR-SEC-09-recording-policy (CallGuard, `RecordingController`, `CaptureBackend`),
  ADR-FND-04-database (recordings / audio_chunks / markers tables)

## Context
Every downstream step (VAD, whisper.cpp, diarization, playback) consumes 16 kHz mono PCM16 WAV
chunks (`vv-audio-capture` → Format contract). Recording must be crash-safe (AUD-07: ≤ 1 s loss),
must drop call audio within the SEC-09 budget, must not click at pause/resume and must not
hard-code the chunk file format (SEC-01 may choose app-level encryption).

## Options considered
1. **`record` package `startStream(pcm16bits, 16 kHz, mono)` + our own chunk writer in Dart
   (chosen).** Standard OS microphone APIs (AVAudioEngine / `AudioRecord`), one Dart code path for
   both platforms, full control of chunking, flushing, discard and fades. Verified against
   record 7.1.2 (record_android 2.2.0, record_ios 2.1.1, record_platform_interface 2.1.0).
2. `record.start(path)` (file mode) — the plugin writes one file; no chunking, no crash-safe header
   patching, no way to cut audio after a call event.
3. Own native recorder (Kotlin `AudioRecord` + Swift `AVAudioEngine`) via Pigeon — most control,
   but two implementations to write and test without devices; `record` already covers the APIs.
   Kept as the fallback if device tests show `record` cannot deliver usable PCM on some HAL.

### Resampling when the device does not deliver 16 kHz
`record` reports the effective config (`setOnConfigChanged`) when the hardware forces another rate
(Bluetooth HFP 8 kHz, fixed 44.1/48 kHz HALs; iOS converts with `AVAudioConverter` itself).
We resample **in Dart** (`PcmConverter`: polyphase windowed-sinc, Blackman window, cutoff 0.92 ×
the lower Nyquist, unity DC gain per phase, channel down-mix) instead of new native code: same code
on both platforms, unit-tested (≥ 50 dB rejection above the new Nyquist, exact output length).
The cost (≈ 1.5 M MAC/s for 48→16 kHz) is negligible on the UI isolate.

## Decision
- **Seams:** `PcmMicSource` (domain) ← `RecordMicSource` (the only code that calls the plugin's
  `startStream`); `AudioChunkCodec`/`AudioChunkWriter` (domain) ← `WavChunkCodec` (default; SEC-01
  can override `audioChunkCodecProvider` with `vvenc`); `DiskSpaceProbe` ←
  `MethodChannelDiskSpaceProbe` (`StorageInfoPlugin.kt/.swift`, channel `vaultvoice/storage_info`,
  plain MethodChannel like CallGuard — one call, no codegen).
- **`RecordCaptureBackend implements CaptureBackend`**, driven only by `RecordingController`. The
  policy source test pins: only `RecordMicSource` starts the plugin stream; only the backend opens a
  `PcmMicSource`, only from `openMicrophone`/`resumeCapture`.
- **Plugin config (`buildRecordConfig`, pinned by tests):** PCM16 16 kHz mono; Android
  `voiceRecognition` (default) or `mic` only, `audioManagerMode: modeNormal` (never written), no
  stream muting, no speakerphone, Bluetooth SCO only when the user picked a Bluetooth input (so
  merely recording never changes the communication route that CallGuard watches); iOS
  `.playAndRecord` + `defaultToSpeaker` + `allowBluetooth` (HFP), never `mixWithOthers`;
  `AudioInterruptionMode.pause` (the plugin pauses on interruption and never resumes by itself —
  we then surface `CaptureNotice.interrupted` → controller pause).
- **Chunks:** `audio/<recording_id>/chunk_<seq:04d>.wav`, 5 min each, rollover at an exact sample
  count (seamless). Each open-microphone *segment* (start→pause, resume→stop) starts a new chunk;
  10 ms raised-cosine fade-in/out at segment ends (no clicks, no sample added or removed).
  Time base = samples written (paused spans excluded); `audio_chunks.start_ms/end_ms` from sample
  counts; gaps as `markers` rows (`call_interruption` kind for calls, `gap` with the `GapKind` wire
  name as label otherwise).
- **Crash safety:** every `flush` (timer, ≤ 1 s) patches the RIFF/data sizes and syncs; the
  `audio_chunks` row and `recordings.duration_ms` are updated at the same cadence. Status
  `recording` while the mic is open, `inProgress` while paused, `recorded` on stop (AUD-07 repairs
  rows left in the first two states).
- **Calls:** `suspend` stops accepting audio synchronously, then truncates audio received after
  `discardFrom − 250 ms` (PRODUCT-DECISION margin for delivery latency; may reach back across a
  chunk rollover, never into the previous segment), fades and finalizes the chunk. Resampler tail
  after a call event is dropped.
- **Storage:** refuse start/resume < 200 MB free, warn < 500 MB, stop + finalize < 100 MB (checked
  every 30 s); unknown free space does not block (PRODUCT-DECISION).
- **`core/platform/AudioRecorder` retired:** its bare `start()` (no `StartSource`) contradicts
  SEC-09. `RecordedAudio` stays (now with `recordingId`); the fake/override moved to
  `captureBackendProvider` (`FakeCaptureBackend`, `fakeEngineOverrides(capture:)`).
- **Interface additions to SEC-09's seam:** `CaptureBackend.close({StopCause cause})`,
  `CaptureBackend.notices`, `StopCause.lowStorage`, `PauseCause.captureError`,
  `GapKind.captureError`. Nothing in them can resume capture.

## Consequences
- Positive: one tested Dart capture path; codec swap for SEC-01 is a provider override; files are
  valid WAVs at all times; call audio is cut by sample count, not by timer.
- Negative / risks (device rows): Bluetooth HFP quality and whether SCO on API 31+
  (`setCommunicationDevice`) changes the audio mode on some OEMs (would read as a call → pause —
  fail-safe); first ~ms of audio between plugin start and our listen may be lost; iOS audio-session
  mode stays the plugin's `.default` until AUD-02 measures `.measurement`/`.spokenAudio`.
- Follow-ups: AUD-09 (proposed) compressed archive copy; AUD-02 mode/source evaluation; AUD-04/05
  background + notification + session handling; AUD-07 recovery; AUD-08 UI (input picker).
