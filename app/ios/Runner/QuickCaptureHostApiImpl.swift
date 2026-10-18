import Flutter

/// QCP-02: Pigeon host API exposing the in-memory hand-off to Dart. The
/// request is returned once; the mode is always navigate.
final class QuickCaptureHostApiImpl: QuickCaptureHostApi {
  func consumeRequest() throws -> QuickCaptureRequestMessage? {
    guard let request = QuickCaptureStore.shared.consume() else { return nil }
    return QuickCaptureRequestMessage(
      id: request.id, entry: request.entry.rawValue, mode: "navigate",
      remainingMs: Int64(request.remainingMs))
  }
}
