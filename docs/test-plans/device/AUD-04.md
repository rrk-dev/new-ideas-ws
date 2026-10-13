# Device verification — AUD-04 iOS Background Recording & Interruption Handling

Authored without Xcode or devices: the Swift sources were only type-checked against the Mac
Catalyst SDK with a stub Flutter module; the iOS build runs in CI. Fill Device/OS/Result/Date/Tester
only after running.

Setup: dev flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <id>`, then
stop `flutter run`), Record tab → **Recording debug**. Allow microphone and notifications. Pull the
container with Xcode → Devices → Download Container; check chunks with `soxi`. Film the screen
(≥ 30 fps) for timing rows. Use a second phone as the caller.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-04/AC1] | Start; lock the phone; leave 60 min on battery with speech/radio nearby; unlock; Stop. | Status bar shows the recording indicator while locked/backgrounded; 12 chunks; total = 60 min ± 0.5 s; no gaps at boundaries; no `paused` in the log; one "Still recording (1h 00m)" notification. | iPhone (oldest in matrix) | iOS 16+ | | | |
| [AUD-04/AC1] | Same 60-min locked run on the newest iPhone. | Same as above. | iPhone (newest) | latest iOS | | | |
| [AUD-04/AC2] | Locked + recording: incoming **cellular** call; ring 5 s; answer; talk 10 s; hang up; wait 30 s; unlock. | Capture stops ≤ 500 ms after ringing starts (measure from the screen recording / log `callActive` time vs ring); no ringtone/call voice in any chunk (listen + waveform at the `call_interruption` marker); after the call the app shows `PAUSED (call)` and stays paused (no auto-resume despite `.shouldResume`) until Resume is tapped. | iPhone | iOS 16+ | | | |
| [AUD-04/AC2] | Same with **FaceTime audio** and **WhatsApp** calls (foreground and locked). | Same as above. | iPhone | iOS 16+ | | | |
| [AUD-04/AC2] | Siri / alarm / timer interruption while recording. | Paused with `audio_interruption` gap; stays paused until Resume. | iPhone | iOS 16+ | | | |
| [AUD-04/AC3] | Recording (foreground and locked): connect **AirPods** mid-recording; 1 min later disconnect them; then plug/unplug a wired (Lightning/USB-C) headset. | Recording never shows `paused`; log shows `audio session event` + a `route_change` marker per engine restart; chunks continue (new chunk per restart, each 16 kHz mono); speech intelligible from each input; total gap per restart < 0.5 s. | iPhone + AirPods | iOS 16+ | | | |
| [AUD-04/AC3] | Settings → Developer → "Reset Media Services" (or trigger via a crash of mediaserverd) while recording. | Recording continues in a new chunk (`route_change` marker); no crash. | iPhone (developer mode) | iOS 16+ | | | |

## Notes / evidence
Evidence under `docs/test-plans/device/evidence/AUD-04/`. Live Activity rows will be added by AUD-10.
