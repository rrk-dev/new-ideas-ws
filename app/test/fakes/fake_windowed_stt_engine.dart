import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';

/// Scripted [WindowedSttEngine] (STT-04). Every window call returns one
/// segment per range, timed on the recording timeline like the real engine
/// (`recordingOffsetMs + file ms`), text `w<call>r<range>` unless [script]
/// supplies segments for that call. [blockOn] (0-based call) hangs until
/// cancelled or [release] completes — for kill/resume tests.
class FakeWindowedSttEngine implements WindowedSttEngine {
  FakeWindowedSttEngine({this.blockOn, this.script = const {}});

  final calls = <List<SttAudioRange>>[];
  final options = <SttOptions>[];
  final Map<int, List<TranscriptSegment>> script;
  int? blockOn;
  final Completer<void> release = Completer();
  Failure? failure;

  bool get blocked => blockOn != null && calls.length > blockOn!;

  @override
  Future<Result<Transcript>> transcribe(
    String audioPath, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options = const SttOptions(),
  }) => transcribeRanges(
    [SttAudioRange(path: audioPath, startMs: 0, endMs: 30000)],
    cancel: cancel,
    onProgress: onProgress,
    onSegment: onSegment,
    options: options,
  );

  @override
  Future<Result<Transcript>> transcribeRanges(
    List<SttAudioRange> ranges, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options = const SttOptions(),
  }) async {
    final call = calls.length;
    calls.add(ranges);
    this.options.add(options);
    if (call == blockOn) {
      while (!(cancel?.isCancelled ?? false) && !release.isCompleted) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
    }
    if (failure case final f?) return Err(f);
    onProgress?.call(1);
    final segments =
        script[call] ??
        [
          for (final (i, r) in ranges.indexed)
            TranscriptSegment(
              start: Duration(milliseconds: r.recordingOffsetMs + r.startMs),
              end: Duration(milliseconds: r.recordingOffsetMs + r.endMs),
              text: 'w${call}r$i',
              avgLogprob: -0.2,
              noSpeechProb: 0.01,
            ),
        ];
    segments.forEach(onSegment ?? (_) {});
    return Ok(Transcript(segments));
  }
}
