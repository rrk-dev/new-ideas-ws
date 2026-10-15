import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';

/// A speech interval in ms (`speech_segments`: on the recording timeline).
@immutable
final class SpeechSpan {
  const SpeechSpan(this.startMs, this.endMs);

  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;

  @override
  bool operator ==(Object other) =>
      other is SpeechSpan && other.startMs == startMs && other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);

  @override
  String toString() => 'SpeechSpan($startMs–$endMs)';
}

/// A chunk file as VAD sees it: `path` holds `startMs..endMs` of the
/// recording timeline.
typedef VadChunk = ({String path, int startMs, int endMs});

/// Voice activity detection — the one interface (integration wave 3 unified
/// STT-04's consumer seam with AUD-03's implementation, `FfiVadEngine` on
/// whisper.cpp's Silero VAD behind the native bridge). Runs in the pipeline
/// worker isolate; fakes live in `test/fakes`. The transcribe step asks it
/// once per recording that has no `speech_segments` yet and stores the
/// result; STT-04's windows are cut on those spans. VAD never starts or
/// resumes a recording (SEC-09).
abstract interface class VadEngine {
  /// Speech spans of [chunks] on the recording timeline, sorted, using the
  /// ggml VAD model at [modelPath].
  Future<Result<List<SpeechSpan>>> detect(
    List<VadChunk> chunks, {
    required String modelPath,
    CancelToken? cancel,
  });

  /// Frees the loaded model.
  Future<void> dispose();
}
