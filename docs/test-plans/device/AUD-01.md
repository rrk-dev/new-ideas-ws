# Device verification — AUD-01 Core Audio Recording Service (16 kHz Mono WAV)

Authored without devices, Xcode or an Android SDK: the capture path has only run against fakes
(`app/test/unit/recording/`). Fill Device/OS/Result/Date/Tester only after running.

Setup: install the **dev** flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <id>`),
open the Record tab → app-bar icon **Recording debug** (Start / Pause / Resume / Stop, "List inputs"
+ input picker, live phase/timer and a log of states and notices). Chunks are written to
`<appSupport>/vv/audio/<recording_id>/chunk_NNNN.wav`; pull them with
`adb exec-out run-as com.vaultvoice.vaultvoice.dev tar c files/vv/audio | tar x` (Android) or
Xcode → Devices → Download Container (iOS). Check with `soxi chunk_*.wav` / `ffprobe`.
Use a second phone/account as the caller.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-01/AC1] | iOS: Start; keep the app in the foreground (screen on, Auto-Lock off) 2 h with speech/radio playing nearby; Stop. Pull the container. | 24 chunks; every `soxi` shows 16000 Hz, 1 channel, 16-bit; sum of durations = timer ± 0.5 s; `sox chunk_*.wav all.wav` plays without gaps/clicks at the 5-min boundaries (listen at each boundary ± 2 s). | iPhone (oldest in matrix) | iOS 16+ | | | |
| [AUD-01/AC1] | Android: same 2 h foreground run. | Same as above. | Pixel + Samsung | Android 12+ | | | |
| [AUD-01/AC1] | Both platforms: "List inputs", pick a **Bluetooth HFP headset**, Start, speak 2 min, Stop. Repeat with a wired headset. | Log shows `mic format adjusted` (8/16 kHz) if the route forces another rate; chunks still 16 kHz mono; speech intelligible; recording never paused by itself (no `callActive`/`captureSilenced` from the SCO route). | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [AUD-01/AC2] | iOS, foreground: Start; speak counting aloud; incoming **cellular** call from the second phone; let it ring 5 s, answer, talk 10 s, hang up; wait 30 s. Then repeat with **WhatsApp/FaceTime** (VoIP). | Phase `PAUSED (call)` ≤ 500 ms after ringing starts (screen recording ≥ 30 fps, frame-step); recording stays paused after hang-up; no ringtone or call voice in any chunk (listen + waveform around the `call_interruption` marker); Resume tap continues into a new chunk. | iPhone | iOS 16+ | | | |
| [AUD-01/AC2] | Android, foreground: same with cellular and WhatsApp/Teams calls. | Same as above. | Pixel / Samsung | Android 12+ | | | |
| [AUD-01/AC2] | Both: while a call is ringing/active, tap Start. | "refused: Recording is unavailable during calls"; no mic indicator appears. | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [AUD-01/AC3] | Both: play a steady 1 kHz tone from a second device; Start, Pause/Resume 10× at random moments, Stop. Concatenate the chunks. | No audible click at any pause/resume point (listen + spectrogram: no broadband spike); total duration = recorded time shown (no duplicated audio). | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [AUD-01/AC4] | Needs AUD-04 (iOS) / AUD-05 (Android). Start, lock the screen for 10 min, unlock, Stop. | Recording continued while locked (chunk durations sum to the timer ± 0.5 s; OS mic indicator / notification visible). | iPhone + Android phone | iOS 16+ / API 26+ | | | |

## Notes / evidence
Evidence (screen recordings, `soxi` output, spectrograms) under `docs/test-plans/device/evidence/AUD-01/`.
Automated counterparts: `app/test/unit/recording/record_capture_backend_test.dart`
(`[AUD-01/AC1]` gapless sample-exact chunks + 2-hour chunk math, `[AUD-01/AC2]` call discard /
no auto-resume / refused start, `[AUD-01/AC3]` pause/resume without click or duplicated samples).
