# AUD-09 — macOS Microphone Capture

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** AUD-01, SEC-09, FND-09 | **Source:** User decision 2026-10-14
**Status:** todo
**Skills:** vv-task-workflow, vv-audio-capture, vv-flutter-architecture, vv-testing

## Goal
On macOS, recording starts only after an explicit user click, uses the standard microphone API, and writes the same 16 kHz mono WAV chunks as iOS.

## Scope
- [ ] Microphone permission with a purpose string that says the user is recording a note, not a call.
- [ ] Capture goes through the existing recording service (AUD-01). No second recorder.
- [ ] Start only from the Record button. No launch-time capture, no menu-bar or shortcut that starts recording without that same explicit action.
- [ ] No screen capture, no system-audio tap, no aggregate device that includes another app's output.
- [ ] Permission denial and unplug-during-record follow the existing failure types. Unplug pauses; nothing auto-resumes.
- [ ] Tagged tests cover refusal without a user action and the WAV chunk format. Device row covers a real microphone grant.

## Acceptance Criteria
- A test named `[AUD-09/AC1]` fails if macOS capture can start without the Record button path.
- Granting the microphone and tapping Record produces a 16 kHz mono WAV chunk (device row in `docs/test-plans/device/AUD-09.md`).
- The macOS entitlements and Info.plist request microphone only. No screen-recording or audio-input capture of other processes.

## Notes
SEC-09 still applies: never record a phone or VoIP call. macOS has no cellular call, but do not attach to FaceTime, Continuity, or any call audio source.
