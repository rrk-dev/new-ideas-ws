# ADR-AUD-04 — iOS background recording, interruptions and route changes

- **Status:** Accepted (engineering); Live Activity deferred (AUD-10, proposed); device rows pending
  (docs/test-plans/device/AUD-04.md)
- **Date:** 2026-10-13
- **Task:** AUD-04
- **Deciders:** Claude Code (implementer); pending independent verifier
- **Builds on:** ADR-AUD-01-recording-service, ADR-SEC-09-recording-policy, ADR-AUD-05 (indicator channel)
- **Verified against:** AVFAudio (`AVAudioSession` route-change / media-services-reset
  notifications, `AVAudioEngineConfigurationChange`), UserNotifications; Swift sources type-checked
  locally with `swiftc -target arm64-apple-ios16.0-macabi` (Swift 6.4, macOS 27 SDK with
  iOSSupport) against a stub `Flutter` module — the full iOS build runs in CI only.

## Context
iOS keeps recording in the background only with `UIBackgroundModes: audio` and an active
recording session; the recording must be started in the foreground (SEC-09 already refuses
otherwise). The `record` plugin (record_ios 2.1.1) captures with `AVAudioEngine` and does **not**
handle `AVAudioEngineConfigurationChange` or media-services resets: when AirPods/a wired headset
connect or the route's format changes, the engine stops and the stream silently ends.

## Decision
1. **Background mode:** `UIBackgroundModes = [audio]` (never `voip` — CI guard). No silent-audio
   tricks; recording continues only because the user's recording session is active.
2. **Interruptions & calls:** unchanged SEC-09 path — `CallGuardPlugin` (`CXCallObserver` +
   `AVAudioSession.interruptionNotification` → `callActive` / `interruptionBegan`) suspends capture
   in the event handler and writes the gap; `record` itself is configured with
   `AudioInterruptionMode.pause` (no auto-resume). `interruptionEnded` / `.shouldResume` (and the
   iOS 27 resumption recommendation) are never acted on: the only way back is the Resume tap.
3. **Route / engine changes:** new `AudioSessionPlugin.swift` (event channel
   `vaultvoice/audio_session/events`, observers only while a recording is open) reports
   `routeChanged` (logged; device kinds only), `engineConfigurationChanged` and
   `mediaServicesReset`. The latter two raise `CaptureNotice.inputRestartRequired`;
   `RecordingController._restartInput` then — **only while the recording is running, never while
   paused** — suspends the input (`route_change` gap marker), **re-checks CallGuard and fails
   closed** (call or unknown state ⇒ pause, user must tap Resume) and reopens the input into a new
   chunk. This is not a resume: the recording never left `recording`, and the reopen is inside the
   controller (the only code allowed to open the microphone). The reopen gap is excluded from the
   timer.
4. **Visibility:** while recording in the background iOS shows its own microphone indicator
   (status-bar recording pill / orange dot, Control Center attribution) — there is no hidden mode.
   The SEC-09 60-min "Still recording" reminder is a local notification
   (`RecordingIndicatorPlugin.swift`; authorization requested once at the first recording — no
   push, no network).
5. **Live Activity: deferred → AUD-10 (proposed).** It needs a new WidgetKit/ActivityKit extension
   target (pbxproj target, embed phase, `NSSupportsLiveActivities`, signing/App Group), which cannot
   be created or validated without Xcode in this environment; a hand-edited target that might break
   the Runner build is a worse trade than the OS indicator in the meantime.
6. Audio-session category/mode stay as configured by `record` (`.playAndRecord`,
   `defaultToSpeaker` + `allowBluetooth`, mode `.default`); AUD-02 measures `.measurement` /
   `.spokenAudio`.

## Consequences
- Positive: AirPods connect/disconnect and media-services resets no longer end a recording; no
  call path can reopen the microphone.
- Negative / risks: each restart loses the ~100–300 ms the engine needs to restart (marked as a
  `route_change` gap); restart behaviour must be measured on devices (rows in AUD-04.md).
- Found while type-checking: `CallGuardPlugin.swift` (SEC-09) inferred `() -> Void?` for the
  closure passed to `DispatchQueue.main.async`, which does not compile; fixed with an explicit
  `() -> Void` annotation (note added to SEC-09 Follow-ups).
