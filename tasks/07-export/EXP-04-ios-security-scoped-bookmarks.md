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
