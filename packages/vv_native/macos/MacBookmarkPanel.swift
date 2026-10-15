import AppKit
import FlutterMacOS

/// Security-scoped bookmark host for a user-picked vault folder (EXP-09).
///
/// FND-09 compiles this into the macOS runner and registers it with
/// `BookmarkHostApiSetup.setUp` once the Pigeon `BookmarkHostApi` protocol
/// (same API as `app/ios/Runner/BookmarkApi.g.swift`) is in the macOS target.
/// Dart writes through `BookmarkVaultWriter` — this host only resolves the
/// bookmark and stores the bytes it is given.
///
/// - Picking: `NSOpenPanel` (directories only). The bookmark is created with
///   `.withSecurityScope`, which is the macOS way a folder grant survives
///   relaunch. The panel URL is not stored.
/// - Every operation resolves that bookmark, calls
///   `startAccessingSecurityScopedResource()`, does its work, and stops
///   again. A stale bookmark is re-created and returned from `checkAccess`.
/// - Writes go through `NSFileCoordinator` and are atomic.
/// - Error messages are content-free (no file names or paths).
///
/// Written against the macOS 13 AppKit/Foundation bookmark APIs and the
/// Pigeon 29.0.8 `BookmarkHostApi` protocol. Error codes match
/// `VaultErrorCodes`.
final class MacBookmarkHostApiImpl: NSObject, BookmarkHostApi {
  private let ioQueue = DispatchQueue(label: "com.vaultvoice.macos-bookmarks", qos: .utility)

  private static func err(_ code: String, _ message: String) -> BookmarkPigeonError {
    BookmarkPigeonError(code: code, message: message, details: nil)
  }

  func pickFolder(completion: @escaping (Result<BookmarkFolder?, Error>) -> Void) {
    DispatchQueue.main.async {
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      panel.canCreateDirectories = true
      panel.prompt = "Choose Vault"
      guard panel.runModal() == .OK, let url = panel.url else {
        completion(.success(nil))
        return
      }
      let name = url.lastPathComponent
      self.ioQueue.async {
        do {
          let bookmark = try Self.createBookmark(url)
          DispatchQueue.main.async {
            completion(.success(BookmarkFolder(bookmark: bookmark, displayName: name)))
          }
        } catch {
          DispatchQueue.main.async { completion(.failure(Self.map(error))) }
        }
      }
    }
  }

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

  func exists(
    bookmark: String, relativePath: String, completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> Bool in
        let target = try Self.child(root, relativePath)
        return FileManager.default.fileExists(atPath: target.path)
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
        if FileManager.default.fileExists(atPath: target.path) && !overwrite {
          throw Self.err("exists", "file exists")
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
        try Self.coordinatedMkdirs(try Self.child(root, relativePath))
      }.0
    }
  }

  func delete(
    bookmark: String, relativePath: String, completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> Bool in
        let target = try Self.child(root, relativePath)
        guard FileManager.default.fileExists(atPath: target.path) else { return false }
        try Self.coordinate(writing: target, options: .forDeleting) { url in
          try FileManager.default.removeItem(at: url)
        }
        return true
      }.0
    }
  }

  func list(
    bookmark: String, relativePath: String,
    completion: @escaping (Result<[BookmarkEntry], Error>) -> Void
  ) {
    runIo(completion) {
      try Self.withFolder(bookmark) { root -> [BookmarkEntry] in
        let dir = relativePath.isEmpty ? root : try Self.child(root, relativePath)
        guard FileManager.default.fileExists(atPath: dir.path) else {
          throw Self.err("not_found", "no such folder")
        }
        var urls: [URL] = []
        try Self.coordinate(reading: dir, options: []) { url in
          urls = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        }
        return urls.map { url in
          let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
          return BookmarkEntry(name: url.lastPathComponent, isDirectory: isDir)
        }
      }.0
    }
  }

  private func runIo<T>(
    _ completion: @escaping (Result<T, Error>) -> Void, _ body: @escaping () throws -> T
  ) {
    ioQueue.async {
      let result: Result<T, Error>
      do { result = .success(try body()) } catch { result = .failure(Self.map(error)) }
      DispatchQueue.main.async { completion(result) }
    }
  }

  /// `.withSecurityScope` is what makes the grant survive relaunch.
  private static func createBookmark(_ url: URL) throws -> String {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let data = try url.bookmarkData(
      options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    return data.base64EncodedString()
  }

  private static func withScope<T>(_ url: URL, _ body: () throws -> T) throws -> T {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    if !scoped {
      throw err("revoked", "security scope refused")
    }
    return try body()
  }

  /// Resolves [bookmark]. Returns the body's value and, when the bookmark was
  /// stale, a re-created security-scoped bookmark (base64).
  private static func withFolder<T>(_ bookmark: String, _ body: (URL) throws -> T) throws -> (
    T, String?
  ) {
    guard let data = Data(base64Encoded: bookmark) else { throw err("invalid", "bad bookmark") }
    var stale = false
    let url: URL
    do {
      url = try URL(
        resolvingBookmarkData: data,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &stale)
    } catch {
      throw err("revoked", "bookmark cannot be resolved")
    }
    return try withScope(url) {
      var refreshed: String?
      if stale {
        refreshed = try? createBookmark(url)
      }
      return (try body(url), refreshed)
    }
  }

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

  private static func coordinatedMkdirs(_ dir: URL) throws {
    if FileManager.default.fileExists(atPath: dir.path) { return }
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

  private static func map(_ error: Error) -> BookmarkPigeonError {
    if let e = error as? BookmarkPigeonError { return e }
    let ns = error as NSError
    guard ns.domain == NSCocoaErrorDomain else { return err("io", "error \(ns.code)") }
    switch ns.code {
    case NSFileWriteNoPermissionError, NSFileReadNoPermissionError, NSFileWriteVolumeReadOnlyError:
      return err("revoked", "permission denied")
    case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
      return err("not_found", "no such file")
    case NSFileWriteOutOfSpaceError:
      return err("io", "out of space")
    default:
      return err("io", "cocoa error \(ns.code)")
    }
  }
}
