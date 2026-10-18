# AUD-14 — iOS ShareExtension target wiring

**Workstream:** Audio | **Phase:** 1 | **Size:** S | **Depends on:** AUD-06 | **Source:** AUD-06 follow-up (was proposed as AUD-10); Codex review 2026-10-15
**Status:** review
**Skills:** vv-task-workflow, vv-ffi-bridge, vv-privacy-security, vv-ci-release, vv-testing

## Goal
Audio shared from other iOS apps through the system share sheet reaches the Lumen import pipeline, with the existing `app/ios/ShareExtension/` sources built and embedded.

## Scope
- [x] Add `ios/ShareExtension/` as an app extension target in `Runner.xcodeproj` (bundle id `$(APP_BUNDLE_IDENTIFIER).ShareExtension` per flavor, deployment target iOS 16) and embed it in Runner via "Embed Foundation Extensions".
- [x] Add the App Group `group.<app id>` entitlement to Runner and the extension; register both in the developer portal and provisioning profiles (⏳ device row D5).
- [~] deferred → device rows: run the AUD-06 AC2 row (`docs/test-plans/device/AUD-06.md`, `AUD-14.md`); needs an iPhone.
- [x] Keep `tools/ci/check_recording_policy.py` and `check_egress.sh` passing; the extension adds no microphone, call-related or network capability.

## Acceptance Criteria
- A shared audio file from another app appears in the import flow and converts to the app WAV format (device row, AUD-06 AC2).
- The built Runner and extension contain the App Group entitlement and the extension is embedded (CI/build artifact check).
- The extension writes only to the App Group inbox and uses no network (policy and egress scripts).

## Notes
- Needs Xcode and signing. Whether a free personal team can sign App Groups is unverified (ADR-QCP-01, device row D5).
- Apple's capability table lists App Groups for free accounts, but whether Xcode provisions it (and the extension) on a Personal Team is unverified; fallback documented in `docs/audio-import.md`.

## Open Decisions
- PRODUCT-DECISION (proposed): paid-account/TestFlight builds ship the extension; Personal Team builds may drop it per the documented fallback if D5 fails.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/AUD-14-ios-share-extension-wiring · **Date:** 2026-10-18
- **Summary:** Added the `ShareExtension` app-extension target to `Runner.xcodeproj` (6 configs, `$(APP_BUNDLE_IDENTIFIER).ShareExtension`, iOS 16, embedded via Embed Foundation Extensions, target dependency), completed its Info.plist, added the App Group to `Runner.entitlements` and `APP_BUNDLE_IDENTIFIER` to Runner's configs, repointed AUD-10 comments, added `tools/ci/check_ios_share_extension.sh` (CI `static`) and scanned `app/ios/ShareExtension` in the egress and recording-policy scripts. The extension target builds unsigned locally. LumenWidgets untouched. Verified vs unverified Apple facts in `docs/audio-import.md`.
- **Acceptance evidence:**
  - AC1: ⏳ device: docs/test-plans/device/AUD-14.md
  - AC2: ✅ test: [AUD-14/AC2]
  - AC3: ✅ ci: tools/ci/check_egress.sh and tools/ci/check_recording_policy.sh (scan app/ios/ShareExtension)
