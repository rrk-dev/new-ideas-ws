# Device verification — AUD-05 Android Background Recording (Foreground Service)

Authored without an Android SDK or devices: `RecordingService.kt` / `RecordingIndicatorPlugin.kt`
are compiled by the CI `android` job but have never run. Fill Device/OS/Result/Date/Tester only
after running.

Setup: dev flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <id>`), Record
tab → **Recording debug**. Grant microphone and notification permission when asked. Pull chunks
with `adb exec-out run-as com.vaultvoice.vaultvoice.dev tar c files/vv/audio | tar x`; check with
`soxi`. Check the service with `adb shell dumpsys activity services com.vaultvoice.vaultvoice.dev`
(expect `isForeground=true foregroundServiceType=0x00000080` = microphone).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-05/AC1] | Start; press power (screen off); leave 60 min on battery with speech/radio nearby; unlock; Stop. | Notification visible the whole time (check on the lock screen at 30 min); 12 chunks; total duration = 60 min ± 0.5 s; no gaps (listen at each chunk boundary); no `paused` in the log. | Pixel | Android 14+ | | | |
| [AUD-05/AC1] | Same 60-min screen-off run on Samsung with default battery settings (guidance card shown on the Record screen first — follow it once, then repeat without following it and note the difference). | Same as above (note OEM behaviour in Notes). | Samsung | Android 13+ | | | |
| [AUD-05/AC1] | Start; swipe the app away from Recents; wait 5 min; reopen from the launcher; Stop. | Recording continued (engine retained): duration ≈ timer; the reopened app shows the running recording (no second engine/recording); notification stayed. | Pixel | Android 14+ | | | |
| [AUD-05/AC2] | Screen off while recording; on the lock screen / shade tap **Pause**, wait 30 s, **Resume**, wait 30 s, **Stop**. | Pause: chronometer stops, mic indicator (green dot) disappears, title "Recording paused"; Resume: recording continues in a new chunk; Stop: notification removed, recording finalized (Library row `recorded`). | Pixel + Samsung | Android 12+ | | | |
| [AUD-05/AC2] | Android 14+: swipe the ongoing notification away while recording. | It reappears immediately (re-posted); recording unaffected. | Pixel | Android 14+ | | | |
| [AUD-05/AC3] | Screen off, recording. Incoming **cellular** call from the second phone: ring 5 s, answer, talk 10 s, hang up. Repeat with **WhatsApp** and **Teams** calls. | ≤ 500 ms after ringing the notification shows "Recording paused because a call started"; no ringtone/call voice in any chunk (listen + waveform at the `call_interruption` marker); after hang-up it stays paused; Resume tapped *during* the call is refused (stays paused). | Pixel + Samsung | Android 12+ | | | |
| [AUD-05/AC3] | API 26–30 device: same cellular + WhatsApp test (500 ms polling path). | Same as above. | Android 8–11 device | API 26–30 | | | |
| [AUD-05/AC3] | Concurrent capture: while recording, start a voice recorder / camera video in another app; stop it. | Our recording pauses (`captureSilenced`/`interrupted` in the log), stays paused until Resume; no audio from the other app's session after the pause. | Pixel | Android 12+ | | | |
| [AUD-05/AC4] | Upload an internal-testing build to Play Console; fill the FGS declaration from `docs/play-console/fgs-declaration.md` with the video. | Declaration accepted; no policy warning for `FOREGROUND_SERVICE_MICROPHONE`; pre-launch report shows no FGS crash. | Play Console | — | | | |

## Notes / evidence
Evidence under `docs/test-plans/device/evidence/AUD-05/` (screen recordings, `dumpsys` output,
Play Console screenshots).
