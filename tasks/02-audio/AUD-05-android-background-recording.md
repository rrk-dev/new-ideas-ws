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

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (0 changed) · analyze ✅ (no issues) · tests ✅ (785 passed, 24 skipped, coverage 93.2% of 4708 gated lines, min 80%) · native smoke ✅ (host ctest 9 passed / 14 skipped / 0 failed, includes `vv_crash`) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51, success, `67b6fcf`) and https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574 (run 50, success)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[AUD-05/AC1]`. With the rig backgrounded, 60 minutes yields 12 contiguous 5-minute chunks, no gap markers, indicator stays visible until stop. Device 60-minute screen-off rows (Pixel, Samsung) are blank.
  - AC2: ✅ re-ran `[AUD-05/AC2]`. Notification Pause/Resume/Stop drive the controller while backgrounded; duration is the recorded 3 s, not the wall clock. Device lock-screen action row is blank.
  - AC3: ✅ re-ran `[AUD-05/AC3]`. Background call keeps samples only up to the event minus the safety margin, Resume is refused while the call is active, hang-up does not open the mic, and a later tap does. Device cellular/VoIP row is blank.
  - AC4: ✅ re-ran `[AUD-05/AC4]` (manifest + `RecordingService.kt`) and artifact `docs/play-console/fgs-declaration.md` exists. Asserts one `microphone` FGS (`exported=false`, `START_NOT_STICKY`), `RECORD_AUDIO` / `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MICROPHONE` / `POST_NOTIFICATIONS`, and no `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. The MDL-02 `dataSync` service is the only other FGS type. Checked it fails when the recording service type is changed to `mediaPlayback`. Play Console submission row is blank.
- **Adversarial checks:** Resume from the notification uses `ResumeSource.recordingNotification` and is re-checked against CallGuard. Service returns `START_NOT_STICKY` (no system restart after kill). Notification actions are pause/resume/stop only — no start. Battery guidance never requests the exemption. `check_recording_policy.sh` and `check_egress.sh` OK. No phone-state permission in the manifest. `tasks.py verify AUD-05 --run` short-circuits on pending evidence; tagged tests passed in the full suite.
- **Skill/rule compliance:** FGS type `microphone`, started only while the activity is visible (comments + ADR-AUD-05). Capture remains in the Flutter engine. OEM guidance is in-app text, not a permission. Live recording policy (user tap, no auto-resume) is unchanged.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/AUD-05.md has no PASS result with a date; AC2: still pending (⏳) — cannot be done; AC2: device row in docs/test-plans/device/AUD-05.md has no PASS result with a date; AC3: still pending (⏳) — cannot be done; AC3: device row in docs/test-plans/device/AUD-05.md has no PASS result with a date; AC4: still pending (⏳) — cannot be done; AC4: device row in docs/test-plans/device/AUD-05.md has no PASS result with a date; dependency AUD-01 is not done; dependency SEC-09 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
