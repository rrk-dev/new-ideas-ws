# AUD-09 — macOS Microphone Capture

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** AUD-01, SEC-09, FND-09 | **Source:** User decision 2026-10-14
**Status:** review
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-testing

## Goal
On macOS, recording starts only after an explicit user click, uses the standard microphone API, and writes the same 16 kHz mono WAV chunks as iOS.

## Scope
- [x] Microphone permission with a purpose string that says the user is recording a note, not a call.
- [x] Capture goes through the existing recording service (AUD-01). No second recorder.
- [x] Start only from the Record button. No launch-time capture, no menu-bar or shortcut that starts recording without that same explicit action.
- [x] No screen capture, no system-audio tap, no aggregate device that includes another app's output.
- [x] Permission denial and unplug-during-record follow the existing failure types. Unplug pauses; nothing auto-resumes.
- [x] Tagged tests cover refusal without a user action and the WAV chunk format. Device row covers a real microphone grant.

## Acceptance Criteria
- A test named `[AUD-09/AC1]` fails if macOS capture can start without the Record button path.
- Granting the microphone and tapping Record produces a 16 kHz mono WAV chunk (device row in `docs/test-plans/device/AUD-09.md`).
- The macOS entitlements and Info.plist request microphone only. No screen-recording or audio-input capture of other processes.

## Notes
SEC-09 still applies: never record a phone or VoIP call. macOS has no cellular call, but do not attach to FaceTime, Continuity, or any call audio source.

## Completion Notes
- **Agent:** Cursor · **Branch:** task/AUD-09-macos-microphone · **Date:** 2026-10-14
- **Summary:** macOS capture stays on `RecordingController` and `RecordCaptureBackend` (AUD-01). The macOS provider allows only `StartSource.inAppButton`. Unplug emits the existing interruption pause and does not reopen the mic. Purpose string and microphone-only entitlements live in `packages/vv_native/macos/` for FND-09 to merge. `MacAudioRouteObserver.swift` reports device removal and does not open the microphone.
- **Acceptance evidence:**
  - AC1: ✅ test: [AUD-09/AC1]
  - AC2: ⏳ device: docs/test-plans/device/AUD-09.md
  - AC3: ✅ test: [AUD-09/AC3]
- **Decisions:** none (no new recorder; record_macos 2.1.1 remains the OS microphone API)
- **Follow-ups:** FND-09 merges `packages/vv_native/macos/Info.plist`, `DebugProfile.entitlements`, `Release.entitlements`, and registers `MacAudioRouteObserver` in the runner. Real microphone grant was not run (Xcode license not accepted; no `sudo`).

## Follow-ups
- FND-09: copy the microphone purpose string and `com.apple.security.device.audio-input` into the runner, and register `MacAudioRouteObserver`. Do not add screen capture or a second recorder.
