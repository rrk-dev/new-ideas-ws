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
    BookmarkHostApiSetup.setUp(
      binaryMessenger: engineBridge.applicationRegistrar.messenger(), api: bookmarkApi)
  }
}
