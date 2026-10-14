import Flutter
import UserNotifications

/// AUD-04 (iOS side of `vaultvoice/recording_indicator`, see
/// docs/adr/ADR-AUD-04-ios-background-recording.md).
///
/// While recording in the background iOS itself shows the microphone
/// indicator (orange dot / recording pill in the status bar, Control Center
/// "in use by" label) for an app with the `audio` background mode — there is
/// no hidden mode. The Live Activity is deferred (AUD-10, proposed), so:
/// - `show` / `hide`: request notification authorization once (for the
///   reminder) / remove a delivered reminder; no other UI.
/// - `remind({text})`: the SEC-09 "Still recording (1h 00m)" reminder as a
///   local notification (no network, no push).
/// - no action events (iOS has no notification buttons here); battery
///   methods are Android-only (`FlutterMethodNotImplemented`).
final class RecordingIndicatorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let methodChannelName = "vaultvoice/recording_indicator"
  static let eventChannelName = "vaultvoice/recording_indicator/actions"
  private static let reminderId = "vaultvoice.recording.reminder"

  private var askedForAuthorization = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = RecordingIndicatorPlugin()
    let methods = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "show":
      if !askedForAuthorization {
        askedForAuthorization = true
        center.requestAuthorization(options: [.alert]) { _, _ in }
      }
      result(nil)
    case "hide":
      center.removeDeliveredNotifications(withIdentifiers: [Self.reminderId])
      center.removePendingNotificationRequests(withIdentifiers: [Self.reminderId])
      result(nil)
    case "remind":
      let text = (call.arguments as? [String: Any])?["text"] as? String ?? ""
      let content = UNMutableNotificationContent()
      content.title = text
      let request = UNNotificationRequest(identifier: Self.reminderId, content: content, trigger: nil)
      center.add(request) { _ in }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    nil
  }
}
