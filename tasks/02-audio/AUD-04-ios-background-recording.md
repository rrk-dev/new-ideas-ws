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
- [~] deferred → AUD-13 Live Activity / lock-screen indicator showing recording state (required where supported — SEC-09 visibility rule). — reason: needs a new WidgetKit/ActivityKit extension target that cannot be created or validated without Xcode here; meanwhile the OS microphone/recording indicator is always shown for background recording and the 60-min reminder is a local notification (ADR-AUD-04).

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
- **Follow-ups:** AUD-13 (filed).

## Follow-ups
- **AUD-13 (filed, tasks/02-audio/AUD-13-ios-live-activity.md; was proposed as AUD-10): iOS Live Activity for recording state** — WidgetKit/ActivityKit extension
  (`NSSupportsLiveActivities`, App Group for state), started from the in-app Record tap, showing
  recording/paused + timer, updated from `RecordingIndicatorBinding` via the existing
  `vaultvoice/recording_indicator` channel; buttons only open the app (no start from the Activity).
  Needs Xcode to create the target. Deferred from AUD-04 scope.

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (0 changed) · analyze ✅ (no issues) · tests ✅ (785 passed, 24 skipped, coverage 93.2% of 4708 gated lines, min 80%) · native smoke ✅ (host ctest 9 passed / 14 skipped / 0 failed, includes `vv_crash`) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51, success, `67b6fcf`) and https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574 (run 50, success)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[AUD-04/AC1]`. Backgrounded rig records 60 minutes as 12 chunks, never enters `paused`, and the session observer is listening only while open. Locked-screen device row is blank (no Xcode).
  - AC2: ✅ re-ran `[AUD-04/AC2]`. Ringing pauses immediately, post-event audio is not kept (1750 ms of 2000), a `call_interruption` marker is written, and `interruptionEnded` plus `callEnded` leave the mic closed. Device call row is blank.
  - AC3: ✅ re-ran `[AUD-04/AC3]`. A plain route change does not reopen; an engine-configuration change reopens into a new chunk and the recording stays in `recording` with a `route_change` marker. Media-services reset continues in a second chunk. Checked it fails when `_restartInput` is replaced with `return`. Bluetooth device row is blank.
- **Adversarial checks:** Route/engine restart while `inCall` pauses instead of reopening (fail closed). A paused recording is not reopened by an engine change. Controller drops `callEnded` and `interruptionEnded` (`blocksCapture` is false), so `.shouldResume` cannot resume. `UIBackgroundModes` is `audio` only. CallKit is the SEC-09 observer, not a call provider. `tasks.py verify AUD-04 --run` short-circuits on pending evidence; tagged tests passed in the full suite.
- **Skill/rule compliance:** No auto-resume. Live Activity is `[~] deferred → AUD-13` with a reason (needs a WidgetKit target and Xcode). Input reopen is a route recovery, not a resume, and fails closed on calls (ADR-AUD-04).
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/AUD-04.md has no PASS result with a date; AC2: still pending (⏳) — cannot be done; AC2: device row in docs/test-plans/device/AUD-04.md has no PASS result with a date; AC3: still pending (⏳) — cannot be done; AC3: device row in docs/test-plans/device/AUD-04.md has no PASS result with a date; dependency AUD-01 is not done; dependency SEC-09 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
