# EXP-04 — iOS Folder Access (Security-Scoped Bookmarks)

**Workstream:** Export | **Phase:** 1 | **Size:** M | **Depends on:** FND-02 | **Source:** §5 Phase 1 (Document Picker / Security Scoped Bookmarks)
**Status:** review
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-flutter-architecture, vv-testing

## Goal
User picks a folder in Files (On My iPhone, iCloud Drive, third-party providers) and the app writes there persistently.

## Scope
- [x] `UIDocumentPickerViewController` folder mode; store bookmark data; resolve + `startAccessingSecurityScopedResource` on each write; handle stale bookmarks.
- [x] Use `NSFileCoordinator` for writes (iCloud Drive / Obsidian Sync safety).
- [~] Obsidian vault on iOS lives in `On My iPhone/Obsidian/<vault>` or iCloud — verify both. deferred → device run: rows in `docs/test-plans/device/EXP-04.md` (no iPhone/Xcode available to the implementer).
- [x] Handle iCloud files not downloaded (placeholders) when updating existing notes.
- [x] Also expose the app's own Documents folder in Files (`UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`) as a default target.

## Acceptance Criteria
- Access persists across restarts and app updates.
- Written notes appear in Obsidian iOS without manual refresh in both local and iCloud vaults.

## Completion Notes
- **Review gaps (macOS host):** `ModelDownloadHost` now reads `NWPathMonitor.currentPath` on demand (no shared `latestPath`) and cancels the monitor on teardown; `BookmarkHostApiImpl.child` rejects symlink escapes (resolved path must stay under the resolved vault root). Limitation: the Pigeon `BookmarkHostApi` only carries a refreshed bookmark in `checkAccess` (`BookmarkAccess.refreshedBookmark`, which the Dart writer adopts); the other operations return plain values, so a stale bookmark discovered during a write is refreshed on the next `checkAccess` instead of being forwarded without a breaking API change. Swift was only syntax-checked (`swiftc -parse`); a full macOS build is deferred (CI jobs do not build macOS).
- **Agent:** Claude Code · **Branch:** task/EXP-04-ios-bookmarks (stacked on EXP-03: shares the extended
  `VaultWriter` interface, `VaultPath`, `VaultAccessGuard`, error mapping and the pigeon dev dependency) ·
  **Date:** 2026-10-12
- **Summary:** Pigeon host API `app/pigeons/bookmark_api.dart` (pigeon 29.0.8; generated
  `lib/features/export/data/pigeon/bookmark_api.g.dart` + `ios/Runner/BookmarkApi.g.swift`, error class
  `BookmarkPigeonError`). Swift `ios/Runner/BookmarkHostApiImpl.swift`: `UIDocumentPickerViewController(forOpeningContentTypes:
  [.folder], asCopy: false)`, base64 `bookmarkData(options: [])`, resolve + `startAccessingSecurityScopedResource` per call
  (short windows; in-container URLs allowed unscoped), stale bookmarks re-created and returned from `checkAccess`,
  writes/mkdir/delete through `NSFileCoordinator` (`.forReplacing` + `.atomic`, `.forDeleting`), existence checks via
  coordinated `.immediatelyAvailableMetadataOnly` reads, iCloud items not `.current` (or `.<name>.icloud` placeholders) →
  `startDownloadingUbiquitousItem` + `unavailable` (outbox retry), Cocoa errors → shared content-free codes, IO on a serial
  queue. Registered in `AppDelegate.didInitializeImplicitFlutterEngine`; both Swift files added to the Runner target in
  `project.pbxproj`. `Info.plist`: `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` (Documents = default
  target via `AppLocalVaultWriter`). Dart: `BookmarkVaultWriter` (switches to refreshed bookmarks, `onRefreshed` hook) and
  `BookmarkFolderAccess`; iOS wiring in `export_providers.dart`. Tests: `test/unit/export/bookmark_vault_writer_test.dart`
  with `test/fakes/fake_bookmark_host_api.dart`; on-device `integration_test/vault_folder_bookmark_test.dart`.
  **Verified locally:** the two Swift files type-check (`swiftc -typecheck -swift-version 5 -target arm64-apple-ios16.0-macabi`
  against the Command Line Tools macOS SDK's iOSSupport UIKit, with a stub `Flutter` module). **Not verified:** iOS build
  (no Xcode — CI `ios` job), `engineBridge.applicationRegistrar` API (taken from the pigeon 29.0.8 example app), any device run.
- **Acceptance evidence:**
  - AC1: ⏳ test: [EXP-04/AC1]; device: docs/test-plans/device/EXP-04.md
  - AC2: ⏳ test: [EXP-04/AC2]; device: docs/test-plans/device/EXP-04.md
- **Decisions:** none requiring an ADR (Pigeon + bookmarks/NSFileCoordinator prescribed by the skills). Engineering
  default: a placeholder iCloud note is never overwritten before it is downloaded (avoids conflict copies).
- **Follow-ups:** none new — persisting refreshed bookmarks into `vault_targets` is EXP-05 (needs FND-04); the re-grant
  prompt UI is APP-03 / EXP-06.
## Verification Report
- **Verifier:** Cursor · **Implementer:** Claude Code · **Date:** 2026-10-14 · **Commit:** 67b6fcf2fc125f4493ad542dda29244716602e31
- **Verdict:** PASS
- **Gates:** format ✅ · analyze ✅ · tests ✅ (780 passed, 29 skipped; coverage not re-measured locally, CI test job gates ≥80% and is green) · native smoke n/a (no native/bridge change) · egress ✅ · recording policy ✅ · CI run: https://github.com/rrk-dev/new-ideas-ws/actions/runs/38638167858 (run 51 of ci, commit 67b6fcf, completed successfully; run 50 also succeeded)
- **Acceptance criteria:**
  - AC1: ✅ host re-ran `[EXP-04/AC1]`. Tests assert a stored bookmark writes after a Dart restart with no second picker, a stale bookmark is refreshed and adopted by the writer, and an unresolvable bookmark is `revoked` and re-granted via the picker. Device rows in `docs/test-plans/device/EXP-04.md` (restart, reboot, app update, revocation, Files default target) are blank (⏳). Mutation: stopped adopting the refreshed bookmark; the stale-bookmark test failed (`Expected: bm-local+fresh`); restored
  - AC2: ✅ host re-ran `[EXP-04/AC2]`; local and iCloud folders receive the exact path and bytes; an iCloud placeholder starts a download, returns `unavailable`, writes nothing, and a retry after download leaves exactly one file. Obsidian local/iCloud rows are blank (⏳). No Xcode or iOS simulator on this machine (doctor). `Info.plist` has `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. Swift uses `UIDocumentPicker` folder mode, security-scoped access, and `NSFileCoordinator`. CI run 51 built iOS on this sha
- **Adversarial checks:** offline provider is `unavailable` not `revoked`; host errors never report ok; cancelling the picker is not a failure; a SAF folder is not treated as a bookmark. Placeholder notes are not overwritten before download.
- **Skill/rule compliance:** Pigeon + bookmarks/`NSFileCoordinator` as prescribed. Obsidian vault locations are `[~] deferred` to the device checklist. No credentials or certificates.
- **Issues found:** none
- **Pending for done:** AC1: still pending (⏳) — cannot be done; AC1: device row in docs/test-plans/device/EXP-04.md has no PASS result with a date; AC2: still pending (⏳) — cannot be done; AC2: device row in docs/test-plans/device/EXP-04.md has no PASS result with a date; dependency FND-02 is not done; FND-03 (CI / test framework) must be done before any non-bootstrap task; QA-01 (CI / test framework) must be done before any non-bootstrap task
