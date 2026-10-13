# Device verification — MDL-01 Model Catalog Manifest & Hosting

The automated part of AC2 is `[MDL-01/AC2]` in `app/test/unit/models/catalog_repository_test.dart`
(every request the catalog code makes is captured and asserted). This row is the real-network
capture on a device/emulator. Model-file downloads arrive with MDL-02; until then the capture
covers the catalog requests only — re-run the row after MDL-02 lands with a model download.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [MDL-01/AC2] | 1. Start mitmproxy (`mitmweb --set block_global=false`), install its CA on the device (user CA on Android needs a debug `network_security_config` overlay for the dev flavor only). 2. Point the device Wi-Fi proxy at it. 3. Temporarily point `kCatalogBaseUris` / `kModelCdnHost` at a test bucket serving `app/assets/catalog/catalog.json(.sig)` (or use the real CDN once provisioned). 4. Fresh install of the dev flavor, launch, trigger catalog refresh (and, after MDL-02, download `whisper-tiny.en`). 5. Export the flow list (`File → Save`) to `docs/test-plans/device/evidence/MDL-01/flows.txt`. | Only hosts in `kModelHosts` appear; only `GET …/catalog.json`, `GET …/catalog.json.sig` (and model files after MDL-02); request headers are exactly `Host`, `User-Agent: VaultVoice/1`, `Accept: */*`, `Accept-Encoding`, `Content-Length: 0` (+ `Range` for downloads); no `Cookie`, `Authorization`, query strings or IDs. | Android dev phone (QA-05 matrix) + iPhone (QA-05 matrix) | Android 14+, iOS 17+ | ⏳ | | |

## Notes / evidence
Flow exports and screenshots: `docs/test-plans/device/evidence/MDL-01/`.
