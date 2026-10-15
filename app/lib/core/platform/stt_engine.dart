import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';

/// One token with its probability (low-confidence highlighting, STT-06).
class TranscriptToken {
  const TranscriptToken({
    required this.text,
    required this.p,
    this.start,
    this.end,
  });

  final String text;

  /// Probability 0..1.
  final double p;

  /// Token times (only with `SttOptions.tokenTimestamps`).
  final Duration? start;
  final Duration? end;
}

/// One timed piece of transcript text.
class TranscriptSegment {
  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
    this.avgLogprob,
    this.noSpeechProb,
    this.tokens = const [],
  });

  final Duration start;
  final Duration end;
  final String text;

  /// Mean token log-probability (confidence); null when unknown.
  final double? avgLogprob;

  /// Probability that the segment is not speech (hallucination guard).
  final double? noSpeechProb;
  final List<TranscriptToken> tokens;
}

/// Result of transcribing one audio file.
class Transcript {
  const Transcript(this.segments);

  final List<TranscriptSegment> segments;

  String get text => segments.map((s) => s.text).join(' ');
}

/// Decoding options (vv-whisper-stt defaults table). Vocabulary hints come
/// from the profile (product/team names) and are never logged.
class SttOptions {
  const SttOptions({
    this.language = 'en',
    this.initialPrompt,
    this.beamSize = 1,
    this.temperatureFallback = true,
    this.tokenTimestamps = false,
    this.threads = 0,
    this.vadModelPath,
  });

  /// `en`, `de`, … or `auto` (multilingual models only).
  final String language;

  /// Vocabulary hints / previous-window tail, carried into every window.
  final String? initialPrompt;

  /// 1 = greedy (Low tier), 5 = beam search (Mid/High tier).
  final int beamSize;

  /// Retry with higher temperature when decoding fails the thresholds.
  final bool temperatureFallback;
  final bool tokenTimestamps;

  /// 0 = performance cores capped at 4.
  final int threads;

  /// AUD-03: ggml Silero VAD model. When set, silence is skipped before
  /// decoding (less compute, no hallucinated text on silence) and segment
  /// times stay on the original audio timeline. Null = no VAD.
  final String? vadModelPath;
}

/// Called for every segment as soon as it is decoded.
typedef SegmentCallback = void Function(TranscriptSegment segment);

/// Speech-to-text (whisper.cpp behind the native bridge).
abstract interface class SttEngine {
  Future<Result<Transcript>> transcribe(
    String audioPath, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options = const SttOptions(),
  });
}

/// One file range of a transcription window (`vv_audio_range`, STT-04):
/// `[startMs, endMs)` of [path]; file time 0 is at [recordingOffsetMs] on
/// the recording timeline.
class SttAudioRange {
  const SttAudioRange({
    required this.path,
    required this.startMs,
    required this.endMs,
    this.recordingOffsetMs = 0,
  });

  final String path;
  final int startMs;
  final int endMs;
  final int recordingOffsetMs;
}

/// An engine that decodes a window of several file ranges in one
/// `whisper_full` (native concatenation, no temp WAVs — STT-04). Segment
/// times are on the **recording** timeline (range offset + file time).
abstract interface class WindowedSttEngine implements SttEngine {
  Future<Result<Transcript>> transcribeRanges(
    List<SttAudioRange> ranges, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    SegmentCallback? onSegment,
    SttOptions options = const SttOptions(),
  });
}
