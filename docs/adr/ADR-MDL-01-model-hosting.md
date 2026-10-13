# ADR-MDL-01 — Model hosting, signed catalog format and signing library

- **Status:** Proposed (the catalog format, signature scheme and libraries are implemented;
  the CDN provider/domain and the production signing key are owner decisions — see "Open")
- **Date:** 2026-10-12
- **Task:** MDL-01
- **Deciders:** Claude Code (implementer); pending independent verifier + owner (CDN)
- **Supersedes:** —

## Context
The app's only content-related network traffic is fetching public model files (Whisper `ggml-*.bin`,
GGUF LLMs, later VAD/diarization). Constraints (`AGENTS.md`, `vv-model-delivery`,
`vv-privacy-security`):
- Integrity: a modified catalog or model file must never be used (malicious GGUF → parser bugs).
- Privacy: no cookies, auth, identifiers or query params; the server should learn no more than
  "an IP fetched public file X with UA `VaultVoice/1`"; access logs off or shortest retention.
- Availability: downloads work when one host is down; the app works offline (bundled catalog).
- Licensing: we only redistribute models whose license allows it (SEC-05).
- All requests go through `NetworkGateway` (https only, host allowlist, no redirects followed).

## Options — hosting
1. **Own object storage + CDN** (e.g. S3/R2/GCS/Bunny behind our domain) — primary for catalog
   and model files.
2. **Hugging Face direct links only** — `resolve/<revision>/<file>` URLs.
3. **GitHub Releases** — release assets as files.

## Criteria (weights fixed before deciding)
| Criterion | Weight | Own CDN | HF only | GitHub Releases |
|---|---|---|---|---|
| Privacy control (logs, headers, no tracking cookies, retention) | 30% | 5 — we configure log retention / disable logging | 2 — third-party logs, policy outside our control | 2 |
| Availability / control over removals & renames | 25% | 5 — we own the objects | 2 — repo owners can delete/rename/gate files; rate limits | 3 |
| Allowlist stability (no cross-host redirects) | 15% | 5 — one stable host | 2 — redirects to `*.cdn.hf.co` (host set changes over time) | 2 — redirects to `objects.githubusercontent.com` |
| Cost / ops effort | 15% | 3 — egress cost, needs provisioning | 5 — free | 4 — free, 2 GB/file limit |
| License compliance | 15% | 4 — we must check redistribution rights (SEC-05) | 5 — upstream distributes | 4 |
| **Weighted** | | **4.55** | **2.90** | **2.85** |

## Options — catalog signing
1. **Ed25519 detached signature over exact `catalog.json` bytes**, `.sig` = small JSON envelope
   `{"alg","key_id","sig"}`, up to 2 pinned public keys in the app.
2. Minisign/signify format — same primitive, extra parser, no gain for a single producer.
3. TLS only (no signature) — trusts the CDN and every mirror; rejected (task requires signing).

## Options — Dart Ed25519 implementation
1. **`cryptography` 2.9.0 (`DartEd25519`, pure Dart)** — Apache-2.0, published 2025-11-21, no
   network/telemetry code, checks `s < L` (malleability) and point decoding; same behaviour on
   iOS/Android/host; no native build.
2. `pinenacl` — pure Dart, smaller community.
3. Native (libsodium via `vv_bridge`) — fastest, but adds a native lib for a once-per-launch
   verify of < 1 MiB; violates "smallest change".
SHA-256 for model files: `crypto` 3.0.7 (dart-lang, BSD-3, already transitive) — streaming.
CLI: Python `cryptography` 46.0.3 (pyca, Apache-2.0/BSD) — the only non-stdlib dependency.

## Evidence
- Seeded entries verified 2026-10-12: `ggml-tiny.en.bin` downloaded from
  `huggingface.co/ggerganov/whisper.cpp` @ `5359861c…` — size 77 704 715, sha256 `921e4cf8…b1f`,
  computed locally and equal to the HF LFS oid. `qwen2.5-0.5b-instruct-q4_k_m.gguf` @ `9217f5db…`
  — size 491 400 032, sha256 `74a4da8c…a9db` from HF LFS metadata (the local download was
  blocked by the corporate proxy; re-hash is a follow-up, MDL-05).
- HF `resolve` URLs answer `302 Found` → `us.aws.cdn.hf.co/xet-bridge-us/…` (observed
  2026-10-12 for `ggml-tiny.en.bin`; headers `X-Linked-Size` / `X-Linked-ETag` = size / sha256),
  a different host that the gateway deliberately does not follow → HF works as a mirror only if MDL-02 resolves redirects
  against the allowlist (or we mirror the files ourselves).
- Tests: `app/test/unit/models/*_test.dart`, `tools/model-catalog/tests/test_catalog.py`.

## Decision
- **Hosting: own object storage + CDN is the primary** for `catalog.json(.sig)` and model files;
  **Hugging Face pinned-revision URLs are mirrors** (listed after the primary in `urls`).
  Before a model is copied to our CDN its license must allow redistribution (SEC-05).
- **Catalog: Ed25519 over exact bytes, JSON envelope, ≤ 2 pinned keys, rollback floor =
  max(bundled `issued_at`, last accepted `issued_at`), unknown `schema` rejected, 1 MiB cap,
  min app version enforced.** Signed bundled fallback in `app/assets/catalog/`.
- **Libraries:** `cryptography` 2.9.0 (Dart), `crypto` 3.0.7 (Dart), `cryptography` 46.0.3
  (Python CLI), pinned exactly.

## Open (owner decisions — PRODUCT-DECISION)
1. CDN provider and domain. Placeholder host `models.vaultvoice.example` (`kModelCdnHost`,
   `kCatalogBaseUris`, catalog `urls`). Requirements for whichever provider is chosen: HTTPS only,
   `Range` support, no cookies/auth/query tokens, access logs disabled or ≤ 7 days, no
   analytics/WAF JS challenges on the file paths, CORS not needed.
2. Production signing key: generate offline (`catalog.py keygen` on an offline machine / HSM),
   store the private key in a password manager / CI secret (`VV_CATALOG_SIGNING_KEY`), replace the
   dev key in `catalog_keys.dart`, re-sign. The shipped dev key `vv-catalog-dev-2026a` must not be
   in a release build.
3. Whether to mirror model files on our CDN at all for models whose license is unclear (else HF only).

## Consequences
- Positive: integrity is independent of TLS/CDN/mirror trust; offline first launch works;
  catalog requests carry no identifiers (tested); format shared by app and CLI.
- Negative / risks: until the CDN exists the catalog is never refreshed (bundled only) and model
  downloads rely on HF redirects (MDL-02); persisting the rollback floor + last catalog needs DB
  storage (MDL-05); key loss requires an app update (mitigated by 2-key rotation).
- Follow-up tasks: MDL-05 (persist catalog state + cached catalog, production key, re-hash GGUF),
  MDL-02 (redirect handling against allowlist), SEC-02 (egress audit with proxy capture).
