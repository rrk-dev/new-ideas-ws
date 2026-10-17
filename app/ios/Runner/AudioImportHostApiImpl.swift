import AVFoundation
import Flutter
import Foundation
import UIKit

/// AUD-06 audio import on iOS: AVFoundation decoding only (no ffmpeg) and
/// files handed over by "Open in" / the share sheet.
///
/// * `decodeToPcm`: `AVAssetReader` + `AVAssetReaderTrackOutput` with linear
///   PCM output settings — AVFoundation resamples and down-mixes to 16 kHz
///   mono PCM16 LE itself (the format contract). Decodes m4a/AAC, mp3, wav,
///   aiff, caf and flac (iOS 11+); **not** Ogg/Opus/Vorbis (no AVFoundation
///   demuxer) → error code `unsupported`.
/// * Shares: `SceneDelegate` forwards `openURLContexts` here ("Open in" /
///   "Copy to Lumen" via `CFBundleDocumentTypes`); the share extension
///   (follow-up AUD-10) drops files into the App Group inbox
///   `group.<bundle id>/Inbox/Audio`, which is drained on every
///   `takePendingShares`. Files are copied into `tmp/shared_audio` at once.
/// * Never logs file names or paths.
final class AudioImportHostApiImpl: AudioImportHostApi {
  static let shared = AudioImportHostApiImpl()

  var flutterApi: AudioImportFlutterApi?
  private var pending: [SharedAudioFile] = []
  private let lock = NSLock()
  private let queue = DispatchQueue(label: "vaultvoice.audio-import", qos: .userInitiated)

  // MARK: - Decoding

  func decodeToPcm(
    srcPath: String, dstPath: String,
    completion: @escaping (Result<DecodedAudio, Error>) -> Void
  ) {
    queue.async {
      let result: Result<DecodedAudio, Error>
      do {
        result = .success(try Self.decode(src: URL(fileURLWithPath: srcPath),
                                          dst: URL(fileURLWithPath: dstPath)))
      } catch let e as AudioImportPigeonError {
        result = .failure(e)
      } catch {
        result = .failure(AudioImportPigeonError(code: "failed", message: "\(type(of: error))", details: nil))
      }
      DispatchQueue.main.async { completion(result) }
    }
  }

  private static func decode(src: URL, dst: URL) throws -> DecodedAudio {
    let asset = AVURLAsset(url: src)
    // Synchronous track access is deprecated from iOS 16 but still correct
    // on this background queue; the async `load(.tracks)` needs a Task.
    let tracks = asset.tracks(withMediaType: .audio)
    guard let track = tracks.first else {
      // Unreadable container (Ogg/Opus, garbage) or a video without audio.
      throw AudioImportPigeonError(
        code: asset.isReadable ? "no_audio" : "unsupported", message: "no audio track", details: nil)
    }
    let reader: AVAssetReader
    do {
      reader = try AVAssetReader(asset: asset)
    } catch {
      throw AudioImportPigeonError(code: "unsupported", message: "reader", details: nil)
    }
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else {
      throw AudioImportPigeonError(code: "unsupported", message: "output", details: nil)
    }
    reader.add(output)
    guard reader.startReading() else {
      throw AudioImportPigeonError(code: "unsupported", message: "start", details: nil)
    }
    FileManager.default.createFile(atPath: dst.path, contents: nil)
    let handle = try FileHandle(forWritingTo: dst)
    defer { try? handle.close() }
    var bytes = 0
    while let sample = output.copyNextSampleBuffer() {
      if let block = CMSampleBufferGetDataBuffer(sample) {
        let length = CMBlockBufferGetDataLength(block)
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { raw -> OSStatus in
          guard let base = raw.baseAddress else { return -1 }
          return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: base)
        }
        if status == kCMBlockBufferNoErr {
          handle.write(data)
          bytes += length
        }
      }
      CMSampleBufferInvalidate(sample)
    }
    if reader.status == .failed {
      throw AudioImportPigeonError(code: "failed", message: "read", details: nil)
    }
    var created: Int64?
    if let date = asset.creationDate?.dateValue {
      created = Int64(date.timeIntervalSince1970 * 1000)
    }
    return DecodedAudio(sampleRate: 16000, channels: 1, frames: Int64(bytes / 2), creationDateMs: created)
  }

  // MARK: - Shares

  func takePendingShares() throws -> [SharedAudioFile] {
    drainAppGroupInbox()
    lock.lock()
    defer { lock.unlock() }
    let out = pending
    pending.removeAll()
    return out
  }

  /// "Open in" / "Copy to Lumen": copy now (the URL may be a
  /// security-scoped document in another app's container).
  func handleOpenedUrls(_ urls: [URL]) {
    var added = false
    for url in urls where Self.isAudio(url) {
      if let f = copyIn(url, removeSource: false) { append(f); added = true }
    }
    if added { notifyDart() }
  }

  /// Files the share extension left in the App Group container.
  private func drainAppGroupInbox() {
    guard let inbox = Self.appGroupInbox() else { return }
    let files = (try? FileManager.default.contentsOfDirectory(
      at: inbox, includingPropertiesForKeys: nil)) ?? []
    for url in files where Self.isAudio(url) {
      if let f = copyIn(url, removeSource: true) { append(f) }
    }
  }

  private func append(_ f: SharedAudioFile) {
    lock.lock()
    pending.append(f)
    lock.unlock()
  }

  private func notifyDart() {
    DispatchQueue.main.async { self.flutterApi?.sharesAvailable { _ in } }
  }

  private func copyIn(_ url: URL, removeSource: Bool) -> SharedAudioFile? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("shared_audio", isDirectory: true)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let ext = url.pathExtension.lowercased()
    let dst = dir.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"))
    do {
      try fm.copyItem(at: url, to: dst)
      if removeSource { try? fm.removeItem(at: url) }
      var created: Int64?
      if let attrs = try? fm.attributesOfItem(atPath: url.path),
        let date = (attrs[.creationDate] ?? attrs[.modificationDate]) as? Date
      {
        created = Int64(date.timeIntervalSince1970 * 1000)
      }
      return SharedAudioFile(path: dst.path, fileExtension: ext.isEmpty ? nil : ext, creationDateMs: created)
    } catch {
      NSLog("VVAudioImport: share copy failed (%@)", "\(type(of: error))")
      return nil
    }
  }

  private static let audioExtensions: Set<String> = [
    "m4a", "aac", "mp3", "wav", "wave", "aif", "aiff", "caf", "flac", "ogg", "oga", "opus", "mp4",
  ]

  /// Extensions we accept from the share sheet; Ogg/Opus are accepted so the
  /// app can show "not supported on iPhone" instead of silently ignoring them.
  static func isAudio(_ url: URL) -> Bool {
    audioExtensions.contains(url.pathExtension.lowercased())
  }

  /// `group.<main app bundle id>/Inbox/Audio`; nil until the App Group
  /// entitlement exists (AUD-10).
  static func appGroupInbox() -> URL? {
    guard let bundleId = Bundle.main.bundleIdentifier,
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.\(bundleId)")
    else { return nil }
    return container.appendingPathComponent("Inbox/Audio", isDirectory: true)
  }
}

/// Registers the import host API and receives "Open in" URLs through
/// Flutter's scene life-cycle forwarding (Flutter 3.47.7
/// `FlutterSceneLifeCycleDelegate`, `registrar.addSceneDelegate`), so
/// `SceneDelegate` stays Flutter's default.
final class AudioImportPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static func register(with registrar: FlutterPluginRegistrar) {
    let api = AudioImportHostApiImpl.shared
    api.flutterApi = AudioImportFlutterApi(binaryMessenger: registrar.messenger())
    AudioImportHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: api)
    let instance = AudioImportPlugin()
    registrar.publish(instance)
    registrar.addSceneDelegate(instance)
  }

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    let urls = connectionOptions?.urlContexts.map { $0.url } ?? []
    let audio = urls.filter { AudioImportHostApiImpl.isAudio($0) }
    guard !audio.isEmpty else { return false }
    AudioImportHostApiImpl.shared.handleOpenedUrls(audio)
    return true
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    let audio = URLContexts.map { $0.url }.filter { AudioImportHostApiImpl.isAudio($0) }
    guard !audio.isEmpty else { return false }
    AudioImportHostApiImpl.shared.handleOpenedUrls(audio)
    return true
  }
}
