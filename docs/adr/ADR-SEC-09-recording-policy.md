# ADR-SEC-09 — Recording policy: user-started only, standard mic APIs, never record calls

- **Status:** Accepted (engineering); consent/attestation wording **pending legal review** (see below)
- **Date:** 2026-10-12
- **Task:** SEC-09
- **Deciders:** Claude Code (implementer); pending independent verifier; product/legal for wording
- **Supersedes:** —
- **Amendments:** 2026-10-17 (human decision, ADR-QCP-01): §4 bullet 1 quick-capture entry points are navigate-only (Amendment 1); §5 Live Activity requirement satisfied by OS + AUD-04 indicators until AUD-13 (Amendment 4). No `StartSource` value added.

## Context
VaultVoice records audio. The product/legal requirement (user directive) is that the app can only
capture audio the device user deliberately started recording, through the standard permission-gated
OS microphone APIs, and that it never captures telephone or VoIP call audio. The rule must be
*structural* (hard to violate by accident, checked by CI), not just documented, because three
agents and later humans will write recording code (AUD-01…AUD-08) and plugins can add permissions
silently through the Android manifest merger.

This is engineering guidance, not legal advice; recording-consent laws vary by jurisdiction.

## Options considered

### Call detection
1. **iOS `CXCallObserver` + Android `AudioManager` mode (chosen).** No permission on either platform;
   `CXCallObserver` covers cellular and every CallKit VoIP app; Android audio mode is set by Telecom
   for cellular calls and by VoIP apps (`MODE_IN_COMMUNICATION`) that use the platform audio stack.
2. `TelephonyManager` / `PhoneStateListener` / `TelephonyCallback` — needs `READ_PHONE_STATE`
   (forbidden by this policy, and a Play-policy/store-review red flag); misses VoIP.
3. Only reacting to audio-session interruptions / `isClientSilenced` — too late (fires after the
   call already took the mic) and not available before start. Kept as *additional* signals.

### Platform channel
1. **Plain `MethodChannel` + `EventChannel` (chosen).** Two messages (`isInCall`, an event stream),
   no new dependency, no generated code, trivially mockable in tests.
2. Pigeon (`vv-flutter-architecture` default) — typed, but adds a dev dependency and codegen for a
   two-call API. Revisit if CallGuard grows (e.g. when AUD-04/05 move it into the recording service).

### CI guard
1. **Python checker (`tools/ci/check_recording_policy.py`) behind `check_recording_policy.sh` (chosen).**
   Parses manifests as XML (attributes on any line, `tools:node="remove"` understood) and plists with
   `plistlib`; regex rules for sources.
2. Pure `grep` — cannot tell `tools:node="remove"` from a real permission, and multi-line XML
   elements make it brittle.

## Decision

### 1. Standard OS microphone APIs only
Capture exclusively via the `record` package → iOS `AVAudioSession`/`AVAudioEngine`, Android
`AudioRecord` with `AudioSource.MIC` or `VOICE_RECOGNITION` (`AndroidAudioSource.mic` /
`.voiceRecognition`). Implemented by AUD-01 behind `CaptureBackend`
(`app/lib/features/recording/domain/capture_backend.dart`).

### 2. Forbidden — enforced by `tools/ci/check_recording_policy.sh`
| Where | Forbidden |
|---|---|
| Android manifests (source **and merged**) | permissions `READ_PHONE_STATE`, `READ_PRECISE_PHONE_STATE`, `READ_PHONE_NUMBERS`, `READ_CALL_LOG`, `WRITE_CALL_LOG`, `PROCESS_OUTGOING_CALLS`, `ANSWER_PHONE_CALLS`, `CALL_PHONE`, `MODIFY_PHONE_STATE`, `MANAGE_OWN_CALLS`, `USE_SIP`, `CAPTURE_AUDIO_OUTPUT`, `CAPTURE_MEDIA_OUTPUT`, `CAPTURE_VOICE_COMMUNICATION_OUTPUT`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, `FOREGROUND_SERVICE_PHONE_CALL`, `BIND_ACCESSIBILITY_SERVICE`, `BIND_INCALL_SERVICE`, `BIND_SCREENING_SERVICE`, `BIND_CALL_REDIRECTION_SERVICE`, `BIND_TELECOM_CONNECTION_SERVICE`, `SYSTEM_ALERT_WINDOW`; components guarded by those permissions; `foregroundServiceType` `mediaProjection`/`phoneCall`; accessibility/telecom service intent actions |
| `Info.plist` | `UIBackgroundModes` → `voip` |
| `*.entitlements` | any key/value mentioning VoIP, PushKit or CallKit |
| Dart/Kotlin/Java/Swift/ObjC (first-party: `app/lib`, `app/android/app/src`, `app/ios/Runner`, `packages/*/{lib,android/src,ios/Classes}`) | call audio sources (`VOICE_CALL`, `VOICE_UPLINK`, `VOICE_DOWNLINK`, `VOICE_COMMUNICATION`, `REMOTE_SUBMIX`); `AndroidAudioSource.*` other than `mic`/`voiceRecognition`; `AudioPlaybackCaptureConfiguration`, `MediaProjection*`, ReplayKit (`RPScreenRecorder`, `RPBroadcast*`); `AccessibilityService`; `TelephonyManager`, `PhoneStateListener`, `TelephonyCallback`, `TelecomManager`, `InCallService`, `CallScreeningService`, `CallRedirectionService`, `ConnectionService`; any forbidden permission name; `Permission.phone` / `Permission.systemAlertWindow` (permission_handler); `CXProvider*`, `CXCallController`, `CXTransaction`, `CXStartCallAction`, `CXAnswerCallAction`, `PKPushRegistry*`, `PushKit`; `mixWithOthers`; `voiceChat`/`videoChat` session modes; writing the Android audio mode (`setMode(`, `.mode =`) |

`CXCallObserver` (and `import CallKit` for it) and *reading* `AudioManager.mode` are allowed.
There is deliberately **no inline exemption marker**: a legitimate need is an ADR change. Removing a
permission a plugin adds (`<uses-permission … tools:node="remove"/>`) is allowed — that is the fix.

CI wiring (`.github/workflows/ci.yml`): the `static` job runs the script on sources, source
manifests, plists and entitlements (`run_slot.sh check_recording_policy.sh SEC-09`); the `android`
job re-runs it with `--require-merged-manifest` right after `build_android.sh`, so third-party
plugins and manifest-merger-implied permissions are covered and a moved AGP output path fails
loudly instead of skipping. Merged manifest paths verified for AGP 8.x
(`app/build/app/intermediates/merged_manifest/<variant>/process<Variant>Manifest/AndroidManifest.xml`).
Proof the guard fails: `tools/ci/tests/test_recording_policy.py` builds fixture trees (no bad
manifest is committed).

Known limit: third-party plugin *native source* (in the pub cache) is not scanned — e.g. `record`
itself contains a mapping for every Android audio source. Our Dart call site chooses the source, and
is scanned; plugin code is covered by the dependency review (`vv-privacy-security`).

### 3. CallGuard
Interface `CallGuard` (`app/lib/core/platform/call_guard.dart`): `isInCall()` + `events`
(`callActive`, `callEnded`, `interruptionBegan`, `interruptionEnded`, `captureSilenced`,
`captureUnsilenced`, each with the platform timestamp). Implementation
`MethodChannelCallGuard` (`features/recording/data/`) on channels `vaultvoice/call_guard` and
`vaultvoice/call_guard/events`.
- **iOS** (`app/ios/Runner/CallGuardPlugin.swift`): `CXCallObserver`; any call with
  `hasEnded == false` ⇒ in call (ringing/dialing/connected/held). `AVAudioSession`
  interruption-began ⇒ `interruptionBegan`; ended is reported but `.shouldResume` is never read.
- **Android** (`app/android/.../CallGuardPlugin.kt`): `AudioManager.getMode()` ∈ {`MODE_RINGTONE`,
  `MODE_IN_CALL`, `MODE_IN_COMMUNICATION`, `MODE_CALL_SCREENING`, `MODE_CALL_REDIRECT`,
  `MODE_COMMUNICATION_REDIRECT`} ⇒ in call; `addOnModeChangedListener` on API 31+, 500 ms polling
  on API 26–30 while Dart listens; `AudioRecordingCallback` → `isClientSilenced()` (API 29+) ⇒
  `captureSilenced`. No phone-state permission. The plugin only reads the mode.
- **macOS** (`app/macos/Runner/MacHostChannels.swift`, `CallGuardHost`): a Mac has no cellular
  call, and this policy forbids CallKit, VoIP modes, Continuity/FaceTime attachment and every
  call permission. The host therefore answers `isInCall` → `false` (honest: it cannot see calls and
  does not try) and its event stream never emits; it uses no call API at all.
  `check_recording_policy.py` fails any CallKit/CXCall*/CoreTelephony/FaceTime reference under
  `app/macos` and `packages/*/macos`. The user is still protected by the mic-only entitlement,
  the explicit start tap, the system menu-bar mic indicator and AUD-09's input-device checks.
  The channel exists so the Dart guard gets a definite answer instead of a
  `MissingPluginException` (FND-09 bug: Record screen said "the call state could not be checked").
- **Fail closed:** on iOS and Android, if the call state cannot be determined (`Err`), start and resume are refused.

### 4. `RecordingController.start(StartSource)` — the only way to open the mic
`app/lib/features/recording/domain/recording_controller.dart`:
- `StartSource` = {`inAppButton`, `homeScreenWidget`, `androidQuickSettingsTile`, `iosControl`} —
  user taps only; the enum is the allowlist (`allowedStartSources`, pinned by a test). There is no
  way to express a scheduled/automated, voice-activated, push/MDM/remote, app-launch or
  background/headless start. Widgets, Lock Screen/Control Center controls, the Android widget
  and the Quick Settings tile are *navigate-only* (ADR-QCP-01, amended 2026-10-17): they open the app on
  the Record screen and never call `RecordingController.start`. The recording starts only with the in-app
  Record tap (`StartSource.inAppButton`) after the same first-run acknowledgement, profile consent and
  microphone priming as any in-app start. No App Intent that opens or starts recording is discoverable by
  Siri, Spotlight or Shortcuts, and no Shortcuts action or automation for recording is provided.
  `StartSource.homeScreenWidget`, `.androidQuickSettingsTile` and `.iosControl` remain allowlisted but are
  unused until a later amendment makes an entry point start-now.
- Refuses when: source not allowlisted, app not in the foreground (`AppLifecycleState.resumed`
  only; unknown = not foreground), a call rings/is active, the guard is unavailable, wrong phase.
- **No pre-capture:** `CaptureBackend.openMicrophone()` is called only after all checks pass; the
  controller does nothing (no guard query, no listener, no mic) before the tap.
- **Call while recording:** the blocking event suspends capture synchronously in the event handler
  (`CaptureBackend.suspend(gap: callInterruption, discardFrom: <event time>)`): the backend drops
  audio captured at/after the call event, finalizes the chunk and writes a `call_interruption` gap.
  A call that rings while the mic is opening is applied right after it opens.
- **No auto-resume:** `callEnded`/`interruptionEnded`/`captureUnsilenced` are ignored. Only
  `resume(ResumeSource)` (`inAppButton`, `recordingNotification`) reopens the mic, and it re-checks
  the call state.
- **Long sessions** (`RecordingLimits`): auto-stop at max duration (default 4 h, configurable,
  clamped to 8 h; paused time excluded), "Still recording (1h 00m)" reminder every 60 min while
  backgrounded (`RecordingReminderSink`, rendered by AUD-04/05), auto-stop after configured
  continuous silence (`reportContinuousSilence`, fed by AUD-03).

Only `RecordingController` may call `openMicrophone`/`resumeCapture` (or a recorder's `start`) —
enforced by `app/test/unit/recording/recording_policy_source_test.dart`.

### 5. Always visible, permission, imports, copy (owned by later tasks)
OS indicators + Android ongoing notification (AUD-05) + iOS Live Activity where supported (AUD-04; until AUD-13 ships this is satisfied by the OS microphone indicator plus the AUD-04 recording indicator, amended 2026-10-17);
no hidden/discreet mode, no option to suppress indicators. Mic permission just-in-time on the first
Record tap with a priming screen, never at launch, never worked around (APP-01/AUD-08). Imports
require the rights/consent attestation (AUD-06); no call-recorder marketing (SEC-06/REL-05). MDM
can only make recording stricter (LIC-04).

## Review checklist (every PR touching recording, paste into the PR)
- [ ] `tools/ci/check_recording_policy.sh` passes (static + merged manifest).
- [ ] Every new mic-opening path goes through `RecordingController.start/resume`; no new
      `StartSource`/`ResumeSource` value without an ADR amendment.
- [ ] No start from `initState`, lifecycle callbacks, timers, streams, notifications other than the
      recording notification's Resume, deep links, intents, App Intents, push, MDM or VAD.
- [ ] Nothing opens the microphone before the tap (no input-node pre-warming / early `startRecording`).
- [ ] Calls/interruptions suspend capture; nothing resumes without a user tap (also not `.shouldResume`).
- [ ] No setting, flavor or managed-config key disables CallGuard, indicators or consent.

## Legal review
**Status: requested — awaiting product/legal (owner: product). SEC-09 stays in `review` until confirmed.**
Wording to approve (drafts; English only, l10n later):
1. Start refused: "Recording is unavailable during calls."
2. Paused by a call: "Recording paused because a call started. Audio from the call was not recorded. Tap Resume to continue."
3. Import attestation (AUD-06): "I have the right to process this recording, and everyone recorded consented."
4. Long-session reminder: "Still recording (1h 00m)".
5. Mic-permission priming (APP-01): "VaultVoice needs the microphone to record notes you start. Audio is processed on this device and never uploaded."
Questions for legal: is the import attestation sufficient for all-party-consent jurisdictions; should
the "call not recorded" note name the reason; may reminder frequency be user-configurable.

## Consequences
- Positive: call capture is impossible through first-party code and blocked at the manifest level
  for plugins; start sources are a closed, tested set; behaviour is unit-tested with fakes.
- Negative / risks:
  - The app cannot record speakerphone/VoIP calls on the same phone (intentional).
  - VoIP apps that do not use CallKit (iOS) or do not set `MODE_IN_COMMUNICATION` (Android) are
    detected only through `interruptionBegan`/`captureSilenced` — to be measured in the device test.
  - Fail-closed guard: a broken platform channel blocks recording entirely (preferred over the
    opposite failure).
  - Plugin native sources are not scanned (see §2).
- Follow-ups: AUD-01 implements `CaptureBackend` (and reconciles with `core/platform/AudioRecorder`);
  AUD-04/05 move CallGuard observation into the background-recording paths and render the reminder;
  AUD-08 recording UI strings; REL-01 runs the guard in the release pipeline.

## PRODUCT-DECISIONs (conservative defaults, need confirmation)
- Fail closed when call state is unknown.
- Max duration counts recorded time (pauses excluded); floor 1 min, ceiling 8 h.
- Reminder only while backgrounded, not while paused.
- `mixWithOthers` banned everywhere in first-party code (not only while recording).
- Resume from the recording notification is allowed while backgrounded (it is a tap); in-app resume
  requires the foreground.
