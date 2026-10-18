# AUD-13 — iOS Live Activity for recording state

**Workstream:** Audio | **Phase:** 5 | **Size:** M | **Depends on:** AUD-04, SEC-09, QCP-02 | **Source:** AUD-04 follow-up (was proposed as AUD-10); ADR-QCP-01 Amendment 4
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-privacy-security, vv-testing

## Goal
While a recording runs on iPhone, a Live Activity shows recording or paused state and the elapsed time on the Lock Screen and Dynamic Island, completing the SEC-09 §5 "iOS Live Activity where supported" indicator.

## Scope
- [ ] Add a WidgetKit/ActivityKit extension target (reuse the QCP-02 widget extension target if it exists) with `NSSupportsLiveActivities`; an App Group only if the Activity state needs one. Document targets and entitlements in `docs/ci.md`.
- [ ] Start the Activity only from the in-app Record tap, update it from `RecordingIndicatorBinding` through the existing `vaultvoice/recording_indicator` channel, and end it on stop, cancel, interruption or call.
- [ ] Show state and timer only: no transcript, title, file name or other recording-derived text. Buttons only open the app; nothing starts a recording from the Activity.
- [ ] Keep `tools/ci/check_recording_policy.py` and `check_egress.sh` passing; no permission, background mode or network host added.
- [ ] Tests: Dart tests for indicator state mapping and the content rule; device rows in `docs/test-plans/device/AUD-13.md`.

## Acceptance Criteria
- During an in-app recording on a physical iPhone the Activity shows recording/paused and the timer, and disappears when recording ends (device row).
- The Activity cannot start, resume or stop a recording (automated test and device row).
- The Activity data contains no recording-derived text (automated test).
- Policy and egress scripts, `flutter analyze` and the targeted tests pass.

## Notes
- ADR-QCP-01 (Accepted 2026-10-17) does not require this before quick capture ships; until it lands the OS microphone indicator plus the AUD-04 indicator satisfy SEC-09 §5.
