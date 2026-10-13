# AUD-05 — Android Background Recording (Foreground Service)

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** AUD-01, SEC-09 | **Source:** §3.1.1
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-privacy-security, vv-testing

## Goal
Recording survives backgrounding, screen-off and aggressive OEM battery managers.

## Scope
- [ ] Foreground service with `foregroundServiceType="microphone"` (Android 14+ requirement); persistent notification with pause/stop actions.
- [ ] Permissions: `RECORD_AUDIO`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS` (13+).
- [ ] Call handling via SEC-09 `CallGuard` (`AudioManager` mode: ringtone / in-call / in-communication) — stop capture immediately, mark gap, stay paused until the user taps Resume (**never auto-resume**); refuse to start during a call. Do not request `READ_PHONE_STATE`.
- [ ] Notification is ongoing/non-dismissible while recording; the only audio source used is `MIC`/`VOICE_RECOGNITION`.
- [ ] Battery-optimization guidance for Samsung/Xiaomi/OnePlus (deep link to settings, in-app explanation).
- [ ] Handle microphone being captured by another app (concurrent capture rules).

## Acceptance Criteria
- 60-min screen-off recording on Pixel and Samsung test devices with no gaps.
- Notification actions pause/stop correctly.
- Incoming cellular and VoIP call during recording: no call audio captured; recording remains paused after hang-up until Resume.
- Passes Play policy for foreground service type declaration.
