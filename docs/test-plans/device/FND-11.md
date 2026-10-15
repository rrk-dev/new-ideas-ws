# Device verification — FND-11 Production Engine Wiring

No physical device was available when this was authored; the same flow passes on the macOS host
(`app/test/native/production_pipeline_host_test.dart`, `[FND-11/AC2]`, real whisper.cpp + llama.cpp).

Setup: `tools/ci/fetch_test_models.sh` on the workstation, then copy `ggml-tiny.en.bin`,
`SmolLM2-135M-Instruct-Q8_0.gguf` and `jfk.wav` to a directory the dev app can read
(Android: `adb push … /sdcard/Android/data/<dev package>/files/test-models/`; iOS: the app's
Documents folder via Finder file sharing) and pass it as `VV_TEST_MODELS_DIR`.
Run: `cd app && fvm flutter test integration_test/production_pipeline_test.dart --flavor dev -d <id> --dart-define=VV_TEST_MODELS_DIR=<device dir>`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-11/AC4] | Run the integration test above with the app in the foreground. | Test passes: job `done`, one `exports` row `written`, the note in the app-local vault (Files › On My iPhone › VaultVoice Dev) has front-matter `source: vaultvoice` and the test recording's `recording_id`. | iPhone (≥ 4 GB RAM) | iOS 16+ | ⏳ | | |
| [FND-11/AC4] | Same on Android. | Same; note under `filesDir/vault`. STT and LLM never resident together (RSS drops after transcription). | Android arm64 (≥ 4 GB RAM) | API 26+ | ⏳ | | |
| [FND-11/AC4] | Real recording: record ~20 s with the dev recording screen, stop, process now; check the note. With no model installed first, the job shows "waiting for model"; install the models → it finishes. | A note appears in the configured vault target; the job is never `failed`. | iPhone + Android | as above | ⏳ | | |
| [FND-11/AC4] | Press Home while the job is extracting (iPhone). | No crash; the LLM run restarts on the CPU (no Metal work in background); the job completes or resumes on return. | iPhone | iOS 16+ | ⏳ | | |
