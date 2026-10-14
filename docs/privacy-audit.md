# Privacy audit

Living record of every network use and every dependency review (`vv-privacy-security`).
SEC-02 owns the full egress audit (proxy capture of an e2e run); sections below are added by
the task that introduces the network use or dependency.

## Network uses
| # | What | Who calls it | Hosts | Task |
|---|---|---|---|---|
| 1 | Model catalog `catalog.json` + `catalog.json.sig` | `CatalogRepository.refresh` via `NetworkGateway` | `kModelCdnHost` (placeholder `models.vaultvoice.example`, PRODUCT-DECISION) | MDL-01 |
| 2 | Model files (`urls` in the signed catalog) | `ModelDownloader` via `NetworkGateway.getStream` (Android/host) or gateway-resolved URL → iOS background download session (MDL-02) | `kModelHosts` = our CDN + `huggingface.co` mirror; redirect-only `kModelRedirectHosts` = `us.aws.cdn.hf.co` | MDL-01 / MDL-02 |
| — | Store billing | StoreKit / Play Billing inside the OS, not our HTTP client | Apple / Google | LIC-02 |

Nothing else may open a connection (`tools/ci/check_egress.sh`, allowlist in
`app/lib/core/network/model_hosts.dart`).

## What the model CDN / mirror can see (MDL-01)
Requests are only made when the app refreshes the catalog or the user starts a model download.
They never contain user content.

| Item | Sent? | Value / note |
|---|---|---|
| Client IP address | yes (unavoidable) | the device's public IP (or the carrier/VPN NAT) |
| TLS SNI + `Host` | yes | the catalog/model host name |
| Request line | yes | `GET /catalog/v1/catalog.json`, `GET /catalog/v1/catalog.json.sig`, `GET /<type>/<model file>` — public file names only |
| `User-Agent` | yes | `VaultVoice/1` (major version only; no OS, device model, build number) |
| `Accept` | yes | `*/*` |
| `Accept-Encoding`, `Content-Length: 0` | yes | added by `dart:io` |
| `Range` | model downloads only | byte offset for resume (MDL-02) |
| Cookies | **no** | the gateway client has no cookie jar; `Set-Cookie` is ignored |
| `Authorization` / tokens | **no** | public files only |
| Query parameters / fragments | **no** | rejected by catalog validation (`urls` must have none) |
| Device, install, advertising or user IDs | **no** | none exist in the app |
| Locale, timezone, app build, OS version | **no** | not in any header |
| Referer / Origin | **no** | not a browser |
| Request timing | yes (unavoidable) | when the app fetched which public file |

From this the operator can infer: "this IP downloaded the catalog / model X at time T with
VaultVoice". Mitigations: CDN access logs **disabled or ≤ 7 days retention** (configured when
the CDN is provisioned — PRODUCT-DECISION, ADR-MDL-01); no analytics, cookies or JS challenges
on file paths; the Hugging Face mirror is a third party whose logging we do not control (its
privacy policy applies) — it is only used when our CDN fails, and HF redirects to its own CDN
host (`*.cdn.hf.co`).

Automated evidence: `app/test/unit/models/catalog_repository_test.dart`
`[MDL-01/AC2]` asserts every catalog request is an https `GET` to an allowlisted host, only the
two manifest paths, no query/userinfo, no redirects followed, and exactly the headers
`User-Agent: VaultVoice/1` + `Accept: */*`. The on-device proxy capture is in
`docs/test-plans/device/MDL-01.md` (pending).

### Integrity (why a hostile CDN/mirror cannot hurt users)
The catalog is Ed25519-signed (pinned keys in the app, 2-key rotation), rollback-protected
(`issued_at` never older than the bundled / last accepted catalog), size-capped (1 MiB) and
schema-checked; model files are checked for exact size + SHA-256 from the signed catalog before
use. A bundled signed catalog keeps first launch and offline mode working.

## Model downloads (MDL-02)
Same request shape as the catalog (table above) plus `Range: bytes=<offset>-` on a resume and
`If-Range: <strong ETag>` when one was seen. Nothing else is added. The iOS background session
additionally sends `Accept-Language: *` (set explicitly so CFNetwork does not send the device
locale) and has cookies, cache and credential storage disabled. The download is started only
by a user action (tap "Download" or resume-on-launch of a download the user started).

### Redirect targets
`NetworkGateway.getStream` follows at most 5 redirects and checks **every hop before
requesting it**: https only, no userinfo, host in `kModelHosts` or — for redirect targets only —
`kModelRedirectHosts`. Any other target fails closed with `EgressDeniedFailure`; it is never
contacted and the downloader moves on to the next catalog URL (tests:
`app/test/unit/network/network_gateway_stream_test.dart`,
`app/test/unit/models/model_downloader_test.dart` → "redirects").

| Host | Role | Evidence (2026-10-13) | Added |
|---|---|---|---|
| `us.aws.cdn.hf.co` | Hugging Face Xet bridge CDN behind `huggingface.co/<repo>/resolve/<rev>/<file>` | `curl -I` of both pinned seed-model URLs (repeated 3×) → `302 Location: https://us.aws.cdn.hf.co/xet-bridge-us/<repo-id>/<sha>?…&Expires=…&Signature=…`; the target answers the file (`Content-Length` = catalog size, `ETag` = catalog sha256) | yes |
| `cas-bridge.xethub.hf.co`, `cdn-lfs.hf.co`, `cdn-lfs-us-1.hf.co`, `cdn-lfs-eu-1.hf.co` | other HF CDN names (resolve in DNS) | not observed as a redirect target from our network | **no** — add only after observing |
| regional `eu.aws.cdn.hf.co` / `ap.aws.cdn.hf.co` | possible regional variants | do not resolve (DNS) as of 2026-10-13 | no |

What the HF CDN sees: the device IP, `User-Agent: VaultVoice/1`, the public file path and the
signed query string Hugging Face generated (it contains `user_id=public`, an expiry, a signature
and an opaque `xip` value chosen by HF — we add no parameters). Same-host redirects on
`huggingface.co` (e.g. a moved repo, `307`) are allowed.

**iOS residual:** background `URLSession`s follow redirects without asking the app. The Dart
gateway therefore resolves and validates the chain first and hands the session the final URL;
the native delegate re-checks the current host on every progress callback and on completion
and discards the bytes (and cancels) if it is not allowlisted. A further redirect issued by an
allowlisted CDN to an unlisted host would still cause one request (public file path only, no
user content) before cancellation. To be confirmed by the device proxy capture
(`docs/test-plans/device/MDL-02.md`).

**Rejected:** `background_downloader` 9.6.4 (BSD-3-Clause, maintained) — follows up to 10
redirects natively without a hook and brings its own HTTP client outside the gateway
(ADR-MDL-02).

## Dependency review
| Name | Version | Purpose | Network? | Telemetry? | License | Last release | Decision |
|---|---|---|---|---|---|---|---|
| `cryptography` (Dart) | 2.9.0 (exact) | Ed25519 verify of the model catalog (`DartEd25519`, pure Dart) | no (grep: no `http`/`HttpClient`/`Socket` in `lib/`) | no | Apache-2.0 | 2025-11-21 | Accepted — ADR-MDL-01 |
| `crypto` (Dart, dart-lang) | 3.0.7 (exact) | streaming SHA-256 of model files; key ids | no | no | BSD-3-Clause | already a transitive dependency | Accepted — ADR-MDL-01 |
| `yaml` (Dart, dart-lang) | 3.1.4 (exact) | parse built-in / imported extraction profiles (PRF-01) | no (grep: no `http`/`HttpClient`/`Socket` in `lib/`) | no | MIT | already a transitive dependency (same version) | Accepted — PRF-01 |
| `mustache_template` (flutter/core-packages) | 2.0.5 (exact) | Markdown templates (EXP-01), strict mode | no (only `src/` imports; no `dart:io`/`http`) | no | BSD-2-Clause | 2026-06-09 (2.0.6 on 2026-09-15 is docs-only) | Accepted — ADR-EXP-01 |
| `characters` (Dart, dart-lang) | ^1.4.1 (Flutter SDK pin) | grapheme-safe slug/filename truncation (EXP-01/02) | no | no | BSD-3-Clause | already a transitive Flutter dependency | Accepted — ADR-EXP-01 |
| `unorm_dart` | 0.3.2 (exact) | NFC normalization of vault file names (EXP-02) | no (only its own `src/` imports; pure Dart tables) | no | MIT | 2025-10-01 (0.3.3 of 2026-10-04 is < 2 weeks old) | Accepted — EXP-02 (no Dart SDK API for Unicode normalization) |
| `cryptography` (Python, pyca) | 46.0.3 | `tools/model-catalog` signing CLI only (not shipped in the app) | no | no | Apache-2.0 OR BSD-3-Clause | 2025 | Accepted — ADR-MDL-01 |

## Models (license must allow our use and, for our CDN, redistribution — SEC-05)
| Model | Source (pinned revision) | License | Redistribution on our CDN |
|---|---|---|---|
| `ggml-tiny.en.bin` (Whisper tiny.en) | `huggingface.co/ggerganov/whisper.cpp` @ `5359861c739e955e79d9a303bcbc70fb988958b1` | MIT (OpenAI Whisper weights; whisper.cpp MIT) | allowed (keep license notice) |
| `qwen2.5-0.5b-instruct-q4_k_m.gguf` | `huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF` @ `9217f5db79a29953eb74d5343926648285ec7e67` | Apache-2.0 | allowed (keep LICENSE + NOTICE) — SEC-05 to confirm |
