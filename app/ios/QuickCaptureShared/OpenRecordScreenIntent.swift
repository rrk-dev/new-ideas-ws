import AppIntents

/// QCP-02 Lock Screen / Control Center control action (iOS 18+).
///
/// Navigate-only: running it opens Lumen, which shows the Record screen. It
/// never records; the user taps Record in the app. Hidden from Siri,
/// Spotlight and Shortcuts, so it is not an automation entry point
/// (ADR-QCP-01: no start-now, no Action Button / Shortcuts intent).
///
/// Compiled into the Runner as well: `openAppWhenRun` intents must run in the
/// app process, not in the extension (Apple: it "generates an error if the app
/// intent runs in an app extension"). iOS 26 deprecates `openAppWhenRun` in
/// favour of `supportedModes`; the spelling that opens the app on iOS 18-26+
/// is Unverified on device (docs/test-plans/device/QCP-02.md, D11).
@available(iOS 18.0, *)
public struct OpenRecordScreenIntent: AppIntent {
  public static let title: LocalizedStringResource = "Open Lumen"
  public static let openAppWhenRun: Bool = true
  public static let isDiscoverable: Bool = false

  public init() {}

  @MainActor
  public func perform() async throws -> some IntentResult {
    QuickCaptureStore.shared.submit(entry: .iosControl)
    return .result()
  }
}
