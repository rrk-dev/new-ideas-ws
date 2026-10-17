# QCP-03 — Android quick capture: home widget, Quick Settings tile, app shortcut

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** QCP-01, AUD-05, AUD-08, SEC-09 | **Source:** User decision 2026-10-16 (product Phase 2: one-tap capture)
**Status:** todo
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-flutter-architecture, vv-privacy-security, vv-testing

## Goal
On Android (API 26+, arm64-v8a), a user can open the app straight to the Record screen from a home-screen widget, the Quick Settings tile or a launcher shortcut. Entry points are navigate-only (ADR-QCP-01 Accepted 2026-10-17): the recording starts only with the in-app Record tap.

## Scope
- [ ] Home-screen widget (RemoteViews, per ADR-QCP-01) with an open-Record-screen action and static text only.
- [ ] Quick Settings tile (`TileService`, always inactive state; on API 34+ open the app with the `startActivityAndCollapse(PendingIntent)` overload) and a static launcher shortcut, both navigate-only.
- [ ] Hand-off to Flutter with the same single-use, memory-only, 10 s request contract as QCP-02 (shared Pigeon definition). It never calls `RecordingController.start` and no `StartSource.homeScreenWidget` / `androidQuickSettingsTile` call is made. Stale, replayed or missing requests are ignored; a test asserts the hand-off never starts recording.
- [ ] Recording itself reuses the AUD-05 foreground service, ongoing notification and CallGuard through the normal in-app start. No new permission; manifest additions limited to the widget receiver, tile service and shortcut metadata.
- [ ] The merged-manifest check in `tools/ci/check_recording_policy.sh` still passes (no `READ_PHONE_STATE`, call audio sources, `SYSTEM_ALERT_WINDOW`, Accessibility service).
- [ ] Tests: Dart unit tests for request validation and the never-calls-start check; Android tests where the toolchain allows; device rows on the QA-05 matrix.

## Acceptance Criteria
- Widget, tile and shortcut each open the app on the Record screen without recording, and the in-app Record tap then records with the ongoing notification visible, on a physical Android device (device row `docs/test-plans/device/QCP-03.md`; separate rows for API 26–30, API 31–33 and API 34+; the API 34+ row covers the tile-to-visible-activity hand-off).
- Expired, reused or missing requests never start recording and the hand-off never calls `RecordingController.start` (automated Dart tests, `[QCP-03/ACn]`).
- During a ringing or active call the in-app Record tap after a quick-capture open refuses (device row; same CallGuard path as AUD-05).
- The merged release manifest adds only the components named in the ADR and no forbidden permission (CI script output).
- No widget text derives from recordings (automated test of the widget data).
