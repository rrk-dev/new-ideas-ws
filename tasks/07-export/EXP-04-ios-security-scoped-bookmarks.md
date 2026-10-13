# EXP-04 — iOS Folder Access (Security-Scoped Bookmarks)

**Workstream:** Export | **Phase:** 1 | **Size:** M | **Depends on:** FND-02 | **Source:** §5 Phase 1 (Document Picker / Security Scoped Bookmarks)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-flutter-architecture, vv-testing

## Goal
User picks a folder in Files (On My iPhone, iCloud Drive, third-party providers) and the app writes there persistently.

## Scope
- [ ] `UIDocumentPickerViewController` folder mode; store bookmark data; resolve + `startAccessingSecurityScopedResource` on each write; handle stale bookmarks.
- [ ] Use `NSFileCoordinator` for writes (iCloud Drive / Obsidian Sync safety).
- [ ] Obsidian vault on iOS lives in `On My iPhone/Obsidian/<vault>` or iCloud — verify both.
- [ ] Handle iCloud files not downloaded (placeholders) when updating existing notes.
- [ ] Also expose the app's own Documents folder in Files (`UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`) as a default target.

## Acceptance Criteria
- Access persists across restarts and app updates.
- Written notes appear in Obsidian iOS without manual refresh in both local and iCloud vaults.
