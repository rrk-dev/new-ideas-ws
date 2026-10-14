import AVFoundation
import CallKit
import Flutter

/// SEC-09 CallGuard (iOS), see docs/adr/ADR-SEC-09-recording-policy.md.
///
/// `CXCallObserver` needs no permission and reports cellular calls and every
/// CallKit-based VoIP app (WhatsApp, Teams, FaceTime …): any call with
/// `hasEnded == false` (ringing, dialing, connected, on hold) means "in call".
/// `AVAudioSession` interruption-began is treated as a call-like event;
/// interruption-ended is reported but never resumes anything (the
/// `.shouldResume` option is deliberately not read).
///
/// Only the observer is used — this app never provides calls through CallKit.
///
/// Wire format (event channel): `["signal": <CallGuardSignal name>, "atMs": epoch ms]`.
final class CallGuardPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CXCallObserverDelegate {
  static let methodChannelName = "vaultvoice/call_guard"
  static let eventChannelName = "vaultvoice/call_guard/events"

  private let observer = CXCallObserver()
  private var sink: FlutterEventSink?
  private var lastInCall: Bool?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CallGuardPlugin()
    let methods = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  override init() {
    super.init()
    // nil queue = main queue.
    observer.setDelegate(self, queue: nil)
  }

  private var isInCall: Bool {
    observer.calls.contains { !$0.hasEnded }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isInCall":
      result(isInCall)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    lastInCall = nil
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance())
    evaluate()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self, name: AVAudioSession.interruptionNotification, object: nil)
    sink = nil
    return nil
  }

  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    evaluate()
  }

  private func evaluate() {
    let inCall = isInCall
    if inCall == lastInCall { return }
    lastInCall = inCall
    emit(inCall ? "callActive" : "callEnded")
  }

  @objc private func onInterruption(_ notification: Notification) {
    guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw)
    else { return }
    switch type {
    case .began:
      emit("interruptionBegan")
    case .ended:
      emit("interruptionEnded")
    @unknown default:
      break
    }
  }

  private func emit(_ signal: String) {
    let atMs = Int64(Date().timeIntervalSince1970 * 1000)
    // Explicit type: the inferred `() -> Void?` does not convert to the
    // `() -> Void` block `DispatchQueue.async` expects (found by AUD-04's
    // type-check of the Runner sources).
    let send: () -> Void = { [weak self] in
      self?.sink?(["signal": signal, "atMs": atMs])
    }
    if Thread.isMainThread {
      send()
    } else {
      DispatchQueue.main.async(execute: send)
    }
  }
}
