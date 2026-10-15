// Pigeon definition for audio file import (AUD-06): native decoding with the
// platform codecs (iOS AVFoundation `AVAssetReader`, Android `MediaExtractor`
// + `MediaCodec`) and files handed over by the OS share sheet / "Open in".
// Regenerate after editing (from app/):
//   fvm dart run pigeon --input pigeons/audio_import_api.dart
//   fvm dart format lib/features/recording/data/pigeon/audio_import_api.g.dart
//
// Verified against pigeon 29.0.8.
//
// Error contract: `decodeToPcm` fails with a `PlatformException` whose `code`
// is one of the `AudioImportErrorCodes` constants on the Dart side
// (`lib/features/recording/data/pigeon_audio_decoder.dart`):
//   unsupported - the container/codec cannot be decoded on this platform
//   no_audio    - the file has no audio track
//   failed      - decoding failed (corrupt file, IO error)
// Messages are content-free (never a file name or path).
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/recording/data/pigeon/audio_import_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Runner/AudioImportApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'AudioImportPigeonError'),
    kotlinOut: 'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/audioimport/AudioImportApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.vaultvoice.vaultvoice.audioimport',
      errorClassName: 'AudioImportFlutterError',
    ),
    dartPackageName: 'vaultvoice',
  ),
)
/// What `decodeToPcm` wrote: raw interleaved PCM16 LE frames.
class DecodedAudio {
  DecodedAudio({
    required this.sampleRate,
    required this.channels,
    required this.frames,
    this.creationDateMs,
  });

  /// Sample rate of the written PCM (iOS: always 16000 — AVAssetReader
  /// resamples; Android: the codec's output rate).
  int sampleRate;

  /// Channel count of the written PCM (iOS: always 1).
  int channels;

  /// Frames (samples per channel) written.
  int frames;

  /// Recording date from the file's metadata (epoch ms), if any.
  int? creationDateMs;
}

/// A file the OS handed to the app (Android `ACTION_SEND`/`ACTION_VIEW`,
/// iOS "Open in" / share extension App Group inbox), already copied into
/// app-private storage (URI grants are temporary).
class SharedAudioFile {
  SharedAudioFile({
    required this.path,
    this.fileExtension,
    this.creationDateMs,
  });

  /// Absolute path of the private copy; the app deletes it after import.
  String path;

  /// Lower-case extension without the dot (from the name or MIME type).
  String? fileExtension;

  /// Last-modified / creation date reported by the source, if any.
  int? creationDateMs;
}

@HostApi()
abstract class AudioImportHostApi {
  /// Decodes the first audio track of [srcPath] into raw PCM16 LE at
  /// [dstPath] (overwritten). Runs off the main thread.
  @asyncCallback
  DecodedAudio decodeToPcm(String srcPath, String dstPath);

  /// Files received from the share sheet since the last call (each returned
  /// once).
  List<SharedAudioFile> takePendingShares();
}

@FlutterApi()
abstract class AudioImportFlutterApi {
  /// New shared files are waiting: call `takePendingShares`.
  @asyncCallback
  void sharesAvailable();
}
