# Android: Storage Access Framework vault access (EXP-03)

Dart `dart:io` cannot write to SAF `content://` URIs. Implement a Kotlin host API via Pigeon
(`app/pigeons/saf_api.dart`); avoid third-party SAF plugins unless actively maintained.

## Pick & persist
```kotlin
val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
  addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
           Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
}
// onResult(treeUri):
contentResolver.takePersistableUriPermission(treeUri,
  Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
```
Store `treeUri.toString()` as `vault_targets.handle`. On every use check
`contentResolver.persistedUriPermissions.any { it.uri == treeUri && it.isWritePermission }`;
if missing → `revoked` (prompt re-pick). Max persisted grants per app: 128 (Android ≤ 10), 512 (Android 11+)
(AOSP limits). A grant is also lost if the user moves/deletes the folder — release unused ones with `releasePersistableUriPermission`.

## Write a file at a relative path
- Resolve/create each sub-folder with `DocumentsContract` (faster than `DocumentFile.findFile`,
  which lists the directory each call): query children via
  `DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)` with projection
  `COLUMN_DOCUMENT_ID, COLUMN_DISPLAY_NAME, COLUMN_MIME_TYPE`; create with
  `DocumentsContract.createDocument(cr, parentUri, Document.MIME_TYPE_DIR, name)`.
- Create file: `createDocument(cr, parentUri, "text/markdown", "note.md")`. `createDocument` never overwrites: a name collision yields " (1)"; separately,
  some providers change the extension for unmapped MIME types — use `"text/markdown"` and verify
  the returned display name; if the provider altered it, rename via `DocumentsContract.renameDocument`
  or fall back to `"application/octet-stream"`.
- Overwrite: open with `cr.openOutputStream(docUri, "wt")` (truncate). Mode `"w"` may or may not truncate
  depending on the DocumentsProvider → stale trailing bytes. Always use `"wt"`.
- Atomic-ish replace: write `.<name>.tmp` → `renameDocument` to final (delete existing first).
  If rename is unsupported by the provider, write directly with `"wt"` and verify size/hash.
- Do all IO on `Dispatchers.IO`; return results to Dart via Pigeon async.

## Notes
- Never request `MANAGE_EXTERNAL_STORAGE` (Play policy) or legacy `WRITE_EXTERNAL_STORAGE`.
- Obsidian Android vaults usually live under `Documents/` or a user folder on internal storage;
  SD-card vaults appear as a separate root; Syncthing/FolderSync folders work the same way.
- Test matrix: internal storage, SD card (removal → `unavailable`), Google Drive provider
  (should work but slow; mark "cloud provider" in UI), reboot persistence.
