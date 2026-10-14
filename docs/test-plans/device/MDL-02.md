# Device verification — MDL-02 Resumable Model Downloader

Automated (host) evidence: `app/test/unit/models/model_downloader_test.dart` (local HTTP server:
kill mid-download in a separate isolate + resume with `Range`, pause/resume, server ignoring
Range, hash mismatch → delete + re-download from zero, second mismatch → failure, no space,
Wi-Fi-only / cellular opt-in / Wi-Fi lost mid-download, low-power prompt, redirect to an
unlisted host rejected and never contacted, backoff 1 s → 60 s × 8, atomic install +
`models_installed`), `app/test/unit/network/network_gateway_stream_test.dart` (redirect policy)
and `app/test/unit/models/model_download_channel_test.dart` (Dart side of the native channel).
The rows below need real devices: the native background code (`ModelDownloadPlugin.swift`,
`ModelDownloadService.kt`) could not be built in the implementer's environment (no Xcode /
Android SDK).

Test model: a ≥ 2 GB GGUF entry (e.g. a 3B Q4_K_M) added to a dev-signed catalog served from a
test bucket on an allowlisted host (or temporarily allowlisted for the dev flavor only), plus
`whisper-tiny.en` for the quick rows. Start every row from a fresh install of the dev flavor.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [MDL-02/AC1] | 1. On Wi-Fi, start the 2 GB download. 2. At ~30 %, force-kill the app (Android: swipe away + `adb shell am force-stop <pkg>`; iOS: swipe up in the app switcher). 3. Note `ls -l …/vv/models/.partial/` size (Android `run-as`; iOS Xcode container download). 4. Relaunch the app. | Download resumes automatically on launch; the server/proxy log shows the next request with `Range: bytes=<partial size>-` (iOS force-quit: resume data or `Range` from the partial); total bytes transferred ≈ model size (no restart from 0); model installs and `models_installed` has the row. | Android phone (QA-05 matrix) | Android 14+ | ⏳ | | |
| [MDL-02/AC1] | Same as above on iPhone, plus variant: background the app (do not kill) and let iOS terminate it under memory pressure (Xcode → Debug → Simulate Memory Warning / open heavy apps). | Same; the background session keeps downloading while the app is not running and the next launch verifies + installs without re-downloading. | iPhone (QA-05 matrix) | iOS 17+ | ⏳ | | |
| [MDL-02/AC2] | 1. Serve a catalog whose sha256 for the test model is wrong (dev key), or corrupt one byte of the hosted file. 2. Download. | First full download → verify fails → partial deleted → second download from byte 0 (proxy shows no `Range`) → second failure shows an integrity error; no file under `models/<id>/`, no `models_installed` row. | Android + iPhone | as above | ⏳ | | |
| [MDL-02/AC3] | 1. On Wi-Fi, start the 2 GB download. 2. Lock the screen / switch to another app for 60 min (Android: confirm the "Downloading model" FGS notification). 3. Return. | Download completed (or still progressing) while backgrounded; installed after verification; no crash; Android notification removed at the end. | Android phone (QA-05 matrix) | Android 14+ (also 15+: `adb shell am compat enable FGS_INTRODUCE_TIME_LIMITS <pkg>` + short `data_sync_fgs_timeout_duration` → service stops cleanly, download resumes on next launch) | ⏳ | | |
| [MDL-02/AC3] | 1. On Wi-Fi, start the 2 GB download. 2. Lock the iPhone for 60 min. 3. Return. | Background session finished the transfer; app (relaunched by iOS or on open) appends, verifies and installs; no crash. | iPhone (QA-05 matrix) | iOS 17+ | ⏳ | | |
| Privacy (supports MDL-01/AC2) | mitmproxy capture of a full `whisper-tiny.en` download via the HF mirror URL (CDN URL unreachable). | Hosts: `huggingface.co` → `us.aws.cdn.hf.co` only; headers `User-Agent: VaultVoice/1`, `Accept: */*`, `Range` (resume), iOS `Accept-Language: *`; no cookies/IDs. A test redirect to an unlisted host is not followed. | Android + iPhone | as above | ⏳ | | |
| Wi-Fi only | On cellular only (Wi-Fi off), start a download without the opt-in; then allow cellular. | Refused with "Wi-Fi required" until opt-in; after opt-in downloads over cellular. iOS: background session waits for Wi-Fi when cellular is not allowed. | Android + iPhone | as above | ⏳ | | |

## Notes / evidence
Proxy flow exports, `ls -l` outputs and screen recordings: `docs/test-plans/device/evidence/MDL-02/`.
