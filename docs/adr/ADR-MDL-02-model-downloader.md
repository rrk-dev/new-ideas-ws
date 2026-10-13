# ADR-MDL-02 — Model downloader: transport, background execution and redirect policy

- **Status:** Proposed (implemented + host-tested; background behaviour on real iOS/Android
  devices not yet measured — `docs/test-plans/device/MDL-02.md`)
- **Date:** 2026-10-13
- **Task:** MDL-02
- **Deciders:** Claude Code (implementer); pending independent verifier
- **Supersedes:** —

## Context
Models are 75 MB – 2+ GB. Requirements (`vv-model-delivery`, `vv-background-execution`,
`vv-privacy-security`, task MDL-02): background continuation on iOS and Android, HTTP Range
resume after an app kill, retry 1 s → 60 s (max 8), pause/cancel, Wi-Fi-only default with
cellular opt-in, free space ≥ `size × 1.1 + 200 MB`, streamed SHA-256 off the UI isolate, atomic
install + `models_installed`, backup exclusion — and **every network request goes through the
`NetworkGateway` allowlist**.

New constraint found while implementing: the Hugging Face mirror URLs in the signed catalog
(`huggingface.co/<repo>/resolve/<rev>/<file>`) answer `302` to a signed URL on
`us.aws.cdn.hf.co` (checked 2026-10-13 with `curl -I` for both seed models). That host is not in
`kModelHosts`, so the downloader must follow redirects itself and validate each target, or the
mirror is unusable.

## Options
1. **`background_downloader` 9.6.4** (pub, BBFlight LLC, BSD-3-Clause, released
   2026-10-07, actively maintained). Native URLSession / WorkManager, pause/resume, Wi-Fi-only,
   retries.
2. **Native per platform, Dart owns policy** — iOS background `URLSession` (download tasks with
   `Range`), Android in-process Dart stream through the gateway kept alive by a `dataSync`
   foreground service; redirects resolved and validated by the Dart gateway.
3. **Pure Dart everywhere** (gateway stream, no native) — simplest, fully host-testable.

## Criteria (weights fixed before deciding)
| Criterion | Weight | 1 `background_downloader` | 2 Native + Dart policy | 3 Pure Dart |
|---|---|---|---|---|
| Privacy: every hop allowlisted, fail closed, single egress policy | 35% | 1 — follows up to 10 redirects natively with no hook (source: `file_downloader.dart` "Redirects are followed automatically (up to 10 redirects)"); its own HTTP client bypasses the gateway; extra deps (`connectivity_plus`, `mime`, `logging`) | 4 — Dart gateway validates every hop before the native request; iOS re-checks the host natively (background sessions follow redirects on their own) | 5 |
| Background continuation (AC3: 2 GB in background, both OSes) | 30% | 5 | 4 — iOS: OS-managed background session survives suspension/termination; Android: FGS keeps the Dart isolate alive (6 h/24 h `dataSync` budget on API 35+) | 1 — iOS suspends within ~30 s |
| Resume after kill (AC1) | 15% | 4 | 4 — partial length is the offset (Android/host); iOS resume data / native completion recorded until acked | 4 |
| Testability on host (no devices here) | 10% | 2 | 4 — all policy in Dart, tested against a local HTTP server; native glue small | 5 |
| Maintenance / integration effort | 10% | 4 | 2 — ~400 lines Swift/Kotlin we own | 5 |
| **Weighted** | | **2.9** | **3.9** | **3.6** |

## Decision
**Option 2.** Policy lives in Dart (`ModelDownloader`, `features/models/data/`):
preconditions, partial-file + sidecar layout, retry schedule, integrity check in an isolate
(`verifyModelFileInIsolate` → MDL-01 `verifyModelBytes`), atomic `rename` into
`models/<id>/<file>`, `models_installed` upsert. Transports:
- `GatewayDownloadTransport` (Android, host, tests): `NetworkGateway.getStream` with
  `Range: bytes=<partial length>-` (+ `If-Range` with a strong ETag); 200 → restart from zero,
  206 with wrong `Content-Range` → reject, 416 → complete-or-restart. Android keeps the process
  alive with `ModelDownloadService` (FGS type `dataSync`, `onTimeout` → stop; resume on next
  launch).
- `BackgroundSessionTransport` (iOS): the gateway resolves the redirect chain (validated), then
  `ModelDownloadSession` (background `URLSessionConfiguration`, no cookies/cache/credentials,
  `Accept-Language: *`, cellular per request) downloads `Range: bytes=<offset>-` to a temp file
  and appends it to the partial (206) or replaces it (200) before the delegate returns. Hosts are
  re-checked on every progress callback and on completion; an unlisted host cancels and discards.
  Outcomes persist in `UserDefaults` until Dart acks them, so a download that completed while
  the app was dead is verified + installed on the next launch.
- **Redirect policy** (`NetworkGateway.getStream`): ≤ 5 hops; each target must be https, no
  userinfo, and in `allowedHosts` or `redirectHosts` (redirect-only, never contacted directly).
  Anything else → `EgressDeniedFailure`, the target is never requested, the next catalog URL is
  tried, no backoff. `kModelRedirectHosts = {us.aws.cdn.hf.co}` — only the host actually
  observed; see `docs/privacy-audit.md` → "Redirect targets".
- Background downloads are only started from a user action in the foreground (tap / resume on
  launch), never from the background.

## Consequences
- No new pub dependency. Native code: `app/ios/Runner/ModelDownload/ModelDownloadPlugin.swift`,
  `app/android/.../modeldownload/ModelDownload{Plugin,Service}.kt`.
- `tools/ci/check_egress.sh` allowlists `app/ios/Runner/ModelDownload/` (the only native file
  using `URLSession`). Android native code uses no network API.
- Android manifest gains `INTERNET`, `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS` (notification permission prompt is the
  model-management UI's job, MDL-03; without it the FGS still runs, notification hidden).
- iOS residual risk: a background session follows a *second* redirect on its own before our
  delegate sees it; the request to that host has been made (no user content, only the public
  file path) but its bytes are discarded. Mitigated by handing over the already-resolved final
  URL (HF CDN answers 200/206 directly). Documented in `docs/privacy-audit.md`.
- Android ≥ 15 `dataSync` budget (6 h / 24 h) caps a single background session; Range resume
  covers the rest. A user-initiated data transfer job (API 34+) is a possible later upgrade.
- The free-space rule is applied to the *remaining* bytes (`remaining × 1.1 + 200 MB`), equal
  to the spec for a fresh download and not over-demanding on resume.

## Open
- Device measurements (AC3) on iPhone + Android: `docs/test-plans/device/MDL-02.md`.
- Regional Hugging Face CDN hosts (EU/AP) not observed from our network; add after a capture.
