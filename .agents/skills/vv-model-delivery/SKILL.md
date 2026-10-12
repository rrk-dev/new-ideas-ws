---
name: vv-model-delivery
description: "Model files: signed Ed25519 catalog manifest, CDN hosting and download privacy, resumable verified downloader, atomic install, backup exclusion, model management UI, offline sideload. Use for downloading, installing or listing models."
---

# Model Delivery

The only network traffic the app ever makes for content is fetching **public, anonymous model
files**. Everything here exists to keep that promise verifiable.

## Manifest (MDL-01) — `catalog.json` + `catalog.json.sig`
```json
{
  "schema": 1,
  "issued_at": "2026-10-12T00:00:00Z",
  "min_app_version": "1.0.0",
  "models": [{
    "id": "whisper-base.en-q5_1",
    "type": "stt",                       // stt | llm | vad | diarization-seg | diarization-emb | coreml-encoder
    "version": "1",
    "display_name": "Whisper Base (English)",
    "tier": "free",                      // free | pro | enterprise
    "file": "ggml-base.en-q5_1.bin",
    "size": 59707625,
    "sha256": "<hex>",
    "min_ram_mb": 2048,
    "recommended_device_tiers": ["low","mid","high"],
    "license": "MIT",
    "license_url": "https://…",
    "attribution": null,
    "urls": ["https://models.<our-domain>/stt/ggml-base.en-q5_1.bin", "https://mirror…"],
    "companions": []                     // e.g. coreml encoder ids
  }]
}
```
- Sign the exact bytes of `catalog.json` with Ed25519 (`tools/model-catalog/sign.py`,
  private key **never** in repo/CI logs — offline or CI secret). App pins the public key(s)
  (support 2 keys for rotation). Reject on bad signature, `issued_at` older than the bundled
  catalog (rollback protection), or unknown `schema`.
- Bundled fallback `app/assets/catalog/catalog.json(.sig)` for first launch / offline.
- Hosting: our own object storage + CDN (recommended in README). Hugging Face only as a mirror.
  Before mirroring, confirm each model's license allows redistribution (SEC-05).
- Request privacy: plain `GET` with `Range`, no cookies, no auth, no query params, generic
  User-Agent (`VaultVoice/<major>`), no device IDs. CDN access logs: disable or shortest
  retention, document in `docs/privacy-audit.md` exactly what the server can see (IP, UA, file).
- All requests go through `lib/core/network/NetworkGateway` (`vv-privacy-security`).

## Downloader (MDL-02)
- Package: `background_downloader` (verify maintenance) or native (iOS background `URLSession`,
  Android WorkManager). Must support: background continuation, pause/resume, HTTP Range resume,
  retry with backoff (1 s → 60 s, max 8), cancel.
- Preconditions: free space ≥ `size × 1.1 + 200 MB`; Wi-Fi only unless user allowed cellular
  (show size). Low-power mode → ask.
- Download to `models/.partial/<id>` → stream SHA-256 in a background isolate (or native) →
  compare → atomic rename to `models/<id>/<file>` → insert `models_installed` → delete partial.
  Mismatch ⇒ delete + retry from zero once, then fail with clear error.
- Backup exclusion: iOS `URLResourceValues.isExcludedFromBackup = true` on `models/`;
  Android: `allowBackup="false"` + `dataExtractionRules` (`<cloud-backup>` and `<device-transfer>`)
  + `fullBackupContent` (API ≤ 30) excluding everything (`vv-privacy-security`).
- Models never shipped in the app binary (REL-03), except optionally a tiny VAD model.

## Model management UI (MDL-03)
List by type: name, size, tier badge, installed/active, compatibility (`DeviceCapabilities`
vs `min_ram_mb`). Actions: download, delete, set active. Deleting the active model requires
choosing a replacement (or confirm "STT disabled until you download one"). Show total storage:
models / audio / transcripts. Newer `version` in catalog → "Update available".

## Sideload (MDL-04)
Import via file picker: model file + its signed **single-model manifest** (`<id>.json` +
`.sig`, same key). Verify signature + SHA-256 exactly like online path. Unsigned custom GGUF only
behind Pro "Advanced: custom model" with a warning and GGUF header sanity check (magic `GGUF`,
version, tensor count bounds) before passing to llama.cpp. Enterprise managed config may set
`network_disabled = true` → downloader hidden, sideload only.

## Verification
- Tests: bad signature, rollback, hash mismatch, partial resume (kill mid-download), no space.
- Proxy capture of a full download: only catalog + model hosts, headers as specified.
- Airplane-mode fresh install fully provisioned via sideload runs the full pipeline.
