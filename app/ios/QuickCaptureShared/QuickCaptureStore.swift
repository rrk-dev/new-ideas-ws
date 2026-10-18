import Foundation

/// QCP-02 in-memory quick-capture hand-off (ADR-QCP-01 → "Single-use
/// hand-off request").
///
/// One pending request at most, held in process memory only: no App Group,
/// UserDefaults, Keychain, file, database or network. A request carries an
/// id, the issuing surface and a monotonic expiry. It is navigate-only: it can
/// make the Dart side open the Record screen, nothing more. Dart `consume`s it
/// once; an expired or replayed request is dropped.
///
/// Compiled into the Runner (where it is read) and into the widget extension
/// (the control's intent type references it, but `perform()` only ever runs in
/// the app process because of `openAppWhenRun`).
public final class QuickCaptureStore {
  public static let shared = QuickCaptureStore()

  /// URL scheme registered by the app (`CFBundleURLTypes`).
  public static let urlScheme = "lumen"
  public static let ttl: TimeInterval = 10
  public static let replayMemory = 16

  public enum Entry: String {
    case iosWidget
    case iosControl
  }

  /// What `consume()` hands to the host API.
  public struct Request {
    public let id: String
    public let entry: Entry
    public let remainingMs: Int
  }

  private struct Pending {
    let id: String
    let entry: Entry
    let expiresAt: TimeInterval
  }

  private let lock = NSLock()
  private let uptime: () -> TimeInterval
  private var pending: Pending?
  private var consumed: [String] = []

  public init(uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
    self.uptime = uptime
  }

  /// Stores a navigate request for [entry], replacing any older one.
  @discardableResult
  public func submit(entry: Entry) -> String {
    lock.lock()
    defer { lock.unlock() }
    let id = UUID().uuidString.lowercased()
    pending = Pending(id: id, entry: entry, expiresAt: uptime() + Self.ttl)
    return id
  }

  /// Handles `lumen://record?entry=widget`. Returns true when the URL belongs
  /// to this feature (even if dropped), false so the caller can pass it on.
  @discardableResult
  public func submit(url: URL) -> Bool {
    guard url.scheme?.lowercased() == Self.urlScheme, url.host?.lowercased() == "record"
    else { return false }
    // The widget's URL is a fixed constant; an unknown entry is dropped.
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    if items?.first(where: { $0.name == "entry" })?.value == "widget" {
      submit(entry: .iosWidget)
    }
    return true
  }

  /// Returns the pending request and deletes it; nil when none, expired or
  /// already consumed.
  public func consume() -> Request? {
    lock.lock()
    defer { lock.unlock() }
    guard let request = pending else { return nil }
    pending = nil
    let remaining = request.expiresAt - uptime()
    guard remaining > 0, !consumed.contains(request.id) else { return nil }
    consumed.append(request.id)
    if consumed.count > Self.replayMemory { consumed.removeFirst() }
    return Request(id: request.id, entry: request.entry, remainingMs: Int(remaining * 1000))
  }
}
