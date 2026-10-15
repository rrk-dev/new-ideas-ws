import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/diarization_engine.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';

/// Scripted [DiarizationEngine]. Like a real one it keeps speaker embeddings
/// (a sentinel) in memory and may spill them to the scratch directory, so
/// tests can assert nothing of them survives the step.
class FakeDiarizationEngine implements DiarizationEngine {
  FakeDiarizationEngine(this.turns, {this.failure, this.throwAfterScratch});

  static const embeddingSentinel = 'EMBEDDING-SENTINEL-4f9a';

  List<SpeakerTurn> turns;
  final Failure? failure;

  /// Throws after writing the scratch file (simulates a crash mid-run).
  final Exception? throwAfterScratch;

  int calls = 0;
  int? lastNumSpeakers;
  String? lastScratchDir;
  List<SpeechSpan> lastSpans = const [];

  @override
  Future<Result<List<SpeakerTurn>>> diarize(
    List<VadChunk> chunks, {
    List<SpeechSpan> speechSpans = const [],
    int? numSpeakers,
    String? scratchDir,
    CancelToken? cancel,
    void Function(double fraction)? onProgress,
  }) async {
    calls++;
    lastNumSpeakers = numSpeakers;
    lastScratchDir = scratchDir;
    lastSpans = speechSpans;
    if (scratchDir != null) {
      File(p.join(scratchDir, 'embeddings.bin'))
          .writeAsStringSync(embeddingSentinel);
    }
    if (throwAfterScratch != null) throw throwAfterScratch!;
    onProgress?.call(1);
    if (failure != null) return Err(failure!);
    return Ok(turns);
  }

  @override
  Future<void> dispose() async {}
}
