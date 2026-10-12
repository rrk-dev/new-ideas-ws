# EXP-03 — Android Folder Access (Storage Access Framework)

**Workstream:** Export | **Phase:** 1 | **Size:** M | **Depends on:** FND-02 | **Source:** §5 Phase 1 (Scoped Storage)
**Status:** todo
**Skills:** vv-task-workflow, vv-markdown-vault-export, vv-flutter-architecture, vv-testing

## Goal
User picks any folder (e.g., Obsidian vault on internal storage or SD card) and the app can write there persistently.

## Scope
- [ ] `ACTION_OPEN_DOCUMENT_TREE` picker; `takePersistableUriPermission` for read/write.
- [ ] `DocumentsContract`-based create/overwrite/mkdir via a Pigeon platform channel (see skill reference; `DocumentFile.findFile` is too slow) (Dart `File` cannot write SAF URIs).
- [ ] Detect revoked permissions / removed SD card; prompt re-grant.
- [ ] Avoid `MANAGE_EXTERNAL_STORAGE` (Play policy).
- [ ] Verify compatibility with Obsidian's vault location and Syncthing/FolderSync folders.

## Acceptance Criteria
- Permission survives app restart and device reboot.
- Files written appear immediately in Obsidian Android.
