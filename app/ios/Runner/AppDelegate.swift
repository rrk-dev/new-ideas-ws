import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Security-scoped bookmark vault folders (EXP-04).
  private let bookmarkApi = BookmarkHostApiImpl()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // APP-04: local notifications (flutter_local_notifications 22.3.1 README)
    // — taps and foreground presentation go through FlutterAppDelegate.
    UNUserNotificationCenter.current().delegate = self
    // FND-08: BGProcessingTask handler must be registered before launch ends.
    ProcessingPlugin.registerBackgroundTask()
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
    // AUD-04: audio route / engine / media-services events; recording reminder.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioSessionPlugin") {
      AudioSessionPlugin.register(with: registrar)
    }
    // FND-08: background processing (background task, BGProcessingTask, power/thermal).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ProcessingPlugin") {
      ProcessingPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RecordingIndicatorPlugin") {
      RecordingIndicatorPlugin.register(with: registrar)
    }
    // AUD-06: audio import (AVFoundation decoding, "Open in" / share inbox).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioImportPlugin") {
      AudioImportPlugin.register(with: registrar)
    }
    BookmarkHostApiSetup.setUp(
      binaryMessenger: engineBridge.applicationRegistrar.messenger(), api: bookmarkApi)
    // APP-01: "Open settings" recovery after a denied permission. Opens this
    // app's page in Settings (UIApplication.openSettingsURLString, iOS 8+).
    let appSettings = FlutterMethodChannel(
      name: "vaultvoice/app_settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    appSettings.setMethodCallHandler { call, result in
      guard call.method == "open",
        let url = URL(string: UIApplication.openSettingsURLString)
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(url) { opened in result(opened) }
    }
  }
}
