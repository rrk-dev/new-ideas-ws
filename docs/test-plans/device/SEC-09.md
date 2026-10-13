# Device verification — SEC-09 Recording Safeguards: User-Started Only, Never Record Calls

Authored without devices, Xcode or an Android SDK: the Kotlin/Swift CallGuard code is compiled by
CI (`android`/`ios` jobs) but has never run. Fill Device/OS/Result/Date/Tester only after running.

Setup for AC2: install the **dev** flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <id>`),
open the Record tab → app-bar icon "CallGuard debug". The screen shows `Call state`, a log of
platform events with their timestamps and the "+N ms to Dart" latency, and a **Try start** button
that runs `RecordingController.start(StartSource.inAppButton)` against a backend that never opens the
microphone. Measure "ringing → state shown" with a screen recording at ≥ 30 fps that also shows the
calling phone (or the caller's ring-back), frame-step to both moments; record the numbers in Notes.
Use a second phone/account as the caller.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [SEC-09/AC1] | Push a throw-away branch adding `<uses-permission android:name="android.permission.READ_PHONE_STATE"/>` to `app/android/app/src/main/AndroidManifest.xml`; open a draft PR; then a second commit replacing it with `MediaRecorder.AudioSource.VOICE_CALL` in a Kotlin file. Do not merge; delete the branch. | `static` job fails at `check_recording_policy.sh` with `RECORDING-POLICY: … READ_PHONE_STATE` (then `… call audio source: VOICE_CALL`); `android` job also fails on the merged manifest. Paste both run URLs in Notes. | GitHub Actions | ubuntu-latest | | | |
| [SEC-09/AC2] | iOS, foreground, debug screen open. Incoming **cellular** call from the second phone; let it ring 5 s; decline. | `Call state: IN CALL` ≤ 500 ms after ringing starts; log shows `callActive`; **Try start** while ringing ⇒ "refused: Recording is unavailable during calls"; after hang-up `callEnded` and `no call`. | iPhone (oldest in matrix) | iOS 16+ | | | |
| [SEC-09/AC2] | iOS: repeat with incoming **FaceTime audio**, **WhatsApp** and **Teams** calls; also an outgoing cellular call placed from the app switcher while the debug screen is open. | Same as above for every call type (CallKit apps report via `CXCallObserver`); note any app that is detected only via `interruptionBegan`. | iPhone (newest in matrix) | latest iOS | | | |
| [SEC-09/AC2] | Android **API 31+**, foreground, debug screen open. Incoming cellular call; ring 5 s; answer 5 s; hang up. | `IN CALL` ≤ 500 ms after ringing (mode RINGTONE → IN_CALL); Try start refused while ringing and connected; `callEnded` after hang-up. | Pixel / Samsung (API 31+) | Android 12+ | | | |
| [SEC-09/AC2] | Android API 31+: repeat with incoming **WhatsApp** and **Teams** VoIP calls (mode IN_COMMUNICATION / RINGTONE). | Same as above; note any app not detected. | Pixel / Samsung (API 31+) | Android 12+ | | | |
| [SEC-09/AC2] | Android **API 26–30** device (polling path): incoming cellular call and one WhatsApp call. | `IN CALL` ≤ 500 ms after ringing (500 ms poll + delivery); refused start; clears after hang-up. | Android 8–11 device | API 26–30 | | | |
| [SEC-09/AC5] | Needs AUD-01 + AUD-04/AUD-05 (real capture + notification). iOS and Android: start recording, background the app for 61 min. | One "Still recording (1h 00m)" reminder at 60 min; none while the app is in the foreground. | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [SEC-09/AC5] | Needs AUD-01 + AUD-04/AUD-05. Set max duration to the minimum allowed for testing (or a dev-flavor override of `RecordingLimits`), start recording, background/lock the phone. | Recording stops automatically at the max duration, file finalized, notification removed; paused time not counted. | iPhone + Android phone | iOS 16+ / API 26+ | | | |

## Notes / evidence
Evidence (screen recordings, CI run URLs) under `docs/test-plans/device/evidence/SEC-09/`.
Capture-level call tests (zero call audio in the file, no auto-resume, foreground/background/locked)
belong to AUD-01, AUD-04, AUD-05 and QA-04 (SEC-09/AC3).
