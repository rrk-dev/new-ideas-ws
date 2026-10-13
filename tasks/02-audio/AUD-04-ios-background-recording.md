# AUD-04 — iOS Background Recording & Interruption Handling

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** AUD-01, SEC-09 | **Source:** §3.1.1 (Background Audio Capture)
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-testing

## Goal
Recording continues with the app backgrounded or the device locked, and recovers gracefully from interruptions.

## Scope
- [x] Enable `audio` UIBackgroundMode; `NSMicrophoneUsageDescription` copy. — Info.plist (`audio` only; copy added in AUD-01).
- [x] Handle `AVAudioSession.interruptionNotification` (phone calls, FaceTime/VoIP, Siri, alarms) — pause immediately and mark gap. **Never auto-resume**, even when the system reports `.shouldResume`; the user must tap Resume.
- [x] Use SEC-09 `CallGuard` (`CXCallObserver`) so a ringing/active call stops capture even if no interruption arrives; refuse to start while a call is active.
- [x] Handle route changes (AirPods connect/disconnect, wired headset). — `AudioSessionPlugin.swift` → `inputRestartRequired` → `RecordingController._restartInput` (call re-check, fail closed, never while paused).
- [x] Handle media services reset. — same restart path into a new chunk.
- [~] deferred → AUD-10 Live Activity / lock-screen indicator showing recording state (required where supported — SEC-09 visibility rule). — reason: needs a new WidgetKit/ActivityKit extension target that cannot be created or validated without Xcode here; meanwhile the OS microphone/recording indicator is always shown for background recording and the 60-min reminder is a local notification (ADR-AUD-04).

## Acceptance Criteria
- 60-min locked-screen recording completes without loss.
- Incoming call during recording: capture stops ≤ 500 ms after ringing starts, no call audio in the file, gap marked in metadata, and the recording stays paused after the call until the user taps Resume.
- Bluetooth headset connect mid-recording does not stop recording.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/AUD-04-ios-background-recording · **Date:** 2026-10-13
- **Summary:** `UIBackgroundModes: audio`; interruptions/calls via SEC-09 CallGuard (suspend in the
  event handler, gap marker, never resumed by `interruptionEnded`/`.shouldResume`).
  `AudioSessionPlugin.swift` reports route changes, `AVAudioEngineConfigurationChange` and media-
  services resets while a recording is open; the latter two make `RecordingController` reopen the
  `record` input (record_ios does not handle them) — only while recording, after a CallGuard
  re-check that fails closed, with a `route_change` gap marker and the reopen gap excluded from the
  timer. `RecordingIndicatorPlugin.swift`: SEC-09 "Still recording" reminder as a local
  notification. Swift type-checked locally (Catalyst SDK + stub Flutter module); this also found a
  compile error in SEC-09's `CallGuardPlugin.swift` (closure inferred `() -> Void?`), fixed with a
  one-line type annotation. Key files: `app/ios/Runner/{AudioSessionPlugin,RecordingIndicatorPlugin}
  .swift`, `app/lib/features/recording/domain/{audio_session_monitor,recording_controller}.dart`,
  `app/lib/features/recording/data/{method_channel_audio_session_monitor,record_capture_backend}.dart`,
  `docs/adr/ADR-AUD-04-ios-background-recording.md`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [AUD-04/AC1]; device: docs/test-plans/device/AUD-04.md
  - AC2: ⏳ test: [AUD-04/AC2]; device: docs/test-plans/device/AUD-04.md
  - AC3: ⏳ test: [AUD-04/AC3]; device: docs/test-plans/device/AUD-04.md
- **Decisions:** ADR-AUD-04-ios-background-recording. PRODUCT-DECISIONs: the input is reopened
  automatically after a route/engine change while the recording runs (not a resume; fails closed
  on calls); notification authorization is requested at the first recording (for the reminder);
  Live Activity deferred.
- **Stacking:** branched from task/AUD-05-android-background-recording → task/AUD-07-recording-
  crash-recovery → task/AUD-01-recording-service → origin/main.
- **Follow-ups:** AUD-10 (proposed).

## Follow-ups
- **AUD-10 (proposed): iOS Live Activity for recording state** — WidgetKit/ActivityKit extension
  (`NSSupportsLiveActivities`, App Group for state), started from the in-app Record tap, showing
  recording/paused + timer, updated from `RecordingIndicatorBinding` via the existing
  `vaultvoice/recording_indicator` channel; buttons only open the app (no start from the Activity).
  Needs Xcode to create the target. Deferred from AUD-04 scope.
