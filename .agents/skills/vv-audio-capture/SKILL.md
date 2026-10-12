---
name: vv-audio-capture
description: "Microphone recording policy and implementation: user-tap start only, never record phone/VoIP calls (CallGuard), 16 kHz WAV chunks, AGC/metering, VAD, iOS/Android session and interruptions, import, crash recovery, recording UI. Use for any recording code."
---

# Audio Capture

## Recording policy (SEC-09) — read first, non-negotiable
1. **Standard OS microphone APIs only**: `record` package → iOS AVAudioSession/AVAudioEngine,
   Android `AudioRecord` with `AudioSource.MIC` or `VOICE_RECOGNITION`. Nothing else.
2. **Never capture calls.** Forbidden: Android sources `VOICE_CALL`, `VOICE_UPLINK`,
   `VOICE_DOWNLINK`, `VOICE_COMMUNICATION`, `REMOTE_SUBMIX`; playback/MediaProjection capture;
   Accessibility Services; permissions `READ_PHONE_STATE`, `READ_CALL_LOG`,
   `PROCESS_OUTGOING_CALLS`, `ANSWER_PHONE_CALLS`, `CAPTURE_AUDIO_OUTPUT`, `MANAGE_OWN_CALLS`;
   iOS CallKit providers, `voip` background mode, `.mixWithOthers` while recording.
3. **CallGuard**: refuse to start during a call; when a call rings/starts while recording, stop
   capture within 500 ms, drop audio buffered after the call event, finalize the chunk, add a
   `call_interruption` gap. After the call: stay **paused** — resume only on user tap. Never
   auto-resume (also not on iOS `.shouldResume`).
   - iOS: `CXCallObserver` (`calls.contains { !$0.hasEnded }`) + audio-session interruptions.
   - Android: `AudioManager.mode` ∈ RINGTONE / IN_CALL / IN_COMMUNICATION / CALL_SCREENING /
     CALL_REDIRECT / COMMUNICATION_REDIRECT (`addOnModeChangedListener` on API 31+, poll 500 ms
     on 26–30) + `AudioRecordingCallback` `isClientSilenced()` (API 29+). No phone-state permission.
4. **User-started only**: start only from a direct user tap (app button, widget, quick-settings
   tile, iOS Control). Never from automations/Shortcuts automations, timers, location, push,
   MDM, app launch, VAD/voice activation, or any background/headless context.
5. **No pre-capture**: never open the mic input before the tap.
6. **Always visible**: OS indicator + Android ongoing notification + iOS Live Activity where
   supported. No hidden/discreet mode. Reminder every 60 min in background; auto-stop at max
   duration (default 4 h) and after configured silence.
7. **Consent**: SEC-07 confirmation step before multi-person recordings; imports require the
   user's rights/consent attestation.
Implement start requests through one `RecordingController.start(StartSource source)` where
`StartSource` is an enum of the allowed tap sources only — makes the rule testable.

## Format contract (everything downstream depends on it)
- PCM 16-bit little-endian, **16 000 Hz, mono**, WAV container (44-byte canonical header).
- Rolling chunks: `audio/<recording_id>/chunk_<seq:04d>.wav`, default 5 min each, seamless
  (no dropped/duplicated samples between chunks). `audio_chunks` row per chunk with start/end ms.
- Time base: milliseconds from recording start, **excluding paused spans**; pauses and
  interruptions stored as gap markers so transcript times map to wall-clock if needed.

## Recording (AUD-01) — `record` package (verify API on pinned version)
- Use `AudioRecorder.startStream(RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000,
  numChannels: 1, autoGain: …, echoCancel: …, noiseSuppress: …))`, write bytes yourself into
  chunk files (header placeholder → patch sizes on chunk close). This gives chunking + crash
  safety that `start(path)` doesn't.
- Input device selection: `AudioRecorder().listInputDevices()` → `RecordConfig(device: …)`;
  Android source: `RecordConfig(androidConfig: AndroidRecordConfig(audioSource:
  AndroidAudioSource.voiceRecognition | mic))` — only these two (SEC-09). Verify field names on
  the pinned `record` version.
- Some devices/routes won't deliver 16 kHz (Bluetooth HFP, some Android HALs). Detect the actual
  rate (first buffer size vs time, or platform query) and resample natively/in Dart with a
  proper low-pass resampler (not sample dropping). Test on Bluetooth headset.
- Flush to disk at least every 1 s (`RandomAccessFile.flush`) — required for AUD-07.
- Disk precheck: refuse to start with < 200 MB free; warn at < 500 MB; at 100 MB auto-stop
  and finalize. 1 h of 16 kHz PCM16 mono ≈ 115 MB.
- Optional archive copy (AAC m4a, 32–64 kbps) produced after transcription; WAVs deleted
  per retention policy (`vv-privacy-security`).

## Level metering & AGC (AUD-02)
- RMS/peak per 50 ms window from the stream (dBFS); UI meter ≥ 15 Hz via a throttled stream.
- Clipping: ≥ 0.5% samples at |x| ≥ 32 000 within 1 s → hint.
- Platform AGC/NS/AEC flags: evaluate on the QA-02 corpus (WER with vs without) — voice
  processing can hurt far-field meeting audio. Default chosen by data; record in task notes.
- Software AGC fallback: target −20 dBFS RMS, attack 10 ms, release 500 ms, max gain +20 dB,
  limiter at −1 dBFS.

## VAD (AUD-03)
- Options to compare (ADR): whisper.cpp VAD (Silero `ggml-silero-v6.2.0.bin`, ~0.9 MB, from HF
  `ggml-org/whisper-vad`): standalone `whisper_vad_init_from_file_with_params` +
  `whisper_vad_segments_from_samples` (segment times in centiseconds, float) for
  `speech_segments`, or `params.vad`/`vad_model_path` inside `whisper_full`; upstream defaults
  threshold 0.5, min speech 250 ms, min silence 100 ms, pad 30 ms; Silero VAD ONNX (via onnxruntime — adds a dependency), WebRTC VAD (tiny, weaker).
  Prefer reusing whisper.cpp's VAD if present at the pinned commit (no new runtime).
- Output: `speech_segments` (start/end ms) with min speech 250 ms, min silence 500 ms, pad 200 ms.
- Use for: skipping silence before STT, chunk boundaries (STT-04), auto-pause/auto-stop settings.

## iOS session (AUD-04)
- `Info.plist`: `NSMicrophoneUsageDescription`, `UIBackgroundModes` → `audio`.
- Category `.playAndRecord` with `.allowBluetoothHFP` (Xcode 26+ name; same raw value as the
  deprecated `.allowBluetooth`, back-deploys), `.defaultToSpeaker`; never `.mixWithOthers`.
  Optional `.bluetoothHighQualityRecording` (iOS 26+, mode `.default` only, not in the EU) —
  evaluate in AUD-02; mode `.default`
  (or `.measurement` to disable system processing — compare in AUD-02). Activate before start.
- Observe `AVAudioSession.interruptionNotification` (began → stop capture + gap marker; ended →
  stay paused, show "Tap to resume" — never auto-resume, ignore `.shouldResume`; iOS 27+ also observe `resumptionRecommendationNotification`
  (`InterruptionOptions` is deprecated in the iOS 27 SDK — keep the old path under `#available`
  for iOS 16–26; either way, only *offer* resume), `routeChangeNotification` (device change: keep recording, log
  route), `mediaServicesWereResetNotification` (rebuild engine, continue new chunk).
- Recording must be **started in foreground**; it may continue in background with the audio mode.

## Android (AUD-05)
- Manifest: `RECORD_AUDIO`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`,
  `POST_NOTIFICATIONS`; service `android:foregroundServiceType="microphone"`.
- Android 14+: a microphone FGS **cannot be started from the background** — start it while
  the activity is visible (user tapped Record). Call `startForeground` within 5 s.
- Ongoing notification with Pause / Stop actions (PendingIntent → service).
- Calls / concurrent capture: CallGuard (policy §3) → stop capture + gap marker, stay paused
  until user taps Resume.
- OEM battery killers (Samsung, Xiaomi, OnePlus): in-app guidance + link to battery settings;
  never request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` without a Play-policy-valid reason.

## Chunk writer & optional encryption (SEC-01)
All chunk IO goes through `AudioChunkWriter` / `AudioChunkReader` (Dart interface + native reader
in the bridge) with a codec chosen by the SEC-01 ADR, so AUD-01 never hard-codes the file format:
- `wav` (default, Phase 1): plaintext 16 kHz WAV in app-private storage, protected by OS file
  encryption (iOS Data Protection `CompleteUntilFirstUserAuthentication`; Android credential-
  encrypted storage / file-based encryption, the default for `filesDir`).
- `vvenc` (if SEC-01 chooses app-level encryption): file = header `{magic "VVA1", version,
  sample_rate, channels, key_id, base_nonce}` + frames of ≤ 64 KB PCM, each
  `AES-256-GCM(nonce = base_nonce ⊕ frame_index)` with a 16-byte tag and length prefix. Per-file
  key wrapped by the Keychain/Keystore master key (crypto-shredding on delete). Crash recovery =
  drop the incomplete last frame. Native STT reads via `vv_stt_transcribe_async` with an optional
  `vv_key` handle (decrypt in the reader thread; never write plaintext temp files); playback
  (STT-06) via a `just_audio` `StreamAudioSource` that decrypts on the fly.

## Import (AUD-06)
- iOS: `AVAssetReader` → linear PCM 16 kHz mono (`AVAudioConverter`); Android: `MediaExtractor`
  + `MediaCodec` → PCM → resample. Expose via Pigeon `decodeToWav(src, dstDir) → chunks`.
- Inputs: share sheet (iOS share extension or "Open in" document types; Android `ACTION_SEND`
  / `ACTION_VIEW` intent filters for `audio/*`), file picker. Copy into app storage first.
- Formats: iOS AVFoundation decodes m4a/AAC, mp3, wav, flac (iOS 11+), caf — **not Ogg/Opus**;
  Android MediaCodec decodes all of them incl. ogg/opus. Show unsupported formats as such on iOS
  (or vendor libogg/libopus — BSD — into the bridge via ADR). AC = per-platform format table.
- iOS share extension: the extension copies the file into an **App Group** shared container
  (`group.<bundle-id>`), writes a small JSON job file, and opens the app; the app imports from
  the group container and deletes the copy. Android: `ACTION_SEND`/`ACTION_VIEW` intent → copy via
  `ContentResolver.openInputStream` immediately (URI grants are temporary).
- Preserve source creation date for filename templates. No bundled ffmpeg (size, licensing).
- Before processing an import, require the rights/consent attestation (SEC-09) and store
  `import_attested_at`. Never advertise or special-case call-recorder apps.

## Crash recovery (AUD-07)
On launch: for recordings with status `recording`/`in_progress`, for each chunk compute
`dataBytes = fileLength − 44` (round down to even), rewrite RIFF size (`36 + dataBytes`) and
data size; mark recording `recorded` with `recordings.recovered = true`; ask user to process.
Encrypted chunk format (below): truncate to the last complete frame instead of patching a header.

## Recording UI (AUD-08)
Big record/pause/stop, timer, live meter/waveform (downsampled peaks), marker button
(`markers` row with `kind = user`), profile + destination pickers (or Auto), consent step (SEC-07:
profile `consent_confirmation: required` ⇒ blocking "Everyone present agrees" confirmation before
the mic opens → `recordings.consent_confirmed_at`), "Recording unavailable during calls" state.
Entry points: in-app button, home-screen widget, Android quick-settings tile — each a deliberate
tap that opens the app's recording screen. An iOS Control/App Intent (if built) must set
`openAppWhenRun = true`, `isDiscoverable = false` and only *navigate* to the recording screen —
the actual start still requires the in-app tap, so a Shortcuts automation can never start
recording (App Intents APIs are version-sensitive — verify).
Recording starts < 300 ms after tap: prepare non-microphone resources (file handles, DB row,
UI) on screen open, but open the microphone input only after the tap (policy §5).

## Verification
- 2 h recording both platforms: chunks valid (`ffprobe` / `soxi` show 16 kHz mono), total
  duration = timer ± 0.5 s, no gaps at chunk boundaries (cross-correlation test on a tone).
- Interruptions scripted per QA-04; force-kill recovery test (10 runs, ≤ 1 s loss).
- Call tests (cellular + VoIP, foreground/background/locked): zero call audio in files, no
  auto-resume, start refused during call. `tools/ci/check_recording_policy.sh` passes.
