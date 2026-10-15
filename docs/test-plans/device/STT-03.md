# Device verification — STT-03 Whisper Dart FFI Binding & Engine Service

Authored without devices. The bridge (`vv_stt_*`), the Dart binding (`VvWhisper`) and the engine
(`WhisperSttEngine`) were run on the macOS host build with `ggml-tiny.en` + `jfk.wav`
(ctests `vv_stt_*` incl. an ASan/UBSan build, `packages/vv_native/test/whisper_host_test.dart`,
`app/test/native/whisper_stt_engine_test.dart`). The rows below need a phone.

**Setup:** `tools/ci/fetch_test_models.sh ggml-tiny.en.bin jfk.wav`; copy both to the device
(Android: `adb push` to `/data/local/tmp/vv` and make it readable by the app, or into the app's
files dir with `run-as`; iOS: add via Xcode → Devices → app container), then
`cd app && fvm flutter test integration_test/stt_engine_test.dart --flavor dev -d <id>
--dart-define=VV_TEST_MODELS_DIR=<device dir>` (debug for correctness, `--profile` via
`flutter drive` for the frame-timing row). `binding.reportData` prints frames / p99 / cancel ms.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [STT-03/AC1] | Debug run of `stt_engine_test.dart` (`[STT-03/AC1] [STT-03/AC3]` test): jfk keywords, then the 10-min file (jfk × 55) with the live view on screen. The harness samples the **rendered** progress bar and segment counter after every frame and cancels as soon as ≥ 3 s live and ≥ 3 segments are displayed. | Test passes (`liveUiProblems` empty): displayed progress takes ≥ 2 increasing values, segment text is on screen, cancel issued while running (`completed_before_cancel=false`), `CancelledFailure` with `cancel_ms` < 1000. | iPhone 13 (Metal) | iOS 17/18 | | | |
| [STT-03/AC1] | Same. | Same (CPU backend on the default static build). | Android arm64 mid-range (e.g. Pixel 7a / Galaxy A54) | Android 14/15 | | | |
| [STT-03/AC1] | App flow once the pipeline is wired to `WhisperSttEngine` (follow-up): import a 10-min WAV, open the job. | Job screen shows step + % moving and segments appearing during transcription; Cancel stops within 1 s. | iPhone 13 + Android device | iOS 17/18, Android 14/15 | | | |
| [STT-03/AC2] | `flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/stt_engine_test.dart --flavor dev -d <id> --dart-define=VV_TEST_MODELS_DIR=<dir>` (the `[STT-03/AC2] [STT-03/AC3]` test only runs in profile mode; it skips in debug). Measures FrameTimings over ≥ 10 s of live transcription. Optionally capture a DevTools timeline during the same run. | Test passes (`frameBudgetProblems` empty): `frames` ≥ `live_window_ms`/33 (≥ 300 for 10 s; 0 frames fails), `p99_frame_us` ≤ 16000; no jank frames attributable to the UI isolate in DevTools. | iPhone 13 | iOS 17/18 | | | |
| [STT-03/AC2] | Same. | Same. | Android mid-range | Android 14/15 | | | |
| [STT-03/AC3] | Run the whole `integration_test/stt_engine_test.dart` on one Android and one iOS device in **both** debug (`flutter test …`) and profile (`flutter drive --profile …`) mode (QA-05 device lab or manually) and attach both logs incl. `reportData`. | Debug: AC1 test passes, AC2 test reported as skipped. Profile: both tests pass. | iPhone (iOS 16+) and Android arm64 (API 26+) | — | | | |

The harness checks themselves are host-tested (`app/test/unit/transcription/stt_live_harness_test.dart`,
`[STT-03/AC1]`/`[STT-03/AC2]`): they fail when the screen never rebuilds, when the run completes
before cancel, on a non-cancelled or ≥ 1 s cancel, on zero/too few frame samples and on p99 > 16 ms.

## Notes / evidence
Host (M3 Pro, macOS 27.0.1, tiny.en): cancel → `on_done(VV_E_CANCELLED)` 17 ms (Metal) / 224 ms
(CPU); base.en-q8_0: 53 ms (Metal) / 336 ms (CPU). jfk (11 s) transcribed in 85 ms (Metal, tiny).
Host event-loop proxy for AC2: sync bridge calls < 16 ms, p95 event-loop gap < 16 ms during
transcription (`[STT-03/AC2]` in `packages/vv_native/test/whisper_host_test.dart`).
