import AppKit
import FlutterMacOS
import Foundation

/// Security-scoped bookmark host API, macOS side (EXP-09 / FND-09).
///
/// Mirrors `ios/Runner/BookmarkHostApiImpl.swift` and the Pigeon
/// `BookmarkHostApi` contract:
///
/// - Picking: `NSOpenPanel` (directories only) -> app-scoped security-scoped
///   bookmark (`.withSecurityScope`, entitlement
///   `com.apple.security.files.bookmarks.app-scope`) that Dart stores as
///   `vault_targets.handle`. The panel needs
///   `com.apple.security.files.user-selected.read-write`.
/// - Every operation resolves the bookmark with `.withSecurityScope`, starts
///   access, works and stops again. Stale bookmarks are re-created and
///   returned from `checkAccess` as `refreshedBookmark`.
/// - Writes and existence checks go through `NSFileCoordinator`; writes are
///   `.atomic` with `.forReplacing`. IO runs on a serial utility queue;
///   completions are delivered on main. Error messages are content-free.
///
/// Error codes must match `VaultErrorCodes` in
/// `lib/features/export/data/vault_platform_errors.dart`.
final class BookmarkHostApiImpl: NSObject, BookmarkHostApi {
  private let ioQueue = DispatchQueue(label: "com.vaultvoice.vault-bookmarks", qos: .utility)
  private var pickerOpen = false

  private static func err(_ code: String, _ message: String) -> BookmarkPigeonError {
    BookmarkPigeonError(code: code, message: message, details: nil)
  }

  // MARK: - Picker

  func pickFolder(completion: @escaping (Result<BookmarkFolder?, Error>) -> Void) {
    guard !pickerOpen else {
      completion(.failure(Self.err("busy", "picker already open")))
      return
    }
    pickerOpen = true
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose"
    let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
      guard let self else { return }
      self.pickerOpen = false
      guard response == .OK, let url = panel.url else {
        completion(.success(nil))
        return
      }
      // The panel's grant is tied to this URL object: create the bookmark
      // right here, inside the access window, not on another queue.
      completion(Self.bookmarkForPicked(url))
    }
    if let window = NSApp.keyWindow ?? NSApp.mainWindow {
      panel.beginSheetModal(for: window, completionHandler: finish)
    } else {
      panel.begin(completionHandler: finish)
    }
  }

  /// Builds the stored bookmark for a panel URL. Failures are content-free:
  /// the Cocoa error code only, never the path.
  private static func bookmarkForPicked(_ url: URL) -> Result<BookmarkFolder?, Error> {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try url.bookmarkData(
        options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
      return .success(
        BookmarkFolder(bookmark: bookmark.base64EncodedString(), displayName: url.lastPathComponent))
    } catch {
      let ns = error as NSError
      // A refused grant is "revoked" (re-pick), not a transient outage.
      return .failure(err("revoked", "bookmark refused \(ns.domain) \(ns.code)"))
    }
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

  func readFile(
    bookmark: String, relativePath: String,
    completion: @escaping (Result<FlutterStandardTypedData?, Error>) -> Void
  ) {
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> FlutterStandardTypedData? in
        let target = try Self.child(root, relativePath)
        switch Self.state(of: target) {
        case .none:
          return nil
        case .some(.directory):
          throw Self.err("invalid", "path is a folder")
        case .some(.notDownloaded):
          // Reading a placeholder would block on the download: start it and
          // let the caller retry (EXP-06 outbox).
          try? FileManager.default.startDownloadingUbiquitousItem(at: target)
          throw Self.err("unavailable", "icloud item not downloaded")
        case .some(.file):
          var data = Data()
          try Self.coordinate(reading: target, options: []) { url in
            data = try Data(contentsOf: url)
          }
          return FlutterStandardTypedData(bytes: data)
        }
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
        resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
    } catch {
      // Folder deleted, provider removed or app reinstalled: re-pick.
      throw err("revoked", "bookmark cannot be resolved")
    }
    return try withScope(url) {
      var refreshed: String?
      if stale {
        refreshed = try? url.bookmarkData(
          options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
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
