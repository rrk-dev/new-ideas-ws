# AUD-13 — iOS Live Activity for recording state

**Workstream:** Audio | **Phase:** 5 | **Size:** M | **Depends on:** AUD-04, SEC-09, QCP-02 | **Source:** AUD-04 follow-up (was proposed as AUD-10); ADR-QCP-01 Amendment 4
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-privacy-security, vv-testing

## Goal
While a recording runs on iPhone, a Live Activity shows recording or paused state and the elapsed time on the Lock Screen and Dynamic Island, completing the SEC-09 §5 "iOS Live Activity where supported" indicator.

## Scope
- [x] Add a WidgetKit/ActivityKit extension target (reuse the QCP-02 widget extension target if it exists) with `NSSupportsLiveActivities`; an App Group only if the Activity state needs one. Document targets and entitlements in `docs/ci.md`.
- [x] Start the Activity only from the in-app Record tap, update it from `RecordingIndicatorBinding` through the existing `vaultvoice/recording_indicator` channel, and end it on stop, cancel, interruption or call.
- [x] Show state and timer only: no transcript, title, file name or other recording-derived text. Buttons only open the app; nothing starts a recording from the Activity.
- [x] Keep `tools/ci/check_recording_policy.py` and `check_egress.sh` passing; no permission, background mode or network host added.
- [x] Tests: Dart tests for indicator state mapping and the content rule; device rows in `docs/test-plans/device/AUD-13.md`.

## Acceptance Criteria
- During an in-app recording on a physical iPhone the Activity shows recording/paused and the timer, and disappears when recording ends (device row).
- The Activity cannot start, resume or stop a recording (automated test and device row).
- The Activity data contains no recording-derived text (automated test).
- Policy and egress scripts, `flutter analyze` and the targeted tests pass.

## Notes
- ADR-QCP-01 (Accepted 2026-10-17) does not require this before quick capture ships; until it lands the OS microphone indicator plus the AUD-04 indicator satisfy SEC-09 §5.
- Verified at build time: the compiler enforces `ActivityAttributes` iOS 16.1 and `ActivityContent`/`Activity.request(attributes:content:pushType:)` iOS 16.2 (the Runner builds for iOS 16.0 with `#available(iOS 16.2, *)` guards). From web summaries of Apple documentation, not read on developer.apple.com: `NSSupportsLiveActivities` goes in the host app Info.plist; `pushType: nil` means local updates only; the system caps an Activity's lifetime (about 8 h). The exact update budget and Personal Team signing are **Unverified** (device rows D7, D9).
- The existing method channel `vaultvoice/recording_indicator` is extended (a `liveActivity` map in `show`) instead of adding a Pigeon API: it already carries the Record-tap-driven state, and the Activity payload is a two-field map.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/AUD-13-ios-live-activity · **Date:** 2026-10-18
- **Summary:** `RecordingActivityWidget` (Lock Screen + Dynamic Island, iOS 16.2+) added to `LumenWidgets`; `RecordingActivityAttributes` (`recording: Bool`, `timerStart: Date?`) shared by both targets; `RecordingLiveActivityController` in the Runner starts, updates and ends the Activity from `show`/`hide` (so only after the in-app Record tap, and ended on stop, cancel, interruption or call via the existing binding). The view uses static English words and a system `Text(date, style: .timer)`; a tap opens the Record screen via the QCP-02 link. No buttons, intents, push token, App Group, background mode or network. `NSSupportsLiveActivities` added to the Runner Info.plist. `LiveActivityShared` added to the policy and egress scan roots.
- **Deferred / Unverified:** all physical-device behaviour (rows D1–D10), Personal Team signing, the update budget and the 8 h cap. `flutter build ios --flavor dev --debug --no-codesign` succeeds locally.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/AUD-13.md
  - AC2: ✅ test: [AUD-13/AC2]; device: docs/test-plans/device/AUD-13.md; ci: nice -n 10 fvm flutter test test/unit/recording/live_activity_test.dart
  - AC3: ✅ test: [AUD-13/AC3]; ci: nice -n 10 fvm flutter test test/unit/recording/live_activity_test.dart
  - AC4: ✅ test: [AUD-13/AC4]; ci: bash tools/ci/check_recording_policy.sh && bash tools/ci/check_egress.sh
