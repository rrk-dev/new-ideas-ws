import Flutter
import LocalAuthentication
import UIKit

/// SEC-03 (ADR-SEC-03-app-lock): device authentication + app-switcher
/// privacy overlay.
///
/// Channel `vaultvoice/device_auth`: `authenticate({reason})` ->
/// `"success" | "failed" | "unavailable"` via
/// `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` (Face ID / Touch ID
/// with the device passcode as fallback; `NSFaceIDUsageDescription` in
/// Info.plist). `"unavailable"` = no passcode set.
///
/// Channel `vaultvoice/privacy_screen`: `setEnabled({enabled})`. While
/// enabled, an opaque cover is added to every window of a scene when it
/// resigns active (`UIScene.willDeactivateNotification` — posted together
/// with `sceneWillResignActive(_:)`, i.e. before the app-switcher snapshot)
/// and removed when it becomes active again. Observing the notifications
/// keeps `FlutterSceneDelegate`'s own lifecycle forwarding untouched.
/// Verified against the iOS 16 SDK (UIKit / LocalAuthentication).
final class AppLockPlugin: NSObject, FlutterPlugin {
  static let authChannel = "vaultvoice/device_auth"
  static let privacyChannel = "vaultvoice/privacy_screen"
  private static let coverTag = 0x5EC3

  private var enabled = false
  private var observers: [NSObjectProtocol] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = AppLockPlugin()
    for name in [authChannel, privacyChannel] {
      let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
      registrar.addMethodCallDelegate(plugin, channel: channel)
    }
    plugin.observe()
  }

  deinit {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "setEnabled":
      enabled = args?["enabled"] as? Bool ?? false
      if !enabled { removeCovers() }
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

  private func observe() {
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(
        forName: UIScene.willDeactivateNotification, object: nil, queue: .main
      ) { [weak self] note in
        guard let self, self.enabled, let scene = note.object as? UIWindowScene else { return }
        scene.windows.forEach { self.cover($0) }
      })
    observers.append(
      center.addObserver(
        forName: UIScene.didActivateNotification, object: nil, queue: .main
      ) { [weak self] _ in
        self?.removeCovers()
      })
  }

  private func cover(_ window: UIWindow) {
    guard window.viewWithTag(Self.coverTag) == nil else { return }
    let view = UIView(frame: window.bounds)
    view.tag = Self.coverTag
    view.backgroundColor = .systemBackground
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
    icon.tintColor = .secondaryLabel
    icon.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(icon)
    NSLayoutConstraint.activate([
      icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 44),
      icon.heightAnchor.constraint(equalToConstant: 52),
    ])
    window.addSubview(view)
  }

  private func removeCovers() {
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for window in windowScene.windows {
        window.viewWithTag(Self.coverTag)?.removeFromSuperview()
      }
    }
  }
}
