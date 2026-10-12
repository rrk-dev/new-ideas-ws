# iOS: folder access with security-scoped bookmarks (EXP-04)

Implement in Swift behind a Pigeon host API (`app/pigeons/bookmark_api.dart`).

## Pick
```swift
let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
picker.allowsMultipleSelection = false
// delegate didPickDocumentsAt urls: [URL]
```

## Create & persist bookmark
```swift
guard url.startAccessingSecurityScopedResource() else { throw VaultError.accessDenied }
defer { url.stopAccessingSecurityScopedResource() }
let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
// .withSecurityScope is macOS-only; on iOS plain bookmarkData from a picked URL carries scope.
```
Store base64 `data` in `vault_targets.handle` (DB is encrypted — SEC-01).

## Resolve & use (every write)
```swift
var stale = false
let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
guard url.startAccessingSecurityScopedResource() else { return .revoked }   // VaultAccess enum
defer { url.stopAccessingSecurityScopedResource() }
if stale { save(try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)) }
```
Keep access windows short (start → write → stop).

## Coordinated, atomic writes (iCloud Drive / Obsidian Sync safety)
```swift
let target = url.appendingPathComponent(relPath)
let dir = target.deletingLastPathComponent()
var dirErr: NSError?
NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: dir, options: [], error: &dirErr) { d in
  try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
}
var coordErr: NSError?
var writeErr: Error?
NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: target, options: .forReplacing, error: &coordErr) { dst in
  do { try bytes.write(to: dst, options: .atomic) } catch { writeErr = error }
}
if let e = (coordErr as Error?) ?? writeErr { throw e }
```
- iCloud placeholders: before updating an existing note, read
  `[.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]`; only when `isUbiquitousItem == true`
  and `ubiquitousItemDownloadingStatus` is not `.current`, call
  `FileManager.default.startDownloadingUbiquitousItem(at:)` and retry later via outbox (EXP-06).
- Exists checks also go through coordination (`coordinate(readingItemAt:)`).

## App's own folder (default target)
`Info.plist`: `UIFileSharingEnabled = YES`, `LSSupportsOpeningDocumentsInPlace = YES` → app's
`Documents/` shows in Files under "On My iPhone › VaultVoice". Only exported notes go there —
internal data lives in Application Support (see `vv-local-database`).

## Notes
- Obsidian iOS vaults: `On My iPhone › Obsidian › <Vault>` or `iCloud Drive › Obsidian › <Vault>`.
  Test both; confirm Obsidian picks up new files without manual refresh.
- Bookmarks survive app updates; they do not survive app deletion → re-pick.
- Background writes (pipeline finishing in background): bookmark resolution works, but iCloud
  coordination may be slow — rely on outbox retry, never block the background task budget.
