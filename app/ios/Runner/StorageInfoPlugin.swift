import Flutter
import Foundation

/// AUD-01 recording storage policy: free bytes on the volume holding the
/// app-private recording directory.
///
/// Uses `volumeAvailableCapacityForImportantUsage` (iOS 11+), the value
/// Apple recommends for user-initiated content such as a recording.
/// Method channel `vaultvoice/storage_info`: `freeBytes({path})` -> Int64.
final class StorageInfoPlugin: NSObject, FlutterPlugin {
  static let channelName = "vaultvoice/storage_info"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(StorageInfoPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "freeBytes":
      var path = (call.arguments as? [String: Any])?["path"] as? String ?? NSHomeDirectory()
      if !FileManager.default.fileExists(atPath: path) {
        // The directory may not exist yet: the home directory is on the same volume.
        path = NSHomeDirectory()
      }
      do {
        let values = try URL(fileURLWithPath: path).resourceValues(
          forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values.volumeAvailableCapacityForImportantUsage {
          result(NSNumber(value: free))
        } else {
          result(FlutterError(code: "unavailable", message: "capacity unknown", details: nil))
        }
      } catch {
        result(FlutterError(code: "unavailable", message: "resource values failed", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
