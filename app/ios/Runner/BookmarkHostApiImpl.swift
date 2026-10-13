import Flutter
import UIKit
import UniformTypeIdentifiers

/// Security-scoped bookmark host API (EXP-04).
///
/// - Picking: `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`
///   → bookmark data (base64) that Dart stores as `vault_targets.handle`.
///   On iOS a plain `bookmarkData(options: [])` of a picked URL carries the
///   security scope (`.withSecurityScope` is macOS-only).
/// - Every operation resolves the bookmark, calls
///   `startAccessingSecurityScopedResource()`, does its work and stops again
///   (short access windows). Stale bookmarks are re-created and returned from
///   `checkAccess` as `refreshedBookmark`.
/// - Writes and existence checks go through `NSFileCoordinator` (iCloud Drive /
///   Obsidian Sync safety); writes are `.atomic` with `.forReplacing`.
/// - iCloud items that are not downloaded (status != current, or a
///   `.<name>.icloud` placeholder) are not overwritten blindly: a download is
///   started and the call fails with `unavailable` so the outbox retries.
/// - IO runs on a serial utility queue; completions are delivered on main.
///   Error messages are content-free (no file names or paths).
///
/// Written against the iOS 16 SDK Foundation/UIKit reference and the Pigeon
/// 29.0.8 generated `BookmarkHostApi` protocol. Error codes must match
/// `VaultErrorCodes` in `lib/features/export/data/vault_platform_errors.dart`.
final class BookmarkHostApiImpl: NSObject, BookmarkHostApi, UIDocumentPickerDelegate,
  UIAdaptivePresentationControllerDelegate
{
  private let ioQueue = DispatchQueue(label: "com.vaultvoice.vault-bookmarks", qos: .utility)
  private var pendingPick: ((Result<BookmarkFolder?, Error>) -> Void)?

  private static func err(_ code: String, _ message: String) -> BookmarkPigeonError {
    BookmarkPigeonError(code: code, message: message, details: nil)
  }

  // MARK: - Picker

  func pickFolder(completion: @escaping (Result<BookmarkFolder?, Error>) -> Void) {
    guard pendingPick == nil else {
      completion(.failure(Self.err("busy", "picker already open")))
      return
    }
    guard let presenter = Self.topViewController() else {
      completion(.failure(Self.err("unavailable", "no view controller to present from")))
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    pendingPick = completion
    presenter.present(picker, animated: true)
    // Swipe-to-dismiss on iPad/sheets: treat as cancel.
    picker.presentationController?.delegate = self
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let completion = pendingPick else { return }
    pendingPick = nil
    guard let url = urls.first else {
      completion(.success(nil))
      return
    }
    ioQueue.async {
      let result: Result<BookmarkFolder?, Error>
      do {
        let bookmark = try Self.withScope(url) {
          try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        result = .success(
          BookmarkFolder(bookmark: bookmark.base64EncodedString(), displayName: url.lastPathComponent))
      } catch {
        result = .failure(Self.map(error))
      }
      DispatchQueue.main.async { completion(result) }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    cancelPendingPick()
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    cancelPendingPick()
  }

  private func cancelPendingPick() {
    guard let completion = pendingPick else { return }
    pendingPick = nil
    completion(.success(nil))
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  // MARK: - Access

  func checkAccess(bookmark: String, completion: @escaping (Result<BookmarkAccess, Error>) -> Void) {
    runIo(completion) {
      do {
        let (reachable, refreshed) = try Self.withFolder(bookmark) { root -> Bool in
          var isDir: ObjCBool = false
          let reachable = (try? root.checkResourceIsReachable()) == true
          return reachable && FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir)
            && isDir.boolValue
        }
        return BookmarkAccess(status: reachable ? .ok : .unavailable, refreshedBookmark: refreshed)
      } catch let e as BookmarkPigeonError where e.code == "revoked" {
        return BookmarkAccess(status: .revoked, refreshedBookmark: nil)
      }
    }
  }

  func appDocumentsPath() throws -> String {
    guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    else { throw Self.err("unavailable", "no documents directory") }
    return docs.path
  }

  // MARK: - Operations

  func exists(
    bookmark: String, relativePath: String, completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> Bool in
        let target = try Self.child(root, relativePath)
        return Self.state(of: target) != nil
      }.0
    }
  }

  func writeFile(
    bookmark: String, relativePath: String, bytes: FlutterStandardTypedData, overwrite: Bool,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let data = bytes.data
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> String in
        let target = try Self.child(root, relativePath)
        try Self.coordinatedMkdirs(target.deletingLastPathComponent())
        switch Self.state(of: target) {
        case .none:
          break
        case .some(.directory):
          throw Self.err("invalid", "path is a folder")
        case .some(_) where !overwrite:
          throw Self.err("exists", "file exists")
        case .some(.notDownloaded):
          // Updating an iCloud placeholder would fork the note: download
          // first, let the outbox retry (EXP-06).
          try? FileManager.default.startDownloadingUbiquitousItem(at: target)
          throw Self.err("unavailable", "icloud item not downloaded")
        case .some(.file):
          break
        }
        try Self.coordinatedWrite(data, to: target)
        return target.absoluteString
      }.0
    }
  }

  func mkdirs(
    bookmark: String, relativePath: String, completion: @escaping (Result<Void, Error>) -> Void
  ) {
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> Void in
        let dir = try Self.child(root, relativePath)
        try Self.coordinatedMkdirs(dir)
      }.0
    }
  }

  func delete(
    bookmark: String, relativePath: String, completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> Bool in
        let target = try Self.child(root, relativePath)
        switch Self.state(of: target) {
        case .none:
          return false
        case .some(.directory):
          throw Self.err("invalid", "path is a folder")
        case .some(.notDownloaded), .some(.file):
          try Self.coordinate(writing: target, options: .forDeleting) { url in
            try FileManager.default.removeItem(at: url)
          }
          return true
        }
      }.0
    }
  }

  func list(
    bookmark: String, relativePath: String,
    completion: @escaping (Result<[BookmarkEntry], Error>) -> Void
  ) {
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> [BookmarkEntry] in
        let dir: URL
        if relativePath.isEmpty {
          dir = root
        } else {
          dir = try Self.child(root, relativePath)
        }
        guard Self.state(of: dir) == .directory else { throw Self.err("not_found", "no such folder") }
        var urls: [URL] = []
        try Self.coordinate(reading: dir, options: []) { url in
          urls = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        }
        return urls.map { url in
          let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
          return BookmarkEntry(name: Self.displayName(url.lastPathComponent), isDirectory: isDir)
        }
      }.0
    }
  }

  // MARK: - Helpers

  private enum ItemState: Equatable { case file, directory, notDownloaded }

  /// Runs [body] on the IO queue, mapping errors, completing on main.
  private func runIo<T>(
    _ completion: @escaping (Result<T, Error>) -> Void, _ body: @escaping () throws -> T
  ) {
    ioQueue.async {
      let result: Result<T, Error>
      do {
        result = .success(try body())
      } catch {
        result = .failure(Self.map(error))
      }
      DispatchQueue.main.async { completion(result) }
    }
  }

  /// Starts security-scoped access for [url] around [body]. URLs inside the
  /// app's own container are not security-scoped (start returns false) but
  /// are accessible anyway.
  private static func withScope<T>(_ url: URL, _ body: () throws -> T) throws -> T {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    if !scoped && !url.standardizedFileURL.path.hasPrefix(NSHomeDirectory()) {
      throw err("revoked", "security scope refused")
    }
    return try body()
  }

  /// Resolves [bookmark] and runs [body] with the folder URL inside a short
  /// access window. Returns the body's value and, when the bookmark was
  /// stale, the re-created bookmark (base64).
  private static func withFolder<T>(_ bookmark: String, _ body: (URL) throws -> T) throws -> (
    T, String?
  ) {
    guard let data = Data(base64Encoded: bookmark) else { throw err("invalid", "bad bookmark") }
    var stale = false
    let url: URL
    do {
      url = try URL(
        resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    } catch {
      // Folder deleted, provider removed or app reinstalled: re-pick.
      throw err("revoked", "bookmark cannot be resolved")
    }
    return try withScope(url) {
      var refreshed: String?
      if stale {
        refreshed = try? url.bookmarkData(
          options: [], includingResourceValuesForKeys: nil, relativeTo: nil
        ).base64EncodedString()
      }
      return (try body(url), refreshed)
    }
  }

  /// Defense in depth: Dart already validated the path with VaultPath.
  private static func child(_ root: URL, _ relativePath: String) throws -> URL {
    let segments = relativePath.split(separator: "/", omittingEmptySubsequences: false)
    guard !relativePath.isEmpty,
      !segments.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." || $0.contains("\0") })
    else { throw err("invalid", "bad relative path") }
    var url = root
    for (i, s) in segments.enumerated() {
      url.appendPathComponent(String(s), isDirectory: i < segments.count - 1)
    }
    return url
  }

  /// `.<name>.icloud` placeholder → `<name>`.
  private static func displayName(_ name: String) -> String {
    if name.hasPrefix("."), name.hasSuffix(".icloud"), name.count > ".icloud".count + 1 {
      return String(name.dropFirst().dropLast(".icloud".count))
    }
    return name
  }

  /// Existence + iCloud download state, without triggering a download.
  private static func state(of url: URL) -> ItemState? {
    var isDir: ObjCBool = false
    var exists = false
    try? coordinate(reading: url, options: .immediatelyAvailableMetadataOnly) { u in
      exists = FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir)
    }
    if exists {
      if isDir.boolValue { return .directory }
      let values = try? url.resourceValues(forKeys: [
        .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
      ])
      if values?.isUbiquitousItem == true,
        let status = values?.ubiquitousItemDownloadingStatus, status != .current
      {
        return .notDownloaded
      }
      return .file
    }
    let placeholder = url.deletingLastPathComponent()
      .appendingPathComponent(".\(url.lastPathComponent).icloud")
    return FileManager.default.fileExists(atPath: placeholder.path) ? .notDownloaded : nil
  }

  private static func coordinatedMkdirs(_ dir: URL) throws {
    if state(of: dir) == .directory { return }
    try coordinate(writing: dir, options: []) { d in
      try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    }
  }

  private static func coordinatedWrite(_ data: Data, to target: URL) throws {
    try coordinate(writing: target, options: .forReplacing) { dst in
      try data.write(to: dst, options: .atomic)
    }
  }

  private static func coordinate(
    writing url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void
  ) throws {
    var coordErr: NSError?
    var bodyErr: Error?
    withoutActuallyEscaping(body) { body in
      NSFileCoordinator(filePresenter: nil).coordinate(
        writingItemAt: url, options: options, error: &coordErr
      ) { u in
        do { try body(u) } catch { bodyErr = error }
      }
    }
    if let e = (coordErr as Error?) ?? bodyErr { throw e }
  }

  private static func coordinate(
    reading url: URL, options: NSFileCoordinator.ReadingOptions, _ body: (URL) throws -> Void
  ) throws {
    var coordErr: NSError?
    var bodyErr: Error?
    withoutActuallyEscaping(body) { body in
      NSFileCoordinator(filePresenter: nil).coordinate(
        readingItemAt: url, options: options, error: &coordErr
      ) { u in
        do { try body(u) } catch { bodyErr = error }
      }
    }
    if let e = (coordErr as Error?) ?? bodyErr { throw e }
  }

  /// Maps Foundation errors to the shared, content-free error codes.
  private static func map(_ error: Error) -> BookmarkPigeonError {
    if let e = error as? BookmarkPigeonError { return e }
    let ns = error as NSError
    guard ns.domain == NSCocoaErrorDomain else { return err("io", "error \(ns.code)") }
    switch ns.code {
    case NSFileWriteNoPermissionError, NSFileReadNoPermissionError, NSFileWriteVolumeReadOnlyError:
      return err("revoked", "permission denied")
    case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
      return err("not_found", "no such file")
    case NSUbiquitousFileUnavailableError, NSFileReadUnknownError:
      return err("unavailable", "storage unavailable")
    case NSFileWriteOutOfSpaceError:
      return err("io", "out of space")
    default:
      return err("io", "cocoa error \(ns.code)")
    }
  }
}
