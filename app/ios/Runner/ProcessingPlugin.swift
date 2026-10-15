import BackgroundTasks
import Flutter
import Foundation
import UIKit

/// FND-08 bridge for Dart's `MethodChannelBackgroundProcessing`
/// (vv-background-execution; verified against the BackgroundTasks and
/// UIKit API reference for iOS 16–26).
///
/// - `begin` takes a `beginBackgroundTask` assertion while work is pending,
///   so a job keeps running for the short time iOS allows after the app
///   leaves the foreground; the expiration handler sends `expiring` (Dart
///   pauses = checkpoints) and ends the assertion.
/// - `scheduleDeferred` submits a `BGProcessingTaskRequest`
///   (`requiresExternalPower = true`); when iOS runs it, Dart gets
///   `deferredStarted` and processes on the CPU (no Metal work in the
///   background); its expiration handler sends `expiring`.
/// - Processing is never kept alive through the audio session: that is
///   only legitimate while a user-started recording runs (SEC-09).
///
/// Methods on `vaultvoice/processing`: `conditions`, `begin`, `progress`,
/// `end`, `scheduleDeferred`, `completeDeferred({success})`.
/// Events on `vaultvoice/processing/events`: `{kind: conditions, charging,
/// lowPower, thermal}`, `{kind: expiring}`, `{kind: deferredStarted}`.
final class ProcessingPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let methodChannel = "vaultvoice/processing"
  static let eventChannel = "vaultvoice/processing/events"
  /// Must be listed in Info.plist `BGTaskSchedulerPermittedIdentifiers`.
  static let taskIdentifier = "com.vaultvoice.processing"

  /// The BGProcessingTask iOS launched us for (registered at launch, before
  /// the Flutter engine exists).
  private static var deferredTask: BGProcessingTask?
  private static var pendingStart = false
  private static weak var current: ProcessingPlugin?

  private var sink: FlutterEventSink?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var observers: [NSObjectProtocol] = []

  /// Call from `application(_:didFinishLaunchingWithOptions:)` (Apple:
  /// registration must finish before launch completes).
  static func registerBackgroundTask() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
      guard let task = task as? BGProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }
      deferredTask = task
      task.expirationHandler = {
        current?.send(["kind": "expiring"])
        // Dart pauses (checkpoints are per chunk); complete now so iOS does
        // not penalise the app.
        deferredTask?.setTaskCompleted(success: false)
        deferredTask = nil
      }
      if let plugin = current, plugin.sink != nil {
        plugin.send(["kind": "deferredStarted"])
      } else {
        pendingStart = true
      }
    }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ProcessingPlugin()
    let methods = FlutterMethodChannel(name: methodChannel, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: eventChannel, binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    current = instance
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    UIDevice.current.isBatteryMonitoringEnabled = true
    let center = NotificationCenter.default
    for name in [
      ProcessInfo.thermalStateDidChangeNotification,
      Notification.Name.NSProcessInfoPowerStateDidChange,
      UIDevice.batteryStateDidChangeNotification,
    ] {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          guard let self else { return }
          var payload = self.conditions()
          payload["kind"] = "conditions"
          self.send(payload)
        })
    }
    if ProcessingPlugin.pendingStart {
      ProcessingPlugin.pendingStart = false
      send(["kind": "deferredStarted"])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    for o in observers { NotificationCenter.default.removeObserver(o) }
    observers.removeAll()
    sink = nil
    return nil
  }

  private func send(_ payload: [String: Any]) {
    DispatchQueue.main.async { [weak self] in self?.sink?(payload) }
  }

  private func conditions() -> [String: Any] {
    let info = ProcessInfo.processInfo
    let thermal: String
    switch info.thermalState {
    case .nominal: thermal = "nominal"
    case .fair: thermal = "fair"
    case .serious: thermal = "serious"
    case .critical: thermal = "critical"
    @unknown default: thermal = "unknown"
    }
    UIDevice.current.isBatteryMonitoringEnabled = true
    let battery = UIDevice.current.batteryState
    return [
      "charging": battery == .charging || battery == .full,
      "lowPower": info.isLowPowerModeEnabled,
      "thermal": thermal,
    ]
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "conditions":
      result(conditions())
    case "begin":
      if backgroundTask == .invalid {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "vv-processing") {
          [weak self] in
          guard let self else { return }
          self.send(["kind": "expiring"])
          self.endBackgroundTask()
        }
      }
      result(nil)
    case "progress":
      result(nil)
    case "end":
      endBackgroundTask()
      result(nil)
    case "scheduleDeferred":
      let request = BGProcessingTaskRequest(identifier: ProcessingPlugin.taskIdentifier)
      request.requiresExternalPower = true
      request.requiresNetworkConnectivity = false
      do {
        try BGTaskScheduler.shared.submit(request)
        result(nil)
      } catch {
        // Unavailable (simulator, Background App Refresh off): jobs resume
        // when the app is opened again.
        result(FlutterError(code: "unavailable", message: "BGTaskScheduler refused", details: nil))
      }
    case "completeDeferred":
      let success = (call.arguments as? [String: Any])?["success"] as? Bool ?? false
      ProcessingPlugin.deferredTask?.setTaskCompleted(success: success)
      ProcessingPlugin.deferredTask = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func endBackgroundTask() {
    guard backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }
}
