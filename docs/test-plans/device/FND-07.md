# Device verification — FND-07 Local-Only Logging & Diagnostics

The zip contents, rotation and redaction are covered by host tests (`[FND-07/AC1]`,
`[FND-07/AC2]`). These rows confirm the real share sheet and app-private paths on devices, which
could not be run when this was authored (no Xcode / Android SDK).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [FND-07/AC2] | 1. Install the dev build (`fvm flutter run --flavor dev -t lib/main_dev.dart`). 2. Use the app for a minute (switch tabs). 3. Settings → Export diagnostics. 4. Expand each file in the preview. 5. Tap Share → "Save to Files" (or AirDrop to a Mac). 6. Unzip on a computer. | Preview lists `logs/vv.log`, `device.json`, `metrics.jsonl`, `manifest.json`; the zip has exactly those files; `device.json` shows iOS + version; logs contain `app start` and no DEBUG lines, no file names or paths. Nothing is sent before a share target is picked; Cancel shares nothing. On iPad the sheet anchors to the tile. | iPhone (and an iPad if available) | iOS 16+ | | | |
| [FND-07/AC2] | Same steps on Android; in step 5 pick "Files"/"Drive (save locally)" or Quick Share to a nearby device. Then `adb shell run-as com.vaultvoice.vaultvoice.dev ls files/vv/logs` (path from `getApplicationSupportDirectory`). | Same zip contents; log files only in app-private storage; no new permissions requested. | arm64 Android phone | API 26+ | | | |

## Notes / evidence
Attach the unzipped file listing under `docs/test-plans/device/evidence/FND-07/`.
