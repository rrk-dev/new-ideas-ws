# QCP-03 — Android quick capture: home widget, Quick Settings tile, app shortcut

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** QCP-01, AUD-05, AUD-08, SEC-09 | **Source:** User decision 2026-10-16 (product Phase 2: one-tap capture)
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-flutter-architecture, vv-privacy-security, vv-testing

## Goal
On Android (API 26+, arm64-v8a), a user can open the app straight to the Record screen from a home-screen widget, the Quick Settings tile or a launcher shortcut. Entry points are navigate-only (ADR-QCP-01 Accepted 2026-10-17): the recording starts only with the in-app Record tap.

## Scope
- [x] Home-screen widget (RemoteViews, per ADR-QCP-01) with an open-Record-screen action and static text only.
- [x] Quick Settings tile (`TileService`, always inactive state; on API 34+ open the app with the `startActivityAndCollapse(PendingIntent)` overload) and a static launcher shortcut, both navigate-only.
- [x] Hand-off to Flutter with the same single-use, memory-only, 10 s request contract as QCP-02 (shared Pigeon definition). It never calls `RecordingController.start` and no `StartSource.homeScreenWidget` / `androidQuickSettingsTile` call is made. Stale, replayed or missing requests are ignored; a test asserts the hand-off never starts recording.
- [x] Recording itself reuses the AUD-05 foreground service, ongoing notification and CallGuard through the normal in-app start. No new permission; manifest additions limited to the widget receiver, tile service and shortcut metadata.
- [x] The merged-manifest check in `tools/ci/check_recording_policy.sh` still passes (no `READ_PHONE_STATE`, call audio sources, `SYSTEM_ALERT_WINDOW`, Accessibility service).
- [x] Tests: Dart unit tests for request validation and the never-calls-start check; Android tests where the toolchain allows; device rows on the QA-05 matrix.

## Acceptance Criteria
- Widget, tile and shortcut each open the app on the Record screen without recording, and the in-app Record tap then records with the ongoing notification visible, on a physical Android device (device row `docs/test-plans/device/QCP-03.md`; separate rows for API 26–30, API 31–33 and API 34+; the API 34+ row covers the tile-to-visible-activity hand-off).
- Expired, reused or missing requests never start recording and the hand-off never calls `RecordingController.start` (automated Dart tests, `[QCP-03/ACn]`).
- During a ringing or active call the in-app Record tap after a quick-capture open refuses (device row; same CallGuard path as AUD-05).
- The merged release manifest adds only the components named in the ADR and no forbidden permission (CI script output).
- No widget text derives from recordings (automated test of the widget data).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/QCP-03-android-quick-capture · **Date:** 2026-10-18
- **Summary:** Plain `AppWidgetProvider` + `RemoteViews` widget (Glance needs Compose and its minimum SDK is unconfirmed; the app has no Compose), `TileService` (always inactive; API 34+ `startActivityAndCollapse(PendingIntent)`, below that the Intent overload) and a static shortcut (per-flavor `shortcuts.xml`). Each fires an explicit `FLAG_IMMUTABLE` PendingIntent/Intent into `MainActivity` carrying one static extra. `MainActivity` stores it in the in-memory `QuickCaptureStore` (10 s, single-use; ignored on activity restore and on launch from Recents; extras stripped after reading). Dart reads it through the shared Pigeon `consumeRequest()` (now with a Kotlin output) and the existing `QuickCaptureHandoff`/`QuickCaptureHost`; `QuickCaptureEntry` gained `androidWidget`, `androidTile`, `androidShortcut` (routing only). `StartSource` is unchanged and no recorder code is referenced. Manifest additions: one receiver, one service (no foreground-service type) and the shortcuts meta-data.
- **Deviation:** the 10 s clock starts when `MainActivity` receives the intent, not when the user taps, because a widget/shortcut PendingIntent is static and cannot carry a fresh id or timestamp.
- **Deferred / Unverified:** all device rows (docs/test-plans/device/QCP-03.md), widget receiver `exported="false"` (D1), tile BAL on API 34–36 (D6), tile tap while the app is in the foreground (D13); no Android SDK here, so Kotlin compiles only in CI and has no JVM unit tests (follow-up).
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/QCP-03.md
  - AC2: ✅ test: [QCP-03/AC2]; ci: nice -n 10 fvm flutter test test/unit/recording/quick_capture_android_test.dart
  - AC3: ⏳ device: docs/test-plans/device/QCP-03.md
  - AC4: ✅ test: [QCP-03/AC4]; ci: bash tools/ci/check_recording_policy.sh --require-merged-manifest
  - AC5: ✅ test: [QCP-03/AC5]; ci: nice -n 10 fvm flutter test test/unit/recording/quick_capture_android_test.dart
