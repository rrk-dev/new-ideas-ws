# Device verification — AUD-07 In-Progress Recording Crash Recovery

Authored without devices: recovery has only run against simulated kills
(`app/test/unit/recording/recording_recovery_test.dart`). Fill Device/OS/Result/Date/Tester only
after running.

Setup: dev flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <id>`, then
stop `flutter run` so the app runs standalone), Record tab → **Recording debug**. Film the phone
screen (≥ 30 fps) so the recording timer at the moment of the kill is visible. For each run note
`timer at kill` and the recovered **Length** shown by the launch prompt
("Recovered recording from <time> — process now?"); loss = timer − length.
Vary the moment of the kill: right after Start, mid-chunk, just after a 5-min chunk boundary,
while paused, right after Resume.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-07/AC1] | Android, 10 runs: Start, record 10 s – 12 min, kill with `adb shell am force-stop com.vaultvoice.vaultvoice.dev` (5 runs) and `adb shell am kill` after backgrounding / `adb shell kill -9 <pid>` (5 runs). Relaunch from the launcher. | Each relaunch shows the recovered prompt once; Length ≥ timer at kill − 1 s; pulled chunks (`run-as … tar`) all pass `soxi` (16 kHz mono) and play to the end; Library row `recovered`. "Process now" queues the job. | Pixel | Android 14+ | | | |
| [AUD-07/AC1] | Same 10 runs on a Samsung (OEM process killer). | Same as above. | Samsung | Android 12+ | | | |
| [AUD-07/AC1] | iOS, 10 runs: Start, record 10 s – 12 min, kill by swiping the app away in the app switcher (5 runs) and by stopping it from Xcode/`xcrun devicectl device process terminate` (5 runs). Relaunch. | Same as above (container pulled with Xcode → Download Container). | iPhone | iOS 16+ | | | |
| [AUD-07/AC1] | Battery death: on each platform once, record with < 2 % battery until the phone switches off; charge, relaunch. | Recovered with ≤ 1 s loss relative to the last timer value visible in the screen recording. | iPhone + Android phone | iOS 16+ / API 26+ | | | |

## Notes / evidence
Evidence (screen recordings, `soxi` output, measured losses per run) under
`docs/test-plans/device/evidence/AUD-07/`.
