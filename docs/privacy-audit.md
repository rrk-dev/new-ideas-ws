# Privacy audit

Living record of every network use and every dependency review (`vv-privacy-security`).
SEC-02 owns the full egress audit (proxy capture of an e2e run); sections below are added by
the task that introduces the network use or dependency.

## Network uses
| # | What | Who calls it | Hosts | Task |
|---|---|---|---|---|
| 1 | Model catalog `catalog.json` + `catalog.json.sig` | `CatalogRepository.refresh` via `NetworkGateway` | `kModelCdnHost` (placeholder `models.vaultvoice.example`, PRODUCT-DECISION) | MDL-01 |
| 2 | Model files (`urls` in the signed catalog) | downloader via `NetworkGateway` (MDL-02) | `kModelHosts` = our CDN + `huggingface.co` mirror | MDL-01 / MDL-02 |
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

## Dependency review
| Name | Version | Purpose | Network? | Telemetry? | License | Last release | Decision |
|---|---|---|---|---|---|---|---|
| `cryptography` (Dart) | 2.9.0 (exact) | Ed25519 verify of the model catalog (`DartEd25519`, pure Dart) | no (grep: no `http`/`HttpClient`/`Socket` in `lib/`) | no | Apache-2.0 | 2025-11-21 | Accepted — ADR-MDL-01 |
| `crypto` (Dart, dart-lang) | 3.0.7 (exact) | streaming SHA-256 of model files; key ids | no | no | BSD-3-Clause | already a transitive dependency | Accepted — ADR-MDL-01 |
| `cryptography` (Python, pyca) | 46.0.3 | `tools/model-catalog` signing CLI only (not shipped in the app) | no | no | Apache-2.0 OR BSD-3-Clause | 2025 | Accepted — ADR-MDL-01 |

## Models (license must allow our use and, for our CDN, redistribution — SEC-05)
| Model | Source (pinned revision) | License | Redistribution on our CDN |
|---|---|---|---|
| `ggml-tiny.en.bin` (Whisper tiny.en) | `huggingface.co/ggerganov/whisper.cpp` @ `5359861c739e955e79d9a303bcbc70fb988958b1` | MIT (OpenAI Whisper weights; whisper.cpp MIT) | allowed (keep license notice) |
| `qwen2.5-0.5b-instruct-q4_k_m.gguf` | `huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF` @ `9217f5db79a29953eb74d5343926648285ec7e67` | Apache-2.0 | allowed (keep LICENSE + NOTICE) — SEC-05 to confirm |
