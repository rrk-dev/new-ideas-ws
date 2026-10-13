# AUD-05 — Android Background Recording (Foreground Service)

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** AUD-01, SEC-09 | **Source:** §3.1.1
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-privacy-security, vv-testing

## Goal
Recording survives backgrounding, screen-off and aggressive OEM battery managers.

## Scope
- [x] Foreground service with `foregroundServiceType="microphone"` (Android 14+ requirement); persistent notification with pause/stop actions. — `RecordingService.kt` + `RecordingIndicatorPlugin.kt`; Dart `RecordingIndicatorBinding` (Pause/Resume/Stop → `RecordingController`).
- [x] Permissions: `RECORD_AUDIO`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS` (13+). — plus `FOREGROUND_SERVICE`; POST_NOTIFICATIONS requested once on the first start.
- [x] Call handling via SEC-09 `CallGuard` (`AudioManager` mode: ringtone / in-call / in-communication) — stop capture immediately, mark gap, stay paused until the user taps Resume (**never auto-resume**); refuse to start during a call. Do not request `READ_PHONE_STATE`.
- [x] Notification is ongoing/non-dismissible while recording; the only audio source used is `MIC`/`VOICE_RECOGNITION`. — ongoing + `FOREGROUND_SERVICE_IMMEDIATE`; on Android 14+ a swiped-away notification is re-posted; source per AUD-01 `buildRecordConfig`.
- [x] Battery-optimization guidance for Samsung/Xiaomi/OnePlus (deep link to settings, in-app explanation). — `BatteryGuidance` on the Record screen; never requests the exemption permission.
- [x] Handle microphone being captured by another app (concurrent capture rules). — silenced client (`isClientSilenced`) / plugin pause / stream failure → pause that only a tap ends (SEC-09 + AUD-01 notices).

## Acceptance Criteria
- 60-min screen-off recording on Pixel and Samsung test devices with no gaps.
- Notification actions pause/stop correctly.
- Incoming cellular and VoIP call during recording: no call audio captured; recording remains paused after hang-up until Resume.
- Passes Play policy for foreground service type declaration.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/AUD-05-android-background-recording · **Date:** 2026-10-13
- **Summary:** `RecordingService` (FGS type `microphone`, `START_NOT_STICKY`, started only right
  after the user's tap while the activity is visible) keeps the process and while-in-use microphone
  access alive; capture stays in the Flutter engine (AUD-01). Ongoing notification with chronometer,
  Pause/Resume/Stop (→ `RecordingController` via `RecordingIndicatorBinding`, Resume =
  `ResumeSource.recordingNotification`, re-checked against CallGuard), call-pause copy, re-post when
  swiped away, "Still recording" reminder channel. `MainActivity` retains the Flutter engine while
  the service runs (survives swipe-away). `BatteryGuidance` for aggressive OEMs. Play declaration
  draft. Key files: `app/android/app/src/main/kotlin/com/vaultvoice/vaultvoice/{RecordingService,
  RecordingIndicatorPlugin,RetainedEngine,MainActivity}.kt`, `app/lib/features/recording/
  {domain/recording_indicator.dart,data/method_channel_recording_indicator.dart,presentation/
  {recording_indicator_binding,battery_guidance}.dart}`, `docs/adr/ADR-AUD-05-android-background-recording.md`.
- **Acceptance evidence:**
  - AC1: ⏳ test: [AUD-05/AC1]; device: docs/test-plans/device/AUD-05.md
  - AC2: ⏳ test: [AUD-05/AC2]; device: docs/test-plans/device/AUD-05.md
  - AC3: ⏳ test: [AUD-05/AC3]; device: docs/test-plans/device/AUD-05.md
  - AC4: ⏳ test: [AUD-05/AC4]; artifact: docs/play-console/fgs-declaration.md; device: docs/test-plans/device/AUD-05.md
- **Decisions:** ADR-AUD-05-android-background-recording. PRODUCT-DECISIONs: recording is not
  blocked when notification permission is denied (OS mic indicator remains); notification visible
  on the lock screen (state only); notification copy = SEC-09 drafts (pending legal review); OEM
  guidance list (Samsung, Xiaomi/Redmi/POCO, OnePlus/OPPO/realme, vivo, Huawei/Honor).
- **Stacking:** branched from task/AUD-07-recording-crash-recovery → task/AUD-01-recording-service
  → origin/main. AUD-04 is stacked on this branch. Kotlin is compile-checked only by CI.
- **Follow-ups:** none.
