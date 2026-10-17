# QCP-02 — iOS quick capture: widget and Lock Screen control (navigate-only)

**Workstream:** Product Phase 2 | **Phase:** 5 | **Size:** L | **Depends on:** QCP-01, AUD-04, AUD-08, SEC-09 | **Source:** User decision 2026-10-16 (product Phase 2: one-tap capture); ADR-QCP-01 Accepted 2026-10-17
**Status:** todo
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-background-execution, vv-privacy-security, vv-testing, vv-ci-release

## Goal
On iPhone, a user can open the app straight to the Record screen from a Home Screen / Lock Screen widget or a Lock Screen / Control Center control. Entry points are navigate-only (ADR-QCP-01): the recording starts only with the in-app Record tap. The Action Button is deferred and out of scope.

## Scope
- [ ] Add the native targets ADR-QCP-01 requires (widget/controls extension; no App Group, since the hand-off is memory-only). Existing bundle ids and signing stay unchanged; ShareExtension wiring is AUD-14, Live Activity is AUD-13. Document targets and entitlements in `docs/ci.md`.
- [ ] Home Screen / Lock Screen widget (iOS 16+): open-app action and static Lumen branding only.
- [ ] Lock Screen / Control Center control (iOS 18+; absent below) as a button that opens the app (`openAppWhenRun`), with `isDiscoverable = false`. No Action Button support, no App Intent exposed to Siri, Spotlight or Shortcuts, no new `StartSource` value.
- [ ] Hand-off to Flutter through a Pigeon `consumeRequest()`: single-use, memory-only request with a 10 s expiry and the fields in ADR-QCP-01. Dart validates it and navigates to the Record screen. It never calls `RecordingController.start`. Stale, replayed or missing requests are ignored and logged without content; an app launch alone never starts recording.
- [ ] Extend the Swift source roots in `tools/ci/check_recording_policy.py` (currently `app/ios/Runner` only, around lines 133-134) to cover the new extension directory, and keep `check_recording_policy.sh` and `check_egress.sh` passing; no permission, background mode or network host added.
- [ ] Tests: Dart unit tests for request validation (expiry, replay, missing) and a test that the hand-off never calls `RecordingController.start`; a pinned `allowedStartSources` test (unchanged set); native unit tests where the toolchain allows; device rows for the rest.

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
