---
name: vv-privacy-security
description: "Privacy/security policy and audits: network egress allowlist and test, dependency review, content-free logging, encryption-at-rest policy, backups, app lock, retention, licenses, store privacy, recording consent, threat model. Use when adding dependencies, network or log code."
---

# Privacy & Security

The product promise: **user content (audio, transcripts, extractions, notes, file names) never
leaves the device** except when the user explicitly shares/exports it. Every change is checked
against this skill.

## Network egress (SEC-02)
- One gateway: `app/lib/core/network/network_gateway.dart`. It owns the HTTP client and an
  allowlist: model catalog/CDN hosts (`vv-model-delivery`). Store billing (StoreKit /
  Play Billing) is performed by OS frameworks outside our HTTP client and is therefore *not* on the
  gateway allowlist — it is listed in `docs/privacy-audit.md` as the only other network use. Anything else throws `EgressDeniedFailure`.
- CI guard: script `tools/ci/check_egress.sh` fails if `package:http`, `package:dio`,
  `HttpClient(`, `Socket.connect`, `WebSocket`, `URLSession`/`OkHttp`/`HttpURLConnection`
  appear outside the gateway / downloader dirs (allowlist in the script).
- "Offline mode" setting (and MDM `network_disabled`) → gateway refuses everything.
- In-app "Network activity" log: timestamp, host, path, bytes (no headers/body).
- Platform: iOS ATS default (HTTPS only) + no `NSAllowsArbitraryLoads`; Android
  `network_security_config.xml` with `cleartextTrafficPermitted="false"`.
- Egress test (CI or pre-release): run e2e on emulator/simulator behind mitmproxy / Charles,
  export flow log, assert hosts ⊆ allowlist. Commit the report to `docs/privacy-audit.md`.

## Dependency review (every new package / native lib / model)
Before adding, check and record in `docs/privacy-audit.md` (table: name, version, purpose,
network? telemetry? license, last release, decision):
- Grep source for network/telemetry (`http`, `analytics`, `firebase`, `sentry`, `crashlytics`,
  `URLSession`, `OkHttp`). Firebase/Google Play services analytics are **forbidden**.
- License compatible with closed-source commercial distribution (MIT/BSD/Apache-2.0/Zlib OK;
  GPL/AGPL forbidden; LGPL only for dynamically linked native libs after review).
- Maintenance: release within ~12 months, issue activity. Pin exact version.

## Logging (FND-07)
- Logger in `core/logging` with levels; file sink with rotation (5 × 2 MB) in `<appSupport>/vv/logs`.
- **Never** log at INFO+: transcript/LLM text, prompts, file/folder names, vault paths, speaker
  names, profile field values. Use IDs + sizes + timings. DEBUG content logging only in `dev`
  flavor and compiled out of `prod` (`if (kDebugMode)` / flavor const).
- Redaction helper + unit tests with sample sensitive strings.
- Diagnostics export: zip(logs, device info, perf metrics, app/model versions) → preview →
  share sheet. No transcripts, no audio.

## Encryption at rest (SEC-01)
- DB: SQLite3 Multiple Ciphers or SQLCipher per SEC-01 ADR (`vv-local-database`). Files (audio chunks, rendered md, work dir): AES-256-GCM
  per-file key wrapped by a master key in Keychain/Keystore (crypto-shredding on delete).
  Stream encryption in chunks (e.g. 64 KB frames with per-frame nonce) so whisper reads via the
  bridge can decrypt on the fly — or decrypt to a `work/` temp file deleted after the step;
  decide in SEC-01 ADR (performance vs complexity).
- iOS Data Protection: `NSFileProtectionCompleteUntilFirstUserAuthentication` for app files
  (`.complete` breaks background recording/processing while locked). Keychain items
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Android: Keystore AES key (`setUserAuthenticationRequired(false)` so background works);
  StrongBox when available.
- Backups: iOS set `isExcludedFromBackup` on `vv/`; Android `android:allowBackup="false"` **and** `android:dataExtractionRules`
  excluding all domains in both `<cloud-backup>` and `<device-transfer>` **and**
  `android:fullBackupContent` excluding all (API ≤ 30). Exported vault notes are plaintext by design —
  UI must say so.

## App lock (SEC-03)
`local_auth` (biometric + device credential), lock on launch and after N min background,
privacy overlay on app-switcher snapshot (iOS: add in `sceneWillResignActive(_:)`, remove in
`sceneDidBecomeActive(_:)` — UIScene lifecycle, required with the iOS 27 SDK;
Android `FLAG_SECURE` on the activity when lock enabled). Recording can start from widget/
notification while locked; content stays hidden.

## Retention & deletion (SEC-04)
Policies per type (audio, transcript, extraction): after export / after N days / never.
Implementation and residual check: `vv-local-database` → Secure deletion. "Delete all data"
wipes DB, files, keys, bookmarks/SAF grants.

## License compliance (SEC-05)
`docs/licenses.md` inventory: every pub package (use `flutter pub deps` + `LicenseRegistry`),
native lib, and model. Models:
- Llama 3.x: Llama Community License — "Built with Llama" attribution, include license text +
  Acceptable Use Policy link, model name must start with "Llama" if we ship a derivative.
  Re-read the current license for the exact version used (3.2 terms differ from 3.1).
- Gemma: Gemma Terms of Use + Prohibited Use Policy pass-through to users.
- Whisper weights MIT; whisper.cpp/llama.cpp/ggml MIT; sherpa-onnx Apache-2.0; check every
  diarization/VAD model card individually (some pyannote models are gated/conditional).
In-app About → "Open-source & model licenses" screen (`showLicensePage` + custom entries
for native libs and models via `LicenseRegistry.addLicense`).

## Store compliance (SEC-06)
- iOS `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, no tracking domains, collected data
  types none, and **required-reason API** declarations for APIs we or our pods use (file
  timestamp, system boot time, disk space, UserDefaults). Verify every pod ships its own manifest.
- App Store "Data Not Collected" / Play Data safety "No data collected / shared" — only if true
  after the egress test.
- Downloaded models are data, not executable code (Guideline 2.5.2) — explain in review notes.
- Large post-install downloads: tell users the size before downloading (onboarding) and keep the
  app functional (record/import) while models download — reviewers check this (Guideline 4.2 / 2.3).
- Play: foreground service type declarations + justification video if requested; no
  `MANAGE_EXTERNAL_STORAGE`.

## Recording safeguards & consent (SEC-09, SEC-07)
- Recording policy lives in `vv-audio-capture` → "Recording policy": standard OS mic APIs only,
  user-tap start only, never phone/VoIP call audio, CallGuard, no pre-capture, always-visible
  indicator, no auto-resume.
- `tools/ci/check_recording_policy.sh` scans the **merged** Android manifest
  (`app/build/intermediates/merged_manifests/**/AndroidManifest.xml` — verify path for the AGP
  version), `Info.plist`, `*.entitlements`, and Dart/Kotlin/Java/Swift sources for forbidden
  permissions, audio sources, CallKit, `voip` mode, `.mixWithOthers`, MediaProjection,
  AccessibilityService. Any hit fails CI.
- Consent: first-run acknowledgement (required) + per-recording confirmation for multi-person
  profiles (default on; whether it can be disabled is a product/legal decision) →
  `consent_confirmed_at`, front-matter `consent_at`. Imports: rights/consent attestation.
- Speaker embeddings (diarization) are biometric data: transient only, never persisted, no
  voice enrollment.
- Managed config (MDM) can only make recording stricter; it can never start recording, hide
  indicators, or disable CallGuard/consent.
- This is engineering guidance, not legal advice — consent wording needs product/legal review.

## Threat model & testing (SEC-08)
STRIDE doc `docs/threat-model.md`. Must cover: malicious GGUF/model file (parser bugs → only
signed catalog models by default), tampered catalog (Ed25519), malicious `.vvprofile`/template
(zip slip, size limits, no template code execution), prompt injection via speech (grammar +
delimiting), covert/call recording misuse (SEC-09 controls not bypassable via settings, MDM,
deep links, intents, widgets), malicious imported audio (native decoders only, fuzz WAV parser), stolen device
(encryption + app lock), license forgery (signature), log leakage (redaction tests).
Fuzz `vv_bridge` WAV reader + GGUF load path with libFuzzer on host. CI: `osv-scanner` on
`pubspec.lock` and submodule commits. Pre-launch MobSF static scan, fix all high/critical.

## Pre-merge privacy checklist (paste in Completion Notes when relevant)
- [ ] No new network code outside gateway (CI egress script passes)
- [ ] No content in logs at INFO+ (redaction tests pass)
- [ ] New dependencies reviewed and recorded
- [ ] New files stored under `vv/` with correct protection + backup exclusion
- [ ] Recording policy check passes; no new way to start recording without a user tap
