# AUD-01 — Core Audio Recording Service (16 kHz Mono WAV)

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** FND-02, SEC-09 | **Source:** §3.1.1, §4.1, §5 Phase 1
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-testing

## Goal
Reliable, low-latency recording directly in the format Whisper consumes (16 kHz, mono, 16-bit PCM WAV).

## Scope
- [x] Implement `AudioRecorder` using the `record` package (PCM16 stream → WAV); fall back to native platform code if `record` can't guarantee 16 kHz on a device (resample in native). — `RecordCaptureBackend` + `RecordMicSource`; non-16 kHz input is resampled by the band-limited `PcmConverter` in Dart instead of new native code (ADR-AUD-01); FND-02's `AudioRecorder` interface retired in favour of SEC-09's `CaptureBackend`.
- [x] Start / pause / resume / stop with accurate elapsed time. — via `RecordingController`; recorded duration from the sample count.
- [x] All chunk IO through `AudioChunkWriter` with the codec chosen by the SEC-01 ADR (plain WAV by default; `vvenc` if app-level encryption is chosen) — `vv-audio-capture` → Chunk writer.
- [x] Write audio in rolling chunk files (e.g., 5-min segments) to bound corruption and enable streaming STT (STT-04).
- [~] deferred → AUD-09 Optional compressed archive copy (m4a/AAC) for long-term storage; WAV kept only until transcription completes (configurable — see SEC-04). — reason: needs a native AAC transcoder run after transcription (pipeline step) plus the SEC-04 retention setting; not part of capture.
- [~] deferred → AUD-02 Audio session config: iOS `AVAudioSession` category `.playAndRecord`/`.record` (never `.mixWithOthers`), mode `.measurement` or `.spokenAudio`; Android `AudioSource.VOICE_RECOGNITION` vs `MIC` evaluation — **only** these two sources are allowed (SEC-09). — done here: `.playAndRecord` + `defaultToSpeaker`/`allowBluetooth`, never mix (pinned by tests), Android `VOICE_RECOGNITION` default / `MIC` selectable, nothing else expressible; deferred: the *measured* choice of iOS mode and Android source, which AUD-02 makes on the QA-02 corpus together with AGC/voice processing (mode stays the plugin's `.default` until then).
- [x] Integrate SEC-09 `CallGuard` and start-source rules: recording starts only from an explicit user tap and never during a call.
- [x] Input device selection (built-in, wired, Bluetooth HFP — note HFP is 8/16 kHz). — `inputDevices()`/`selectInput()` (picker UI: AUD-08; dev debug screen now).
- [x] Disk-space precheck and low-space warning while recording. — refuse < 200 MB, warn < 500 MB, stop + finalize < 100 MB (`StorageInfoPlugin`).

## Acceptance Criteria
- 2-hour recording on both platforms produces valid, gapless WAV chunks at 16 kHz mono.
- Foreground call test (cellular + VoIP): capture stops ≤ 500 ms after ringing, no call audio in the file (listen + waveform), recording stays paused after hang-up until Resume (SEC-09).
- Pause/resume produces no clicks or duplicated samples.
- Recording continues when the screen locks (with AUD-04/AUD-05).

## Notes
- Recording policy (SEC-09) is mandatory: standard OS microphone APIs only, user-started only, never call audio.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/AUD-01-recording-service · **Date:** 2026-10-13
- **Summary:** Real `CaptureBackend` for SEC-09's `RecordingController`: `RecordMicSource`
  (`record` 7.1.2 PCM16 16 kHz mono stream; policy config pinned in `buildRecordConfig`) →
  `PcmConverter` (band-limited resampler/down-mix, only if the platform reports another format) →
  `RecordingChunkWriter` (5-min rolling chunks through the `AudioChunkCodec` seam, `WavChunkCodec`
  default; header patched + synced every ≤ 1 s flush; `audio_chunks`/`markers`/`recordings` rows via
  FND-04's `RecordingsRepository`; 10 ms fades at segment ends; call discard by sample count incl.
  across a chunk rollover). Storage policy via new `StorageInfoPlugin` (Kotlin/Swift). Controller
  gained capture notices (low-storage stop, OS interruption/stream failure → pause, never resume)
  and passes the stop cause. FND-02 `AudioRecorder` retired (`fakeEngineOverrides(capture:)`).
  Dev-flavor "Recording debug" screen for the device rows. `NSMicrophoneUsageDescription` and
  `RECORD_AUDIO` added. Key files: `app/lib/features/recording/{data,domain}/`,
  `docs/adr/ADR-AUD-01-recording-service.md`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [AUD-01/AC1]; device: docs/test-plans/device/AUD-01.md
  - AC2: ⏳ test: [AUD-01/AC2]; device: docs/test-plans/device/AUD-01.md
  - AC3: ⏳ test: [AUD-01/AC3]; device: docs/test-plans/device/AUD-01.md
  - AC4: ⏳ device: docs/test-plans/device/AUD-01.md
- **Decisions:** ADR-AUD-01-recording-service. PRODUCT-DECISIONs: 250 ms extra discard before a
  call event; unknown free space does not block recording; resume refused below 200 MB; Bluetooth
  SCO only when the user picks a Bluetooth input; voice processing (AGC/AEC/NS) off until AUD-02;
  `NSMicrophoneUsageDescription` copy (pending SEC-09 legal wording review).
- **Stacking:** based on origin/main (SEC-09, FND-04, FND-05, QA-01 in `review`, authorised by the
  user). AUD-07 → AUD-05 → AUD-04 are stacked on this branch.
- **Follow-ups:** AUD-09 (proposed), AUD-02 note.

## Follow-ups
- **AUD-09 (proposed): Compressed archive copy (AAC m4a, 32–64 kbps) after transcription** — native
  transcoder (iOS `AVAssetExportSession`/`AVAudioConverter`, Android `MediaCodec`) run as a pipeline
  step after STT; WAV deletion per SEC-04 retention setting. Deferred from AUD-01 scope.
