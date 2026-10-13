import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';

/// One timed piece of transcript text.
class TranscriptSegment {
  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

/// Result of transcribing one audio file.
class Transcript {
  const Transcript(this.segments);

  final List<TranscriptSegment> segments;

  String get text => segments.map((s) => s.text).join(' ');
}

/// Speech-to-text (whisper.cpp behind the native bridge).
abstract interface class SttEngine {
  Future<Result<Transcript>> transcribe(
    String audioPath, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
  });
}
