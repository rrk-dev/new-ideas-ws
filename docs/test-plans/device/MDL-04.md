# Device verification — MDL-04 Offline / Air-Gapped Model Import

Automated (host) evidence: `[MDL-04/AC1]` in `app/test/unit/models/model_importer_test.dart`
(network disabled, gateway client records zero requests, downloader refuses, STT + LLM
installed from signed single-model manifests) and in
`app/test/unit/network/network_gateway_stream_test.dart` (`network_disabled` refuses every
request, fails closed). The pipeline run needs real models and the native engines, so the
end-to-end criterion is a device row.

Prepare a "USB" folder (Files app / Android `Download/` or a USB-C stick) with, for each
model, `<file>` + `<id>.json` + `<id>.json.sig` built with
`tools/model-catalog/catalog.py build --only <id>` and signed with the key pinned in the dev
build. Use `whisper-tiny.en` and `qwen2.5-0.5b-instruct-q4_k_m` (files from
`tools/ci/fetch_test_models.sh`).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [MDL-04/AC1] | 1. Airplane mode ON (Wi-Fi + cellular off) before installing. 2. Fresh install of the dev flavor; optionally set `network_disabled` via managed config / debug setting. 3. Settings → "Import model from file" → select `ggml-tiny.en.bin`, `whisper-tiny.en.json`, `whisper-tiny.en.json.sig` → "Model installed". 4. Repeat for the GGUF set. 5. Import a 30 s fixture WAV and run the full pipeline (transcribe → extract → render → write to an app-local vault). | Both models installed (no network prompt, no request — confirm with mitmproxy/`adb shell dumpsys netstats` / Xcode network report: zero bytes); pipeline completes and the Markdown note exists with front-matter. | Android phone (QA-05 matrix) | Android 14+ | ⏳ | | |
| [MDL-04/AC1] | Same on iPhone (AirDrop or Files app as the source). | Same. | iPhone (QA-05 matrix) | iOS 17+ | ⏳ | | |

Negative checks on the same devices (no AC, record in notes): a manifest edited by one byte →
"signature is not valid"; model file from a different version → "does not match its manifest";
a GGUF without manifest → "Not a signed VaultVoice model" (custom model disabled).

## Notes / evidence
`docs/test-plans/device/evidence/MDL-04/`.
