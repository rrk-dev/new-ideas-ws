# AUD-04 — iOS Background Recording & Interruption Handling

**Workstream:** Audio | **Phase:** 1 | **Size:** M | **Depends on:** AUD-01, SEC-09 | **Source:** §3.1.1 (Background Audio Capture)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-audio-capture, vv-background-execution, vv-testing

## Goal
Recording continues with the app backgrounded or the device locked, and recovers gracefully from interruptions.

## Scope
- [ ] Enable `audio` UIBackgroundMode; `NSMicrophoneUsageDescription` copy.
- [ ] Handle `AVAudioSession.interruptionNotification` (phone calls, FaceTime/VoIP, Siri, alarms) — pause immediately and mark gap. **Never auto-resume**, even when the system reports `.shouldResume`; the user must tap Resume.
- [ ] Use SEC-09 `CallGuard` (`CXCallObserver`) so a ringing/active call stops capture even if no interruption arrives; refuse to start while a call is active.
- [ ] Handle route changes (AirPods connect/disconnect, wired headset).
- [ ] Handle media services reset.
- [ ] Live Activity / lock-screen indicator showing recording state (required where supported — SEC-09 visibility rule).

## Acceptance Criteria
- 60-min locked-screen recording completes without loss.
- Incoming call during recording: capture stops ≤ 500 ms after ringing starts, no call audio in the file, gap marked in metadata, and the recording stays paused after the call until the user taps Resume.
- Bluetooth headset connect mid-recording does not stop recording.
