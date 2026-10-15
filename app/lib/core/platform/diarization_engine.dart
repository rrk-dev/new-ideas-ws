import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';

/// One anonymous speaker turn on the recording timeline. [speaker] is a
/// 0-based cluster index, meaningless outside the recording (no voiceprints:
/// nothing links it to a person or to another recording).
@immutable
final class SpeakerTurn {
  const SpeakerTurn(this.startMs, this.endMs, this.speaker);

  final int startMs;
  final int endMs;
  final int speaker;

  int get durationMs => endMs - startMs;

  @override
  bool operator ==(Object other) =>
      other is SpeakerTurn &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.speaker == speaker;

  @override
  int get hashCode => Object.hash(startMs, endMs, speaker);

  @override
  String toString() => 'SpeakerTurn($startMs–$endMs: $speaker)';
}

/// Speaker diarization (STT-05): who spoke when, from the recording's audio.
///
/// Privacy contract (SEC-09 / STT-05): speaker embeddings are biometric data.
/// Implementations compute them transiently in memory for clustering only —
/// they never cross this interface, are never written to disk, the DB or a
/// log, and are released before [diarize] returns (also on cancel/failure).
/// The result is anonymous turns only. Any intermediate file an engine
/// needs goes under [diarize]'s `scratchDir`, which the pipeline step deletes
/// when the step ends (success, failure or cancel).
///
/// Runs in the pipeline worker isolate after STT; fakes live in `test/fakes`.
abstract interface class DiarizationEngine {
  /// Turns of [chunks] (same chunk files STT used) on the recording
  /// timeline, sorted by start. [speechSpans] (VAD) bound the analysis when
  /// given. [numSpeakers] fixes the cluster count (2–8); null = automatic.
  Future<Result<List<SpeakerTurn>>> diarize(
    List<VadChunk> chunks, {
    List<SpeechSpan> speechSpans = const [],
    int? numSpeakers,
    String? scratchDir,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  });

  /// Frees the loaded models.
  Future<void> dispose();
}
