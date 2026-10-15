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
- Codex review 2026-10-15 (open): Re-check call/foreground state right before opening the mic after async storage/permission work, and cancel pending opens on blocking events (recording_controller.dart:151); chunk writer: pause exactly at chunk rollover skips fade-out (recording_chunk_writer.dart:140) - add exact-rollover AC3 test.
- **AUD-09 (proposed): Compressed archive copy (AAC m4a, 32–64 kbps) after transcription** — native
  transcoder (iOS `AVAssetExportSession`/`AVAudioConverter`, Android `MediaCodec`) run as a pipeline
  step after STT; WAV deletion per SEC-04 retention setting. Deferred from AUD-01 scope.

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (0 changed) · analyze ✅ (no issues) · tests ✅ (785 passed, 24 skipped, coverage 93.2% of 4708 gated lines, min 80%) · native smoke ✅ (host ctest 9 passed / 14 skipped / 0 failed, includes `vv_crash`) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51, success, `67b6fcf`) and https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574 (run 50, success)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[AUD-01/AC1]` in the full suite (`record_capture_backend_test.dart`). The 7.3 s case asserts sample-exact 16 kHz mono WAV chunks with contiguous ranges and fades only at segment ends; the 2-hour case asserts 24 contiguous 5-minute chunks, exact byte length `44 + 300 * bytesPerSecond`, and duration 7 200 000 ms. Physical 2-hour device rows are still blank.
  - AC2: ✅ re-ran `[AUD-01/AC2]`. Asserts capture stops synchronously on `callActive`, keeps 2350 ms (3000 − 400 latency − 250 ms margin), writes a `call_interruption` marker, ignores hang-up, and refuses start while a call rings with the mic never opened. Checked it fails when `defaultDiscardMargin` is set to 0 (expected length 37600, got a longer buffer). Device call rows are blank.
  - AC3: ✅ re-ran `[AUD-01/AC3]`. Asserts pause/resume keeps every sample, excludes the paused span from the timer, and the boundary step is < 1000 (full-scale jump would be 60 000). Device tone-test row is blank.
  - AC4: ✅ device checklist `docs/test-plans/device/AUD-01.md` has a lock-screen row with steps and expected chunk-sum. Result/Date/Tester are empty (no Xcode or Android SDK on this machine).
- **Adversarial checks:** Call during capture and start-during-call are refused and do not auto-resume (tests above; controller ignores `callEnded` / `interruptionEnded` because they do not block capture). Background/headless start is refused (`notForeground`) on the same controller. Logs at info are codec id, gap kind, duration, sample rate, and input count — no paths or PCM. `check_recording_policy.sh` OK (no `READ_PHONE_STATE` / call audio source). Low-storage refuse/stop is covered by untagged tests in the same file. `tasks.py verify AUD-01 --run` does not execute tests once evidence errors exist; the tagged tests passed in `fvm flutter test`.
- **Skill/rule compliance:** Capture stays behind SEC-09 `CaptureBackend`; `record` 16 kHz PCM16 with Dart resample only when the platform rate differs (ADR-AUD-01). Chunk IO goes through `AudioChunkCodec`. UIBackground/FGS work is AUD-04/AUD-05. Deferred AAC archive and measured session-mode choice are ticked `[~]` with reasons. No new network hosts.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/AUD-01.md has no PASS result with a date; AC2: still pending (⏳) — cannot be done; AC2: device row in docs/test-plans/device/AUD-01.md has no PASS result with a date; AC3: still pending (⏳) — cannot be done; AC3: device row in docs/test-plans/device/AUD-01.md has no PASS result with a date; AC4: still pending (⏳) — cannot be done; AC4: device row in docs/test-plans/device/AUD-01.md has no PASS result with a date; dependency FND-02 is not done; dependency SEC-09 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
