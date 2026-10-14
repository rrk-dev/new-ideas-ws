# Device verification — AUD-02 Auto-Gain Control & Level Metering

Authored without devices: the AGC, meter and clipping detector have only run against fakes
(`app/test/unit/recording/agc_level_meter_test.dart`, `app/test/widget/level_meter_bar_test.dart`).
Fill Device/OS/Result/Date/Tester only after running.

Setup: dev flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart -d <id>`), Record
tab → app-bar **Recording debug** (live meter under the phase/timer line). Settings → Audio has
*Automatic gain control*, *Noise suppression*, *App gain control* and *Raw capture*. The log line
`audio processing {agc, ns, vpio, sw_agc}` (Settings → Diagnostics export) shows what was applied.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-02/AC1] | For each setting combination (defaults; AGC off + NS off; App gain control on; Raw capture on): Start, speak 20 s at 1 m from the phone, Stop; export the diagnostics log. | Log `audio processing` matches the combination (Android: `agc`/`ns` true only if the device has the effect; iOS: `vpio` true when AGC or NS is on; raw: all false). App gain control: quiet speech audibly louder in the chunk, no peak above −1 dBFS (`sox chunk.wav -n stat` → max amplitude ≤ 0.891). | iPhone + Android phone (one without `AutomaticGainControl` if available) | iOS 16+ / API 26+ | | | |
| [AUD-02/AC1] | Shout / clap close to the mic for 3 s while recording. | "Too loud — move the phone further away." appears within 1 s and the meter turns red; it disappears ≤ 2 s after the noise stops. | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [AUD-02/AC3] | Profile build (`fvm flutter run --profile --flavor dev -t lib/main_dev.dart`), DevTools → Performance. Record 60 s while speaking; watch the meter. | Meter visibly moves ≥ 15 times per second with speech (screen recording at 60 fps, count distinct bar positions over 1 s); no frame > 16 ms build+raster in the recorded window (p99). | Oldest Android in the matrix + oldest iPhone | iOS 16+ / API 26+ | | | |
| [AUD-02/AC2] | QA-02: run the corpus with platform AGC on vs off, App gain control and Raw capture; compare WER. | Default kept or changed in ADR-AUD-02 with the numbers. | QA-02 corpus devices | — | | | |

## Notes / evidence
