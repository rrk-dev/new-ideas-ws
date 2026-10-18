import FlutterMacOS
import Foundation

/// LIC-04 managed configuration (MDM), macOS side. Method channel
/// `vaultvoice/managed_config`: `read` -> JSON string (nil when none);
/// native -> Dart `changed`.
///
/// Sources, in order: the `com.apple.configuration.managed` dictionary in
/// `UserDefaults` (same key as iOS), then keys forced by a configuration
/// profile in the app's preference domain (`CFPreferencesAppValueIsForced`).
/// Unverified on a managed Mac: see docs/mdm-config.md. Nothing is written
/// and nothing is logged.
final class ManagedConfigPlugin: NSObject, FlutterPlugin {
  static let channelName = "vaultvoice/managed_config"
  static let managedKey = "com.apple.configuration.managed"
  static let knownKeys = [
    "license", "profile_packs", "allowed_target_kinds", "audio_retention_days",
    "network_disabled", "lock_settings", "force_app_lock", "disable_custom_models",
    "force_consent_confirmation", "max_recording_minutes",
  ]

  private let channel: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    observer = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.channel.invokeMethod("changed", arguments: nil)
    }
  }

  deinit {
    if let observer { NotificationCenter.default.removeObserver(observer) }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
    let plugin = ManagedConfigPlugin(channel: channel)
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.publish(plugin)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "read":
      result(Self.readJson())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func readJson() -> String? {
    var dict = UserDefaults.standard.dictionary(forKey: managedKey) ?? [:]
    let defaults = UserDefaults.standard
    for key in knownKeys where dict[key] == nil && defaults.objectIsForced(forKey: key) {
      if let value = defaults.object(forKey: key) { dict[key] = value }
    }
    guard !dict.isEmpty, JSONSerialization.isValidJSONObject(dict),
      let data = try? JSONSerialization.data(withJSONObject: dict),
      let text = String(data: data, encoding: .utf8)
    else { return nil }
    return text
  }
}
