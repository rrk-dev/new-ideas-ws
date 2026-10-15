# Device verification — AUD-08 Recording Screen UI

Authored without devices: the screen ran only in widget tests
(`app/test/widget/record_screen_test.dart`) with a fake capture backend. Fill
Device/OS/Result/Date/Tester only after running.

Setup: prod or dev flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <id>`),
Record tab.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-08/AC1] | Screen-record at 60 fps (second phone or QuickTime/scrcpy). Open the Record tab, wait 5 s, tap **Record** (profile Auto, no consent step). Frame-step from the finger touching the button to the OS microphone indicator (iOS orange dot / Android green dot) and the timer starting. Repeat 10×, cold and warm. | Median ≤ 300 ms, max ≤ 400 ms; **no** microphone indicator while the screen is open before the tap. With a consent profile: measured from tapping *Everyone present agrees*. | Oldest Android + oldest iPhone in the matrix | API 26+ / iOS 16+ | | | |
| [AUD-08/AC2] | Record 2 min, tap **Mark** at ~0:30 and ~1:30 (pause 20 s in between), stop, process. Open the transcript (STT-06). | Two markers at 0:30 and ~1:30 recorded time (pause not counted); displayed in the transcript view (STT-06). | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [AUD-08/AC3] | Walk through every state: idle → Record → Pause → Resume → incoming call (paused, "a call started", no auto-resume) → Resume → Stop → details sheet (title, tags, Save / Process now); start during a call ("Recording is unavailable during calls"); deny microphone permission. TalkBack / VoiceOver on. | Each state's text matches; the big button reads "Start recording / Pause recording / Resume recording" with the state as value; state changes are announced. | iPhone + Android phone | iOS 16+ / API 26+ | | | |

## Notes / evidence
