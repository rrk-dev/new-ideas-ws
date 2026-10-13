// failWith mirrors the vv-testing fake contract; a setter reads poorly.
// ignore_for_file: use_setters_to_change_properties

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';

/// Scripted [SttEngine]: emits [segments] one per [perChunk], with progress,
/// cancellation and injectable failure.
class FakeSttEngine implements SttEngine {
  FakeSttEngine({
    this.segments = const [
      TranscriptSegment(
        start: Duration.zero,
        end: Duration(seconds: 2),
        text: 'hello world',
      ),
    ],
    this.perChunk = Duration.zero,
  });

  final List<TranscriptSegment> segments;
  final Duration perChunk;
  Failure? _failure;
  final List<String> calls = [];

  void failWith(Failure failure) => _failure = failure;

  @override
  Future<Result<Transcript>> transcribe(
    String audioPath, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
  }) async {
    calls.add(audioPath);
    if (_failure case final failure?) return Err(failure);
    for (var i = 0; i < segments.length; i++) {
      if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
      await Future<void>.delayed(perChunk);
      onProgress?.call((i + 1) / segments.length);
    }
    if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
    return Ok(Transcript(segments));
  }
}
