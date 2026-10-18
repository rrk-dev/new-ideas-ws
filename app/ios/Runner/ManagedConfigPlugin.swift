import Flutter
import Foundation

/// LIC-04 managed configuration (MDM). Method channel
/// `vaultvoice/managed_config`: `read` -> JSON string of the managed
/// dictionary (nil when none); native -> Dart `changed` when it may have
/// changed.
///
/// The MDM server delivers the dictionary under the `UserDefaults` key
/// `com.apple.configuration.managed` (Apple "Managed app configuration").
/// Nothing is written and nothing is logged.
final class ManagedConfigPlugin: NSObject, FlutterPlugin {
  static let channelName = "vaultvoice/managed_config"
  static let managedKey = "com.apple.configuration.managed"

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
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
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
    guard let dict = UserDefaults.standard.dictionary(forKey: managedKey),
      JSONSerialization.isValidJSONObject(dict),
      let data = try? JSONSerialization.data(withJSONObject: dict),
      let text = String(data: data, encoding: .utf8)
    else { return nil }
    return text
  }
}
