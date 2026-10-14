import CoreAudio
import FlutterMacOS
import Foundation

/// AUD-09: tells Dart when the default input device disappears.
///
/// Does not open the microphone. Capture stays in the `record` package
/// (`RecordMicSource`, record_macos 2.1.1), which uses `AVCaptureDevice`
/// microphone types only. FND-09 compiles this file into the macOS runner
/// and calls `MacAudioRouteObserver.register(with:)`.
///
/// Property names match record_macos 2.1.1 (`kAudioObjectPropertyElementMain`,
/// `kAudioHardwarePropertyDefaultInputDevice`). Wire format matches
/// `MethodChannelAudioSessionMonitor`: kind `routeChanged`, reason
/// `oldDeviceUnavailable` when the default input is gone. Device names are
/// not sent.
final class MacAudioRouteObserver: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let eventChannelName = "vaultvoice/audio_session/events"

  private static var shared: MacAudioRouteObserver?
  private var sink: FlutterEventSink?
  private var listening = false
  private let queue = DispatchQueue.main

  private lazy var listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
    self?.emitDefaultInput()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MacAudioRouteObserver()
    shared = instance
    let events = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    guard !listening else { return nil }
    var address = Self.defaultInputAddress
    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      queue,
      listener
    )
    listening = status == noErr
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if listening {
      var address = Self.defaultInputAddress
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        queue,
        listener
      )
      listening = false
    }
    sink = nil
    return nil
  }

  private func emitDefaultInput() {
    guard let sink else { return }
    var address = Self.defaultInputAddress
    var device = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &device
    )
    let removed = status != noErr || device == kAudioObjectUnknown
    sink([
      "kind": "routeChanged",
      "reason": removed ? "oldDeviceUnavailable" : "newDeviceAvailable",
      "inputs": removed ? [String]() : ["microphone"],
    ])
  }

  private static var defaultInputAddress: AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
  }
}
