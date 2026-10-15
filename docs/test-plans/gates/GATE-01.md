# GATE-01 — Phase 1 scenario: foundation, CI and safe recording

Task: [GATE-01](../../../tasks/13-milestones/GATE-01-phase1-foundation-recording.md).
Automated half: `app/integration_test/gate_01_recording_test.dart` (fake microphone and
call guard, real capture backend, controller and recovery). Device rows:
[../device/GATE-01.md](../device/GATE-01.md), all ⏳ until a person runs them.

Enterprise/MDM (LIC-04) is out of scope for the gates and is not checked here.

## Devices

Oldest and newest per platform, from [device-matrix.md](../../device-matrix.md):

| Platform | Oldest (Low) | Newest (High) |
|---|---|---|
| iOS | VV-IOS-11 (iPhone 11) | VV-IOS-16 (iPhone 16, or the 8 GB substitute) |
| Android | VV-AND-4G (4 GB) | VV-AND-FLG (Snapdragon flagship) |

Use a release-like dev build (`--flavor dev`), a fresh install, microphone permission
granted, and a second phone or SIM able to place a cellular call to the device.

## Steps and expected results

### S1 — CI and task state (AC1)

1. On `main`, run `python3 .agents/skills/vv-task-workflow/scripts/tasks.py verify --all-done --run`.
2. Confirm every dependency of GATE-01 is `done` with a Verification Report.

Expected: the command exits 0; CI on `main` is green.

### S2 — Locked 10 minute recording (AC2)

1. Tap Record. Note the timer.
2. Lock the phone and leave it 10 minutes.
3. Unlock, tap Stop. Note the final timer value.
4. Copy the chunk WAVs off the device (`audio/<recording_id>/`) and inspect them.

Expected: every chunk is a valid 16 kHz, mono, 16-bit WAV; total audio duration equals
the timer within ± 0.5 s; the recording indicator stayed visible.

Automated: `[GATE-01/AC2]` (10 minute fake-mic run, header and duration checks).

### S3 — Incoming call during recording (AC3)

1. Tap Record and speak for 10 s.
2. Call the phone from the second device and let it ring, then answer and talk 10 s.
3. Observe the app, hang up, and wait 1 minute.
4. Tap Resume, speak 10 s, tap Stop.
5. While a call is active, tap Record on the Record screen.

Expected: capture stops when the call rings and the recording shows paused; the file has
no call audio; the recording never resumes by itself after the call ends; Resume works
only by tap and only after the call ends; Record during a call is refused with a visible
message.

Automated: `[GATE-01/AC3]` (call stops capture, stays paused, Resume needs a tap, Record
refused).

### S4 — Force-kill recovery (AC4)

1. Tap Record and speak 30 s.
2. Force-kill the app from the app switcher (Android: swipe away, then Force stop).
3. Relaunch.

Expected: the recording is listed as recovered, plays back, and lost audio is at most
1 s.

Automated: `[GATE-01/AC4]` (kill, recover orphans, valid chunks, loss ≤ 1 s).

### S5 — Vault folder survives reboot (AC5)

1. Pick a vault folder (Android: Storage Access Framework; iOS: Files folder picker).
2. Write a test note to it from Settings.
3. Reboot the phone and unlock it once.
4. Write another test note without picking the folder again.

Expected: the second write succeeds with no permission prompt on both platforms.

## Pass rule

GATE-01 passes when S1 passes and S2 to S5 pass on all four devices. Any failure files
an issue and sends the owning task back to `in-progress`.
