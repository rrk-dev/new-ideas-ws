import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';

/// A speech interval on the recording timeline (`speech_segments`).
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

/// A chunk file as VAD sees it.
typedef VadChunk = ({String path, int startMs, int endMs});

/// Voice activity detection (AUD-03 owns the implementation and the model;
/// FND-02 engine-interface pattern: real impl in `features/recording/data`,
/// fake in `test/fakes`). STT-04 only consumes it: when a recording has no
/// `speech_segments` yet, the transcribe step asks VAD once and stores the
/// result. VAD never starts or resumes a recording (SEC-09).
abstract interface class VadEngine {
  /// Speech spans of [chunks] on the recording timeline, sorted.
  Future<Result<List<SpeechSpan>>> detect(
    List<VadChunk> chunks, {
    CancelToken? cancel,
  });
}
