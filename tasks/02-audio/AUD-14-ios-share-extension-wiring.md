# AUD-14 — iOS ShareExtension target wiring

**Workstream:** Audio | **Phase:** 1 | **Size:** S | **Depends on:** AUD-06 | **Source:** AUD-06 follow-up (was proposed as AUD-10); Codex review 2026-10-15
**Status:** in-progress
**Skills:** vv-task-workflow, vv-ffi-bridge, vv-privacy-security, vv-ci-release, vv-testing

## Goal
Audio shared from other iOS apps through the system share sheet reaches the VaultVoice import pipeline, with the existing `app/ios/ShareExtension/` sources built and embedded.

## Scope
- [ ] Add `ios/ShareExtension/` as an app extension target in `Runner.xcodeproj` (bundle id `$(APP_BUNDLE_IDENTIFIER).ShareExtension` per flavor, deployment target iOS 16) and embed it in Runner via "Embed Foundation Extensions".
- [ ] Add the App Group `group.<app id>` entitlement to Runner and the extension; register both in the developer portal and provisioning profiles.
- [ ] Run the AUD-06 AC2 device row and record evidence in `docs/test-plans/device/AUD-06.md`.
- [ ] Keep `tools/ci/check_recording_policy.py` and `check_egress.sh` passing; the extension adds no microphone, call-related or network capability.

## Acceptance Criteria
- A shared audio file from another app appears in the import flow and converts to the app WAV format (device row, AUD-06 AC2).
- The built Runner and extension contain the App Group entitlement and the extension is embedded (CI/build artifact check).
- The extension writes only to the App Group inbox and uses no network (policy and egress scripts).

## Notes
- Needs Xcode and signing. Whether a free personal team can sign App Groups is unverified (ADR-QCP-01, device row D5).
