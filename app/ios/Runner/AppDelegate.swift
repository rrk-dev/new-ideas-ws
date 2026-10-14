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
    // MDL-02: model downloads (background session, free space, backup exclusion).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ModelDownloadPlugin") {
      ModelDownloadPlugin.register(with: registrar)
    }
    // AUD-01: free-space checks for the recording storage policy.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StorageInfoPlugin") {
      StorageInfoPlugin.register(with: registrar)
    }
    BookmarkHostApiSetup.setUp(
      binaryMessenger: engineBridge.applicationRegistrar.messenger(), api: bookmarkApi)
  }
}
