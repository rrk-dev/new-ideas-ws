# Device / corpus verification — AUD-03 Dynamic Silence Detection / VAD

Authored without devices and without the QA-02 corpus (QA-02 is `todo`). Host evidence:
`native/tests/vad_test.cpp` (ctest `vv_vad_*`), `packages/vv_native/test/vad_host_test.dart`,
`app/test/native/ffi_vad_engine_test.dart` — run `tools/ci/fetch_test_models.sh` and
`native/build.sh host` first. Fill Device/OS/Result/Date/Tester only after running.

Setup: install the Silero VAD model (Settings → Models → "Voice detection (Silero VAD v6.2.0)",
or MDL-04 offline import) and an STT model. Settings → Processing → *Skip silence* toggles
silence skipping; Settings → Audio → *Auto-pause on silence* / *Stop after silence*.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [AUD-03/AC1] | QA-02 harness: transcribe the meeting subset with *Skip silence* off, then on (same STT model, same device, cool device, charger off); record total STT wall time and WER per file (vv-benchmark-eval protocol, 3 runs, median). | STT time with VAD ≤ 80 % of without (≥ 20 % reduction); WER(with) − WER(without) ≤ 1.0 pt on the subset. Numbers go into ADR-AUD-03. | Mid-range Android (Pixel 6a / Galaxy A54) + iPhone 12/13 | API 31+ / iOS 16+ | | | |
| [AUD-03/AC2] | QA-02 silence set (silence, room tone, HVAC noise, music without lyrics, long pauses inside speech): transcribe with *Skip silence* on and off. | With VAD: no transcript text on silence-only files and no invented text inside long pauses (e.g. "Thank you.", "Subtitles by…"); list the without-VAD hallucinations as the baseline. | Same as above | | | | |
| [AUD-03] | Record with *Stop after silence* = 5 min; speak 1 min, then stay silent. | Recording stops by itself ~5 min after the last speech (stop reason `silence`); the notification disappears. | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [AUD-03] | Record with *Auto-pause on silence* on; be silent 2 min, then speak loudly for 1 min. | Pauses after ~2 min ("Recording paused after silence"); speaking does **not** resume it; only tapping Resume does. | iPhone + Android phone | iOS 16+ / API 26+ | | | |
| [AUD-03] | Profile build: record 10 min with silence detection on; DevTools Performance. | No UI frame > 16 ms attributable to VAD (model runs on the `vv-vad-stream` isolate). | Oldest Android in the matrix | API 26+ | | | |

## Notes / evidence
