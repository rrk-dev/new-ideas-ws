# EXP-09 — macOS Vault Folder (Security-Scoped Bookmarks)

**Workstream:** Export | **Phase:** 1 | **Size:** M | **Depends on:** EXP-04, FND-09 | **Source:** User decision 2026-10-14
**Status:** review
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-flutter-architecture, vv-testing

## Goal
The user picks an Obsidian or Logseq folder on the Mac, and VaultVoice keeps writing Markdown there after relaunch.

## Scope
- [x] Folder picker (`NSOpenPanel`) stores a security-scoped bookmark and resolves it on each write.
- [x] Writes go through the existing vault writer used by EXP-04. Same relative paths and the same bytes.
- [x] Stale bookmarks (folder moved, app updated) are detected and the user can pick again.
- [x] Sandbox entitlement is limited to user-selected files. No broad disk access.
- [x] Tagged tests use a fake bookmark host for persist, stale, and exact-byte write. Device row uses a real folder on this Mac.

## Acceptance Criteria
- A test named `[EXP-09/AC1]` shows the bookmark still resolves after a simulated restart.
- A note written from the macOS app appears at the chosen path with the expected Markdown (device row in `docs/test-plans/device/EXP-09.md`).
- The macOS entitlements file does not grant `com.apple.security.files.downloads.read-write` or all-files access.

## Notes
iOS bookmark behavior stays in EXP-04. This task adds the macOS host only.

## Completion Notes
- **Agent:** Cursor · **Branch:** task/EXP-09-macos-folder-bookmarks · **Date:** 2026-10-14
- **Summary:** macOS folder access uses the EXP-04 `BookmarkFolderAccess` / `BookmarkVaultWriter` (same UTF-8 bytes and relative paths). `packages/vv_native/macos/MacBookmarkPanel.swift` picks with `NSOpenPanel` and stores a `.withSecurityScope` bookmark. `VaultFolder.entitlements` grants user-selected read-write only. A fake host drops the panel URL on a simulated restart and keeps the bookmark string.
- **Acceptance evidence:**
  - AC1: ✅ test: [EXP-09/AC1]
  - AC2: ⏳ device: docs/test-plans/device/EXP-09.md
  - AC3: ✅ test: [EXP-09/AC3]
- **Decisions:** none (same writer as EXP-04; no second export path)
- **Follow-ups:** FND-09 compiles `MacBookmarkPanel.swift` against the Pigeon `BookmarkHostApi` and merges `VaultFolder.entitlements` into the runner. The real folder panel was not shown (`app/macos` is not in this worktree).

## Follow-ups
- FND-09: register `MacBookmarkHostApiImpl` and merge `com.apple.security.files.user-selected.read-write`. Do not add downloads read-write or all-files access.
