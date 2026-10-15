# MDL-02 — Resumable Model Downloader

**Workstream:** Model Delivery | **Phase:** 2 | **Size:** M | **Depends on:** MDL-01, FND-04 | **Source:** §5 Phase 2
**Status:** review
**Skills:** vv-task-workflow, vv-model-delivery, vv-background-execution, vv-local-database, vv-privacy-security, vv-testing

## Goal
Download multi-GB models reliably on first launch and on demand.

## Scope
- [x] Background-capable downloads: iOS `URLSession` background configuration; Android WorkManager / DownloadManager (via `background_downloader` or native).
- [x] HTTP range resume, retry with backoff, pause/cancel.
- [x] Wi-Fi-only default with cellular opt-in; show size up front.
- [x] Free-space check (model size × 1.1 + 200 MB) before starting.
- [x] SHA-256 verify after download; atomic move into models dir; record in `models_installed`.
- [x] Exclude models from iCloud/Google backups (`isExcludedFromBackup`, `android:fullBackupContent` rules).

## Acceptance Criteria
- Killing the app mid-download resumes from last byte on relaunch.
- Corrupted file (hash mismatch) is deleted and retried.
- 2 GB model downloads in background on both platforms.

## Completion Notes
- **Agent:** Claude Code · **Branch:** task/MDL-02-model-downloader · **Date:** 2026-10-13
- **Summary:** `ModelDownloader` (`app/lib/features/models/data/model_downloader.dart`):
  `models/.partial/<id>` + sidecar (partial length = resume offset), preconditions (free space
  `remaining × 1.1 + 200 MB`, Wi-Fi-only default + per-download/settings cellular opt-in,
  low-power confirmation, offline), every catalog URL per attempt then backoff 1 s → 60 s × 8
  (`domain/download_policy.dart`), pause/cancel, size + SHA-256 in `Isolate.run`
  (`verifyModelFileInIsolate` → MDL-01 `verifyModelBytes`), mismatch → delete + one re-download
  from zero, atomic `rename` to `models/<id>/<file>` + `models_installed` upsert (relative path),
  backup exclusion of `models/` and `models/<id>/`. `NetworkGateway.getStream`
  (`core/network/network_gateway.dart`): streamed GET, ≤ 5 redirects, every hop https +
  allowlisted (`redirectHosts` = redirect-only `kModelRedirectHosts = {us.aws.cdn.hf.co}`,
  observed for both seed models) — unlisted targets fail closed and are never contacted.
  Transports: `GatewayDownloadTransport` (Range / If-Range, 200/206/416 handling; Android + host)
  and `BackgroundSessionTransport` (iOS: gateway-resolved URL → native background session).
  Native: `app/ios/Runner/ModelDownload/ModelDownloadPlugin.swift` (background `URLSession`,
  host re-check, free space, `isExcludedFromBackup`, NWPathMonitor),
  `app/android/.../modeldownload/ModelDownload{Plugin,Service}.kt` (StatFs, connectivity,
  `dataSync` FGS with `onTimeout`); manifest permissions. Riverpod wiring
  `download_providers.dart`; `App` resumes pending downloads on launch. Host tests use a real
  local HTTP server (`test/helpers/model_download_server.dart`); the kill test runs the first
  download in a separate isolate and `Isolate.kill`s it mid-transfer. Native code was not built
  here (no Xcode / Android SDK) — CI `android`/`ios` jobs and the device rows cover it.
- **Acceptance evidence:**
  - AC1: ⏳ test: [MDL-02/AC1]; device: docs/test-plans/device/MDL-02.md
  - AC2: ✅ test: [MDL-02/AC2]
  - AC3: ⏳ test: [MDL-02/AC3]; device: docs/test-plans/device/MDL-02.md
- **Decisions:** ADR-MDL-02-model-downloader (Proposed — native + Dart-policy transport;
  `background_downloader` rejected because it follows redirects natively without a hook)
- **Follow-ups:** notes below (MDL-03, SEC-02); no new task
- **Privacy checklist:** network code only in `core/network/` and `features/models/data/` +
  `app/ios/Runner/ModelDownload/` (egress allowlist extended with justification;
  `check_egress.sh` OK); no content logged (no logging added); no new dependencies (no pub
  packages; `background_downloader` reviewed and rejected in `docs/privacy-audit.md`); model files
  under `vv/models/`, excluded from backup; recording policy check passes (no recording code).

## Follow-ups
- **MDL-03 note:** the model screen should (a) show `ModelDownloader.plan()` (size, free space,
  blocks) before starting, (b) ask for cellular / low-power consent and persist
  `models.allow_cellular_downloads` in `settings`, (c) request `POST_NOTIFICATIONS` (Android 13+)
  before the first download so the FGS progress notification is visible.
- **SEC-02 note:** add the in-app "Network activity" log at `NetworkGateway.getStream` (one
  entry per hop) and on `bgStart` for the iOS session; include the redirect-target rows of
  `docs/privacy-audit.md` in the proxy capture.
- **Note:** DB enum `ModelType` (FND-04) has `diarization` and no `coremlEncoder`; the downloader
  maps `diarization-seg/emb → diarization`, `coreml-encoder → stt`. If MDL-03 needs to
  distinguish them, extend the DB enum with a migration.

## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ (0 changed) · analyze ✅ (no issues) · tests ✅ (785 passed, 24 skipped, coverage 93.2% of 4708 gated lines, min 80%) · native smoke ✅ (host ctest 9 passed / 14 skipped / 0 failed, includes `vv_crash`) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51, success, `67b6fcf`) and https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638136574 (run 50, success)
- **Acceptance criteria:**
  - AC1: ✅ re-ran `[MDL-02/AC1]`. An isolate is killed mid-download; relaunch reads the partial length and the next request is `Range: bytes=<have>-` with body length `size - have`, then the model installs. Pause/resume uses the same offset. Device force-kill rows are blank.
  - AC2: ✅ re-ran `[MDL-02/AC2]`. One corrupted download is deleted and fetched again from byte 0 (no `Range`); the second attempt installs. A second mismatch leaves no file and no `models_installed` row. Checked it fails when the first mismatch returns immediately instead of retrying. Device corrupt-file row is blank.
  - AC3: ✅ re-ran `[MDL-02/AC3]`. The iOS transport gives the background session only the gateway-resolved final URL, `Range`, `allowCellular: false`, and the allowlist; a redirect to an unlisted host never calls `bgStart`. A real 2 GB background run is the device rows, which are blank. No Xcode or Android SDK here.
- **Adversarial checks:** Unlisted redirect is a non-retryable denial and the evil host is not contacted. A server that ignores `Range` still installs a file that matches the catalog hash. Cancel deletes the partial. Free-space math is `remaining × 1.1 + 200 MB`. `check_egress.sh` OK (redirect host is allowlisted). No new pub dependency. `tasks.py verify MDL-02 --run` short-circuits on pending device rows; tagged tests passed in the full suite.
- **Skill/rule compliance:** Downloads use `NetworkGateway.getStream` (≤ 5 hops, https + allowlist) or the iOS background session after that resolution. Models install by rename under `vv/models/` and backup exclusion is recorded. Wi-Fi-only default is in the plan. ADR-MDL-02 Proposed; `background_downloader` rejected because it follows redirects with no hook.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/MDL-02.md has no PASS result with a date; AC3: still pending (⏳) — cannot be done; AC3: device row in docs/test-plans/device/MDL-02.md has no PASS result with a date; dependency MDL-01 is not done; dependency FND-04 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
- Codex review 2026-10-15 (open): iOS ModelDownloadPlugin.swift:272 validates redirects only after contact; needs a transport that rejects unauthorized redirects before connecting (native, device).
