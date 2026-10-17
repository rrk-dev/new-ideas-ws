# QCP-03 — Android quick capture: home widget, Quick Settings tile, app shortcut

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** M | **Depends on:** QCP-01, AUD-05, AUD-08, SEC-09 | **Source:** User decision 2026-10-16 (product Phase 2: one-tap capture)
**Status:** todo
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-flutter-architecture, vv-privacy-security, vv-testing

## Goal
On Android (API 26+, arm64-v8a), a user can start a recording with one deliberate tap from a home-screen widget, the Quick Settings tile or an app shortcut, as decided in ADR-QCP-01.

## Scope
- [ ] Home-screen widget (technology per ADR-QCP-01) with a record action and static text only.
- [ ] Quick Settings tile (`TileService`) and a launcher app shortcut, following the ADR's start-now vs navigate-only decision and the Android 14+ microphone foreground-service start rules it recorded.
- [ ] Hand-off to Flutter with the same single-use expiring token contract as QCP-02 (shared Pigeon definition if the ADR allows), then `RecordingController.start(StartSource.homeScreenWidget | androidQuickSettingsTile)`. Stale or replayed tokens are ignored.
- [ ] Reuse the AUD-05 foreground service, ongoing notification and CallGuard. No new permission; manifest additions limited to the widget receiver, tile service and shortcut metadata.
- [ ] The merged-manifest check in `tools/ci/check_recording_policy.sh` still passes (no `READ_PHONE_STATE`, call audio sources, `SYSTEM_ALERT_WINDOW`, Accessibility service).
- [ ] Tests: Dart unit tests for token validation and source mapping; Android tests where the toolchain allows; device rows on the QA-05 matrix.

## Acceptance Criteria
- Widget, tile and shortcut each start (or open ready to start, per the ADR) a recording on a physical Android device with the ongoing notification visible (device row `docs/test-plans/device/QCP-03.md`; API 26–30 and API 31+ rows separate).
- Expired, reused or missing tokens never start recording (automated Dart tests, `[QCP-03/ACn]`).
- During a ringing or active call none of the entry points records (device row; same CallGuard path as AUD-05).
- The merged release manifest adds only the components named in the ADR and no forbidden permission (CI script output).
- No widget text derives from recordings (automated test of the widget data).
