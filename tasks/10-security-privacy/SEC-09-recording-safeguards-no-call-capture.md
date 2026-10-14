# SEC-09 — Recording Safeguards: User-Started Only, Never Record Calls

**Workstream:** Security & Privacy | **Phase:** 1 | **Size:** M | **Depends on:** FND-02 | **Source:** Product/legal requirement (user directive): use only the standard OS microphone APIs, never record phone/VoIP calls, never record without the user's explicit action
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-privacy-security, vv-ci-release, vv-testing

## Goal
VaultVoice can only ever capture audio that the device user deliberately started recording, through the
standard, permission-gated OS microphone APIs — and it never captures telephone or VoIP call audio.

## Scope
- [x] **Standard APIs only:** microphone capture exclusively via the `record` package → iOS `AVAudioSession`/AVAudioEngine and Android `AudioRecord` with `AudioSource.MIC` or `VOICE_RECOGNITION`. Document as ADR (`Recording policy`).
- [x] **Forbidden (must never appear):** Android audio sources `VOICE_CALL`, `VOICE_UPLINK`, `VOICE_DOWNLINK`, `VOICE_COMMUNICATION`, `REMOTE_SUBMIX`; `AudioPlaybackCaptureConfiguration` / MediaProjection audio capture; Accessibility Services; permissions `READ_PHONE_STATE`, `READ_CALL_LOG`, `PROCESS_OUTGOING_CALLS`, `ANSWER_PHONE_CALLS`, `CAPTURE_AUDIO_OUTPUT`, `MANAGE_OWN_CALLS`, `BIND_ACCESSIBILITY_SERVICE`, `SYSTEM_ALERT_WINDOW`; iOS CallKit providers, `voip` background mode, `AVAudioSession` option `.mixWithOthers` while recording.
- [x] Build `CallGuard`, `RecordingController.start(StartSource)` (allowed sources enum) and the recording-policy ADR (`ADR-SEC-09-recording-policy`).
- [x] **CI guard** `tools/ci/check_recording_policy.sh`: fails the build if any forbidden permission/API/source/background mode appears in the merged Android manifest, Kotlin/Java/Swift/Dart sources, `Info.plist` or entitlements (run on the merged manifest from the build, so third-party plugins are covered too).
- [x] **Active-call guard** (`CallGuard` service, both platforms):
  - iOS: `CXCallObserver` (no permission needed) — any call with `hasEnded == false` ⇒ in call. Covers cellular and CallKit VoIP apps. Also treat `AVAudioSession` interruption-began as a call-like event.
  - Android: `AudioManager.getMode()` ∈ {`MODE_RINGTONE`, `MODE_IN_CALL`, `MODE_IN_COMMUNICATION`, `MODE_CALL_SCREENING`, `MODE_CALL_REDIRECT`, `MODE_COMMUNICATION_REDIRECT`} ⇒ in call. Use `addOnModeChangedListener` (API 31+); poll every 500 ms while recording on API 26–30. Also `AudioRecordingCallback` → `isClientSilenced()` (API 29+) ⇒ pause. Do NOT request `READ_PHONE_STATE`.
  - Refuse to **start** recording while in a call ("Recording is unavailable during calls").
  - If a call starts (incoming ringing included) while recording ⇒ stop capture **immediately** (within 500 ms), discard any buffered audio captured after the call-start event, finalize the current chunk, record a gap marker `call_interruption`.
  - After the call ends the recording stays **paused**. It resumes **only** when the user taps Resume. Never auto-resume.
- [x] **Explicit user start only:** a recording can start only from a direct user tap in the app UI, the app's widget, or the Android quick-settings tile / iOS Control (each is a deliberate tap). Forbidden: scheduled/automated starts (Shortcuts *automations*, alarms, timers, geofences), voice-activated start ("start when speech detected"), remote/MDM/push-triggered starts, starting at app launch, starting from a background/headless context.
- [x] **No pre-capture:** the microphone input is not opened before the user's tap (no pre-warming the input node / `AudioRecord.startRecording()` early; preparing non-mic resources is fine).
- [~] deferred → AUD-04, AUD-05, AUD-08 (notification / Live Activity / UI are built there; rule recorded in ADR-SEC-09 §5) — **Always visible:** OS indicators (iOS orange dot, Android privacy indicator) plus our own: Android ongoing notification (non-dismissible while recording), iOS Live Activity / lock-screen indicator when supported. No hidden or "discreet" recording mode, no disguised UI, no option to suppress indicators.
- [x] **Long-session safeguards:** (logic in `RecordingController`/`RecordingLimits`; OS notification rendering of the reminder → AUD-04/AUD-05) "Still recording (1h 00m)" reminder every 60 min while the app is backgrounded; automatic stop at a maximum duration (default 4 h, user-configurable up to 8 h) and after N minutes of continuous silence (AUD-03 setting).
- [~] deferred → APP-01 (priming + just-in-time request; rule in ADR-SEC-09 §5) — **Microphone permission:** requested just-in-time on the first Record tap (with a priming screen explaining local-only processing), never at launch; if denied, show how to enable it in Settings — never work around it.
- [~] deferred → AUD-06 (attestation draft wording in ADR-SEC-09 → Legal review) — **Imported audio** (AUD-06): user must confirm "I have the right to process this recording and everyone recorded consented" before processing; the app never markets or offers importing from call-recorder apps.
- [~] deferred → SEC-06, REL-05 — Store listing / in-app copy must never claim call recording (SEC-06, REL-05).

## Acceptance Criteria
- `check_recording_policy.sh` runs in CI and fails on a test branch that adds `READ_PHONE_STATE` or `AudioSource.VOICE_CALL` (demonstrated).
- `CallGuard` device test via a debug screen (iOS + Android, foreground): in-call state is reported ≤ 500 ms after ringing starts for a cellular call and a VoIP call (WhatsApp/Teams/FaceTime), and clears after hang-up; `RecordingController.start` is refused while in call.
- Capture-level call tests (no call audio in the file, no auto-resume) are acceptance criteria of AUD-01 (foreground), AUD-04/AUD-05 (background/locked) and QA-04 — this task provides the guard they use.
- No code path starts recording without a user tap (code review checklist + unit tests on `RecordingController` start sources).
- Reminder notification and max-duration auto-stop verified on both platforms.
- Legal review requested for the consent/attestation wording (owner: product) — status `review` until confirmed.

## Notes
- Consequence: the app cannot be used to record speakerphone/VoIP calls on the same phone. This is intentional.
- This is engineering guidance, not legal advice; recording-consent laws vary (one-party vs all-party consent jurisdictions). Product/legal must approve copy and defaults.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/SEC-09-recording-safeguards · **Date:** 2026-10-12
- **Summary:** Recording policy ADR (`docs/adr/ADR-SEC-09-recording-policy.md`, incl. review checklist and legal-review request).
  `CallGuard` interface (`app/lib/core/platform/call_guard.dart`) + `MethodChannelCallGuard`
  (`app/lib/features/recording/data/`) + platform code: iOS `app/ios/Runner/CallGuardPlugin.swift` (`CXCallObserver`,
  audio-session interruptions; registered in `AppDelegate.swift`, added to the Xcode project) and Android
  `app/android/app/src/main/kotlin/com/vaultvoice/vaultvoice/CallGuardPlugin.kt` (`AudioManager` mode via
  `addOnModeChangedListener` on API 31+ / 500 ms polling on 26–30, `AudioRecordingCallback.isClientSilenced`; registered in
  `MainActivity`). `RecordingController.start(StartSource)` / `resume(ResumeSource)` with allowlisted user-tap enums,
  foreground-only, fail-closed call check, synchronous suspend with `discardFrom` + `call_interruption` gap, no auto-resume,
  max-duration (4 h default, ≤ 8 h) and silence auto-stop, 60-min background reminder (`RecordingLimits`) — driving a
  `CaptureBackend` interface that AUD-01 implements (fakes: `app/test/fakes/fake_call_guard.dart`,
  `fake_capture_backend.dart`). Dev-flavor CallGuard debug screen (Record tab app bar). CI guard
  `tools/ci/check_recording_policy.sh` (→ `check_recording_policy.py`: XML/plist parsing + source rules) runs in the `static`
  slot and, with `--require-merged-manifest`, in the `android` job after the APK build. New dev dependency `fake_async`
  1.3.3 (Dart team, BSD-3, test-only, already transitive via flutter_test).
  Not done / unverified: Kotlin/Swift never compiled locally (no SDK/Xcode) — compiled by the CI `android`/`ios` jobs;
  the workflow has not yet run on this branch (no PR opened).
- **Acceptance evidence:**
  - AC1: ✅ test: [SEC-09/AC1]; ci: static job slot + android job `check_recording_policy.sh --require-merged-manifest` (first PR run)
  - AC2: ⏳ test: [SEC-09/AC2]; device: docs/test-plans/device/SEC-09.md
  - AC3: ✅ test: [SEC-09/AC3]; artifact: docs/adr/ADR-SEC-09-recording-policy.md
  - AC4: ✅ test: [SEC-09/AC4]; artifact: docs/adr/ADR-SEC-09-recording-policy.md
  - AC5: ⏳ test: [SEC-09/AC5]; device: docs/test-plans/device/SEC-09.md
  - AC6: ⏳ artifact: docs/adr/ADR-SEC-09-recording-policy.md#legal-review
- **Decisions:** ADR-SEC-09-recording-policy (method/event channel instead of Pigeon; permissionless call detection; Python checker). PRODUCT-DECISIONs listed at the end of the ADR (fail closed, pauses excluded from max duration, reminder only while backgrounded, `mixWithOthers` banned everywhere, notification Resume allowed in background).
- **Follow-ups:** AUD-01 implements `CaptureBackend` (reconcile with `core/platform/AudioRecorder`); AUD-04/AUD-05 keep CallGuard active in background and render the reminder notification; AUD-08 recording UI strings; REL-01 runs the guard in the release pipeline; legal/product sign-off on the wording in the ADR; `tasks.py` runs pytest with `-k <ID>_ACn`, which never matches `test_<ID_with_underscores>_ACn` names (SEC-09 tests carry the tag as a parametrize id as a workaround — FND-03 owner to fix).

## Follow-ups
- From AUD-04 (Claude Code, 2026-10-13): `app/ios/Runner/CallGuardPlugin.swift` did not
  type-check — `let send = { [weak self] in self?.sink?(…) }` is inferred as `() -> Void?`, which
  `DispatchQueue.main.async(execute:)` rejects. Fixed on `task/AUD-04-ios-background-recording`
  with an explicit `let send: () -> Void` (no behaviour change); merge that branch or cherry-pick
  the one-line fix.
