# AUD-01 — Core Audio Recording Service (16 kHz Mono WAV)

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** FND-02, SEC-09 | **Source:** §3.1.1, §4.1, §5 Phase 1
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-testing

## Goal
Reliable, low-latency recording directly in the format Whisper consumes (16 kHz, mono, 16-bit PCM WAV).

## Scope
- [ ] Implement `AudioRecorder` using the `record` package (PCM16 stream → WAV); fall back to native platform code if `record` can't guarantee 16 kHz on a device (resample in native).
- [ ] Start / pause / resume / stop with accurate elapsed time.
- [ ] All chunk IO through `AudioChunkWriter` with the codec chosen by the SEC-01 ADR (plain WAV by default; `vvenc` if app-level encryption is chosen) — `vv-audio-capture` → Chunk writer.
- [ ] Write audio in rolling chunk files (e.g., 5-min segments) to bound corruption and enable streaming STT (STT-04).
- [ ] Optional compressed archive copy (m4a/AAC) for long-term storage; WAV kept only until transcription completes (configurable — see SEC-04).
- [ ] Audio session config: iOS `AVAudioSession` category `.playAndRecord`/`.record` (never `.mixWithOthers`), mode `.measurement` or `.spokenAudio`; Android `AudioSource.VOICE_RECOGNITION` vs `MIC` evaluation — **only** these two sources are allowed (SEC-09).
- [ ] Integrate SEC-09 `CallGuard` and start-source rules: recording starts only from an explicit user tap and never during a call.
- [ ] Input device selection (built-in, wired, Bluetooth HFP — note HFP is 8/16 kHz).
- [ ] Disk-space precheck and low-space warning while recording.

## Acceptance Criteria
- 2-hour recording on both platforms produces valid, gapless WAV chunks at 16 kHz mono.
- Foreground call test (cellular + VoIP): capture stops ≤ 500 ms after ringing, no call audio in the file (listen + waveform), recording stays paused after hang-up until Resume (SEC-09).
- Pause/resume produces no clicks or duplicated samples.
- Recording continues when the screen locks (with AUD-04/AUD-05).

## Notes
- Recording policy (SEC-09) is mandatory: standard OS microphone APIs only, user-started only, never call audio.
