# MDL-02 — Resumable Model Downloader

**Workstream:** Model Delivery | **Phase:** 2 | **Size:** M | **Depends on:** MDL-01, FND-04 | **Source:** §5 Phase 2
**Status:** todo
**Skills:** vv-task-workflow, vv-model-delivery, vv-background-execution, vv-local-database, vv-privacy-security, vv-testing

## Goal
Download multi-GB models reliably on first launch and on demand.

## Scope
- [ ] Background-capable downloads: iOS `URLSession` background configuration; Android WorkManager / DownloadManager (via `background_downloader` or native).
- [ ] HTTP range resume, retry with backoff, pause/cancel.
- [ ] Wi-Fi-only default with cellular opt-in; show size up front.
- [ ] Free-space check (model size × 1.1 + 200 MB) before starting.
- [ ] SHA-256 verify after download; atomic move into models dir; record in `models_installed`.
- [ ] Exclude models from iCloud/Google backups (`isExcludedFromBackup`, `android:fullBackupContent` rules).

## Acceptance Criteria
- Killing the app mid-download resumes from last byte on relaunch.
- Corrupted file (hash mismatch) is deleted and retried.
- 2 GB model downloads in background on both platforms.
