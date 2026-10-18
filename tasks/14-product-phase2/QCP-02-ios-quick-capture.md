# QCP-02 — iOS quick capture: widget and Lock Screen control (navigate-only)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** L | **Depends on:** QCP-01, AUD-04, AUD-08, SEC-09 | **Source:** User decision 2026-10-16 (product Phase 2: one-tap capture); ADR-QCP-01 Accepted 2026-10-17
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-background-execution, vv-privacy-security, vv-testing, vv-ci-release

## Goal
On iPhone, a user can open the app straight to the Record screen from a Home Screen / Lock Screen widget or a Lock Screen / Control Center control. Entry points are navigate-only (ADR-QCP-01): the recording starts only with the in-app Record tap. The Action Button is deferred and out of scope.

## Scope
- [x] Add the native targets ADR-QCP-01 requires (widget/controls extension; no App Group, since the hand-off is memory-only). Existing bundle ids and signing stay unchanged; ShareExtension wiring is AUD-14, Live Activity is AUD-13. Document targets and entitlements in `docs/ci.md`.
- [x] Home Screen / Lock Screen widget (iOS 16+): open-app action and static Lumen branding only.
- [x] Lock Screen / Control Center control (iOS 18+; absent below) as a button that opens the app (`openAppWhenRun`), with `isDiscoverable = false`. No Action Button support, no App Intent exposed to Siri, Spotlight or Shortcuts, no new `StartSource` value.
- [x] Hand-off to Flutter through a Pigeon `consumeRequest()`: single-use, memory-only request with a 10 s expiry and the fields in ADR-QCP-01. Dart validates it and navigates to the Record screen. It never calls `RecordingController.start`. Stale, replayed or missing requests are ignored and logged without content; an app launch alone never starts recording.
- [x] Extend the Swift source roots in `tools/ci/check_recording_policy.py` (currently `app/ios/Runner` only, around lines 133-134) to cover the new extension directory, and keep `check_recording_policy.sh` and `check_egress.sh` passing; no permission, background mode or network host added.
- [x] Tests: Dart unit tests for request validation (expiry, replay, missing) and a test that the hand-off never calls `RecordingController.start`; a pinned `allowedStartSources` test (unchanged set); native unit tests where the toolchain allows; device rows for the rest.

## Acceptance Criteria
- Tapping the widget or control on a physical iPhone opens the app on the Record screen without recording; the in-app Record tap then records a valid 16 kHz mono WAV that appears in the Library (device row `docs/test-plans/device/QCP-02.md`).
- An expired request, a reused request and an app launch with no request never start recording, and the hand-off never calls `RecordingController.start` (automated Dart tests, `[QCP-02/ACn]`).
- `allowedStartSources` is unchanged and a pinned test fails if a value is added (automated).
- While a phone call is ringing or active, the in-app Record tap after a quick-capture open still refuses (device row; same CallGuard path as AUD-04).
- No widget, control or Lock Screen surface shows recording-derived text (automated test of the data the extension reads, plus device row).
- `check_recording_policy.sh`, `check_recording_policy.py` (scanning the new extension sources), `check_egress.sh`, `flutter analyze` and the targeted tests pass; the built Info.plist/entitlements add no permission, background mode or host.

## Notes
- Controls need iOS 18; on iOS 16/17 only the widgets exist and the app still builds for iOS 16+ (ADR-QCP-01).
- Shipping extensions may need a paid Apple Developer team; whether a free personal team can sign them is unverified (ADR-QCP-01 device row D5).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/QCP-02-ios-quick-capture · **Date:** 2026-10-17
- **Summary:** New `LumenWidgets` extension target (static Record widget for Home/Lock Screen, iOS 18 `ControlWidget` button with `openAppWhenRun`, `isDiscoverable = false`), no entitlements and no App Group. The widget opens `lumen://record?entry=widget`; the control runs an app-target intent. Both call `QuickCaptureStore` (shared Swift, in-memory, single-use, 10 s, replay ring of 16). Dart reads it through the Pigeon `QuickCaptureHostApi.consumeRequest()` at startup and on resume (`QuickCaptureHandoff`), validates it and navigates to `/record`; it never touches `RecordingController` and `StartSource` is unchanged. Policy and egress scripts scan the new directories. `FlutterDeepLinkingEnabled=false` keeps go_router from routing the URL.
- **Personal Team:** Apple lists App Groups for the free account, but nothing verified says a free Personal Team can sign an app extension (Unverified, device row D5). No App Group is needed.
- **Deferred / Unverified:** Action Button, Shortcuts, Siri (product decision); device rows AC1, AC4, AC5, D1, D5, D8, D10, D11, D12; native XCTest not run (simulator install failed; logic checked with a swiftc harness).
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/QCP-02.md
  - AC2: ✅ test: [QCP-02/AC2]; ci: nice -n 10 fvm flutter test test/unit/recording/quick_capture_handoff_test.dart
  - AC3: ✅ test: [QCP-02/AC3]; ci: nice -n 10 fvm flutter test test/unit/recording/quick_capture_handoff_test.dart
  - AC4: ⏳ device: docs/test-plans/device/QCP-02.md
  - AC5: ⏳ test: [QCP-02/AC5]; device: docs/test-plans/device/QCP-02.md
  - AC6: ✅ test: [QCP-02/AC6]; ci: bash tools/ci/check_recording_policy.sh && bash tools/ci/check_egress.sh
