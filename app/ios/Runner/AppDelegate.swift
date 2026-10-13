import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Security-scoped bookmark vault folders (EXP-04).
  private let bookmarkApi = BookmarkHostApiImpl()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // SEC-09: call detection without permissions (CXCallObserver).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CallGuardPlugin") {
      CallGuardPlugin.register(with: registrar)
    }
    // AUD-01: free-space checks for the recording storage policy.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StorageInfoPlugin") {
      StorageInfoPlugin.register(with: registrar)
    }
    // AUD-04: audio route / engine / media-services events; recording reminder.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioSessionPlugin") {
      AudioSessionPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RecordingIndicatorPlugin") {
      RecordingIndicatorPlugin.register(with: registrar)
    }
    BookmarkHostApiSetup.setUp(
      binaryMessenger: engineBridge.applicationRegistrar.messenger(), api: bookmarkApi)
  }
}
