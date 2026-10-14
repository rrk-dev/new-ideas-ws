# EXP-09 — macOS Vault Folder (Security-Scoped Bookmarks)

**Workstream:** Export | **Phase:** 1 | **Size:** M | **Depends on:** EXP-04, FND-09 | **Source:** User decision 2026-10-14
**Status:** in-progress
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-flutter-architecture, vv-testing

## Goal
The user picks an Obsidian or Logseq folder on the Mac, and VaultVoice keeps writing Markdown there after relaunch.

## Scope
- [ ] Folder picker (`NSOpenPanel`) stores a security-scoped bookmark and resolves it on each write.
- [ ] Writes go through the existing vault writer used by EXP-04. Same relative paths and the same bytes.
- [ ] Stale bookmarks (folder moved, app updated) are detected and the user can pick again.
- [ ] Sandbox entitlement is limited to user-selected files. No broad disk access.
- [ ] Tagged tests use a fake bookmark host for persist, stale, and exact-byte write. Device row uses a real folder on this Mac.

## Acceptance Criteria
- A test named `[EXP-09/AC1]` shows the bookmark still resolves after a simulated restart.
- A note written from the macOS app appears at the chosen path with the expected Markdown (device row in `docs/test-plans/device/EXP-09.md`).
- The macOS entitlements file does not grant `com.apple.security.files.downloads.read-write` or all-files access.

## Notes
iOS bookmark behavior stays in EXP-04. This task adds the macOS host only.
