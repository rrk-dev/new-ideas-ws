import AVFoundation
import Flutter

/// AUD-04: reports audio-session changes that affect a running recording
/// (docs/adr/ADR-AUD-04-ios-background-recording.md). Observers run only
/// while Dart listens (= while a recording is open).
///
/// - `AVAudioSession.routeChangeNotification` → `routeChanged` (AirPods /
///   wired headset connected or removed). Recording continues; Dart logs it.
/// - `AVAudioEngineConfigurationChange` (any engine in the process — the
///   `record` plugin's input engine) → `engineConfigurationChanged`: the engine
///   stopped because the I/O format changed; Dart reopens the input.
/// - `AVAudioSession.mediaServicesWereResetNotification` → `mediaServicesReset`:
///   Dart rebuilds the input and continues in a new chunk.
///
/// Interruptions (calls, Siri, alarms) are reported by `CallGuardPlugin` and
/// pause the recording; nothing here resumes capture after an interruption.
/// Wire format: `["kind": String, "reason": String?, "inputs": [String]]` with
/// port types only (never device names).
final class AudioSessionPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let eventChannelName = "vaultvoice/audio_session/events"
  /// The event channel keeps only a weak-ish reference path; hold the handler.
  private static var shared: AudioSessionPlugin?

  private var sink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AudioSessionPlugin()
    shared = instance
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    removeObservers()
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(
        forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
      ) { [weak self] note in
        self?.emit("routeChanged", reason: Self.reasonName(note))
      })
    observers.append(
      center.addObserver(
        forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
      ) { [weak self] _ in
        self?.emit("engineConfigurationChanged", reason: nil)
      })
    observers.append(
      center.addObserver(
        forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
      ) { [weak self] _ in
        self?.emit("mediaServicesReset", reason: nil)
      })
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    removeObservers()
    sink = nil
    return nil
  }

  private func removeObservers() {
    for o in observers {
      NotificationCenter.default.removeObserver(o)
    }
    observers.removeAll()
  }

  private func emit(_ kind: String, reason: String?) {
    let inputs = AVAudioSession.sharedInstance().currentRoute.inputs.map { $0.portType.rawValue }
    var event: [String: Any] = ["kind": kind, "inputs": inputs]
    if let reason = reason {
      event["reason"] = reason
    }
    sink?(event)
  }

  private static func reasonName(_ note: Notification) -> String? {
    guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
      let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
    else { return nil }
    switch reason {
    case .newDeviceAvailable: return "newDeviceAvailable"
    case .oldDeviceUnavailable: return "oldDeviceUnavailable"
    case .categoryChange: return "categoryChange"
    case .override: return "override"
    case .wakeFromSleep: return "wakeFromSleep"
    case .noSuitableRouteForCategory: return "noSuitableRouteForCategory"
    case .routeConfigurationChange: return "routeConfigurationChange"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }
}
