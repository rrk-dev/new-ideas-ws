import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vaultvoice/features/recording/data/pigeon/audio_import_api.g.dart';
import 'package:vaultvoice/features/recording/domain/audio_import.dart';

/// Error codes of `AudioImportHostApi.decodeToPcm` (pigeons/audio_import_api).
abstract final class AudioImportErrorCodes {
  static const unsupported = 'unsupported';
  static const noAudio = 'no_audio';
  static const failed = 'failed';
}

/// [AudioDecoder] on the native host API (iOS `AVAssetReader`, Android
/// `MediaExtractor` + `MediaCodec`).
class PigeonAudioDecoder implements AudioDecoder {
  PigeonAudioDecoder([AudioImportHostApi? api])
    : _api = api ?? AudioImportHostApi();

  final AudioImportHostApi _api;

  @override
  Future<DecodeResult> decodeToPcm(String srcPath, String dstPath) async {
    try {
      final d = await _api.decodeToPcm(srcPath, dstPath);
      final created = d.creationDateMs;
      return Decoded(
        DecodedPcm(
          sampleRate: d.sampleRate,
          channels: d.channels,
          frames: d.frames,
          creationDate: created == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(created),
        ),
      );
    } on PlatformException catch (e) {
      return DecodeRefused(switch (e.code) {
        AudioImportErrorCodes.unsupported => DecodeError.unsupported,
        AudioImportErrorCodes.noAudio => DecodeError.noAudio,
        _ => DecodeError.failed,
      });
    } on MissingPluginException {
      // No native decoder on this platform (desktop / tests).
      return const DecodeRefused(DecodeError.unsupported);
    } on Object {
      return const DecodeRefused(DecodeError.failed);
    }
  }
}

/// A file the OS shared with the app, waiting for the user's attestation.
final class SharedAudio {
  const SharedAudio({required this.path, this.extension, this.sourceDate});

  final String path;
  final String? extension;
  final DateTime? sourceDate;
}

/// Files handed over by the share sheet / "Open in" (Android intents, iOS
/// document types and the share-extension App Group inbox), already copied
/// into app storage by the host. [changes] fires when new ones arrive.
abstract interface class SharedAudioInbox {
  Future<List<SharedAudio>> take();

  Stream<void> get changes;
}

class PigeonSharedAudioInbox
    implements SharedAudioInbox, AudioImportFlutterApi {
  PigeonSharedAudioInbox([AudioImportHostApi? api])
    : _api = api ?? AudioImportHostApi() {
    AudioImportFlutterApi.setUp(this);
  }

  final AudioImportHostApi _api;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> sharesAvailable() async => _changes.add(null);

  @override
  Future<List<SharedAudio>> take() async {
    try {
      final files = await _api.takePendingShares();
      return [
        for (final f in files)
          SharedAudio(
            path: f.path,
            extension: f.fileExtension,
            sourceDate: f.creationDateMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(f.creationDateMs!),
          ),
      ];
    } on Object {
      return const [];
    }
  }

  void dispose() {
    AudioImportFlutterApi.setUp(null);
    unawaited(_changes.close());
  }
}
