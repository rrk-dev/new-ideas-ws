import FlutterMacOS
import LocalAuthentication

/// SEC-03 (ADR-SEC-03-app-lock), macOS side (FND-09).
///
/// `vaultvoice/device_auth`: `authenticate({reason})` ->
/// `"success" | "failed" | "unavailable"` via
/// `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` (Touch ID / Apple
/// Watch with the account password as fallback). `"unavailable"` = the Mac has
/// no usable authentication (e.g. no password set).
///
/// `vaultvoice/privacy_screen`: `setEnabled({enabled})` is accepted and does
/// nothing — macOS has no app-switcher snapshot to hide. The documented
/// result is `nil` (success).
final class AppLockPlugin: NSObject, FlutterPlugin {
  static let authChannel = "vaultvoice/device_auth"
  static let privacyChannel = "vaultvoice/privacy_screen"

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = AppLockPlugin()
    for name in [authChannel, privacyChannel] {
      let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger)
      registrar.addMethodCallDelegate(plugin, channel: channel)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "setEnabled":
      result(nil)
    case "authenticate":
      authenticate(reason: args?["reason"] as? String ?? "", result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authenticate(reason: String, result: @escaping FlutterResult) {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
      result("unavailable")
      return
    }
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, err in
      let outcome: String
      if ok {
        outcome = "success"
      } else if let la = err as? LAError, la.code == .passcodeNotSet {
        outcome = "unavailable"
      } else {
        outcome = "failed"
      }
      DispatchQueue.main.async { result(outcome) }
    }
  }
}
