import AVFoundation
import FlutterMacOS
import Foundation

/// AUD-06 audio import on macOS: AVFoundation decoding only (no ffmpeg).
///
/// Same decoder as `ios/Runner/AudioImportHostApiImpl.swift`:
/// `AVAssetReader` with linear PCM output settings gives 16 kHz mono PCM16 LE
/// (the format contract). Ogg/Opus/Vorbis have no AVFoundation demuxer ->
/// error code `unsupported`. macOS has no "Open in" / share-extension inbox
/// in this build, so `takePendingShares` is always empty (documented,
/// not an error). Never logs file names or paths.
final class AudioImportHostApiImpl: AudioImportHostApi {
  static let shared = AudioImportHostApiImpl()

  var flutterApi: AudioImportFlutterApi?
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
    []
  }
}

/// Registers the import host API.
final class AudioImportPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let api = AudioImportHostApiImpl.shared
    api.flutterApi = AudioImportFlutterApi(binaryMessenger: registrar.messenger)
    AudioImportHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: api)
  }
}
