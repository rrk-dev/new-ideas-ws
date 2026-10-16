import AppKit
import FlutterMacOS
import Foundation
import Network

/// macOS hosts for the small platform channels the Dart side calls (FND-09).
/// None of them uses a permission-gated API; see
/// docs/adr/ADR-SEC-09-recording-policy.md for the call-guard decision.
enum MacHostChannels {
  static func register(with registrar: FlutterPluginRegistrar) {
    AppSettingsHost.register(with: registrar)
    StorageInfoHost.register(with: registrar)
    ModelDownloadHost.register(with: registrar)
    CallGuardHost.register(with: registrar)
    RecordingIndicatorHost.register(with: registrar)
    ProcessingHost.register(with: registrar)
  }

  fileprivate static func freeBytes(at path: String?) -> NSNumber? {
    var path = path ?? NSHomeDirectory()
    // The directory may not exist yet: the home directory shares the volume.
    if !FileManager.default.fileExists(atPath: path) { path = NSHomeDirectory() }
    let values = try? URL(fileURLWithPath: path).resourceValues(
      forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    return values?.volumeAvailableCapacityForImportantUsage.map { NSNumber(value: $0) }
  }
}

/// `vaultvoice/app_settings`: `open` -> Bool. Opens System Settings at
/// Privacy & Security -> Microphone (the recovery path after a denial).
final class AppSettingsHost: NSObject, FlutterPlugin {
  static let channelName = "vaultvoice/app_settings"
  static let microphonePane =
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(AppSettingsHost(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "open" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let url = URL(string: Self.microphonePane) else {
      result(false)
      return
    }
    result(NSWorkspace.shared.open(url))
  }
}

/// `vaultvoice/storage_info`: `freeBytes({path})` -> Int64 via
/// `volumeAvailableCapacityForImportantUsage`. `audioEffects` is Android-only
/// (Dart never asks on macOS) and answers "not implemented".
final class StorageInfoHost: NSObject, FlutterPlugin {
  static let channelName = "vaultvoice/storage_info"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(StorageInfoHost(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "freeBytes":
      let path = (call.arguments as? [String: Any])?["path"] as? String
      if let free = MacHostChannels.freeBytes(at: path) {
        result(free)
      } else {
        result(FlutterError(code: "unavailable", message: "capacity unknown", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// `vaultvoice/model_download`: device facts for the in-process gateway
/// transport (macOS does not use the iOS background session).
/// `freeBytes`, `networkStatus` (NWPathMonitor), `excludeFromBackup`;
/// keep-alive calls are accepted no-ops (a Mac app is not suspended like an
/// iPhone app); `bg*` calls are never made on macOS and answer "not
/// implemented".
final class ModelDownloadHost: NSObject, FlutterPlugin {
  static let channelName = "vaultvoice/model_download"
  private let monitor = NWPathMonitor()
  private var latestPath: NWPath?

  static func register(with registrar: FlutterPluginRegistrar) {
    let host = ModelDownloadHost()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(host, channel: channel)
    host.monitor.pathUpdateHandler = { [weak host] path in host?.latestPath = path }
    host.monitor.start(queue: DispatchQueue(label: "vaultvoice.model-download.reachability"))
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "freeBytes":
      result(MacHostChannels.freeBytes(at: args["path"] as? String))
    case "networkStatus":
      let path = latestPath ?? monitor.currentPath
      let connected = path.status == .satisfied
      result([
        "connected": connected,
        "unmetered": connected && !path.isExpensive && !path.isConstrained,
        "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
      ])
    case "excludeFromBackup":
      guard let path = args["path"] as? String else { return result(false) }
      var url = URL(fileURLWithPath: path, isDirectory: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(true)
      } catch {
        result(false)
      }
    case "keepAliveStart", "keepAliveUpdate", "keepAliveStop":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// SEC-09 CallGuard (macOS), see docs/adr/ADR-SEC-09-recording-policy.md.
///
/// A Mac has no cellular call, and the policy forbids CallKit, VoIP modes,
/// call-attachment features and any call-related permission. So the
/// answer is honest and permissionless: `isInCall` -> `false` (this host
/// cannot see calls and does not try), and the event stream never emits.
/// Dart keeps its fail-closed handling for iOS/Android, where a missing or
/// failing guard blocks recording.
final class CallGuardHost: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let methodChannelName = "vaultvoice/call_guard"
  static let eventChannelName = "vaultvoice/call_guard/events"

  static func register(with registrar: FlutterPluginRegistrar) {
    let host = CallGuardHost()
    let methods = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(host, channel: methods)
    let events = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: registrar.messenger)
    events.setStreamHandler(host)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isInCall":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    nil
  }
}

/// `vaultvoice/recording_indicator` (+ `/actions`), macOS side.
///
/// macOS itself shows the microphone indicator in the menu bar for as long as
/// the app captures, and the Record screen is the visible in-app indicator.
/// This host therefore acknowledges `show`, `hide` and `remind` without
/// posting notifications (no notification permission is requested) and emits
/// no action events. `batteryStatus` / `openBatterySettings` are Android-only
/// and answer "not implemented".
final class RecordingIndicatorHost: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let methodChannelName = "vaultvoice/recording_indicator"
  static let eventChannelName = "vaultvoice/recording_indicator/actions"

  static func register(with registrar: FlutterPluginRegistrar) {
    let host = RecordingIndicatorHost()
    let methods = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(host, channel: methods)
    let events = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: registrar.messenger)
    events.setStreamHandler(host)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "show", "hide", "remind":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    nil
  }
}

/// `vaultvoice/processing` (+ `/events`), macOS side. A Mac app keeps
/// running in the background, so begin/progress/end are no-ops and there is
/// no deferred-processing scheduler; only the thermal state is reported.
final class ProcessingHost: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let methodChannelName = "vaultvoice/processing"
  static let eventChannelName = "vaultvoice/processing/events"

  static func register(with registrar: FlutterPluginRegistrar) {
    let host = ProcessingHost()
    let methods = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(host, channel: methods)
    let events = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: registrar.messenger)
    events.setStreamHandler(host)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "conditions":
      let thermal: String
      switch ProcessInfo.processInfo.thermalState {
      case .nominal: thermal = "nominal"
      case .fair: thermal = "fair"
      case .serious: thermal = "serious"
      case .critical: thermal = "critical"
      @unknown default: thermal = "unknown"
      }
      result([
        "charging": false,
        "lowPower": ProcessInfo.processInfo.isLowPowerModeEnabled,
        "thermal": thermal,
      ])
    case "begin", "progress", "end", "scheduleDeferred", "completeDeferred":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    nil
  }
}
