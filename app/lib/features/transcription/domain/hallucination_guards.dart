import 'dart:convert';
import 'dart:io' show ZLibCodec;

import 'package:vaultvoice/core/platform/stt_engine.dart';

/// Why a segment was dropped (counted in diagnostics; never the text).
enum GuardReason {
  /// `no_speech_prob > 0.6 && avg_logprob < -1.0`: decoded "speech" in
  /// silence/noise.
  noSpeech,

  /// A known Whisper hallucination ("Thank you for watching", …).
  knownPhrase,

  /// Same 3-gram ≥ 4× in the segment (decoder loop).
  repetitionLoop,

  /// Identical to the previous segment.
  duplicate,

  /// zlib compression ratio > 2.4 (degenerate, repetitive output).
  compressionRatio,
}

/// Guard thresholds (vv-whisper-stt → Guards; Whisper's own defaults).
const double kNoSpeechProb = 0.6;
const double kLowAvgLogprob = -1;
const int kRepeatedNgram = 3;
const int kRepeatedNgramTimes = 4;
const double kMaxCompressionRatio = 2.4;

/// Known hallucinations on silence/music (normalized: lower-case, no
/// punctuation). A segment consisting only of one of these is dropped.
const Set<String> kKnownHallucinations = {
  'you',
  'thank you for watching',
  'thanks for watching',
  'thank you so much for watching',
  'thank you very much for watching',
  'please subscribe',
  'like and subscribe',
  'please like and subscribe',
  'subscribe to my channel',
  'subtitles by the amaraorg community',
  'subtitles by',
  'subtitled by',
  'transcription by castingwords',
  'blank audio',
  'blankaudio',
  'music',
  'silence',
};

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"[^\p{L}\p{N}\s']", unicode: true), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Whisper's own heuristic: compressed size vs raw size of the UTF-8 text.
double compressionRatio(String text) {
  final raw = utf8.encode(text);
  if (raw.isEmpty) return 0;
  return raw.length / ZLibCodec().encode(raw).length;
}

/// True when some 3-gram occurs ≥ 4 times.
bool hasRepetitionLoop(
  String text, {
  int n = kRepeatedNgram,
  int times = kRepeatedNgramTimes,
}) {
  final words = _normalize(text).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length < n) return false;
  final counts = <String, int>{};
  for (var i = 0; i + n <= words.length; i++) {
    final g = words.sublist(i, i + n).join(' ');
    final c = (counts[g] ?? 0) + 1;
    if (c >= times) return true;
    counts[g] = c;
  }
  return false;
}

/// Checks one segment against the guards; null = keep. [previous] is the
/// last kept segment text (duplicate check across window boundaries too).
GuardReason? guardSegment(TranscriptSegment s, {String? previous}) {
  final noSpeech = s.noSpeechProb;
  final logprob = s.avgLogprob;
  if (noSpeech != null &&
      logprob != null &&
      noSpeech > kNoSpeechProb &&
      logprob < kLowAvgLogprob) {
    return GuardReason.noSpeech;
  }
  final norm = _normalize(s.text);
  if (kKnownHallucinations.contains(norm)) return GuardReason.knownPhrase;
  if (previous != null && norm.isNotEmpty && norm == _normalize(previous)) {
    return GuardReason.duplicate;
  }
  if (hasRepetitionLoop(s.text)) return GuardReason.repetitionLoop;
  // Short texts compress badly by nature; Whisper applies the ratio to
  // whole decodes, we only to segments long enough for it to mean something.
  if (s.text.length >= 40 && compressionRatio(s.text) > kMaxCompressionRatio) {
    return GuardReason.compressionRatio;
  }
  return null;
}

/// Result of [applyGuards].
final class GuardedSegments {
  const GuardedSegments(this.kept, this.dropped);

  final List<TranscriptSegment> kept;

  /// Count per reason (content-free, for diagnostics).
  final Map<GuardReason, int> dropped;
}

/// Filters [segments] (one window, in order). [previous] = last kept text of
/// the previous window.
GuardedSegments applyGuards(
  List<TranscriptSegment> segments, {
  String? previous,
}) {
  final kept = <TranscriptSegment>[];
  final dropped = <GuardReason, int>{};
  var last = previous;
  for (final s in segments) {
    if (s.text.trim().isEmpty) continue;
    final reason = guardSegment(s, previous: last);
    if (reason == null) {
      kept.add(s);
      last = s.text;
    } else {
      dropped[reason] = (dropped[reason] ?? 0) + 1;
    }
  }
  return GuardedSegments(kept, dropped);
}

/// The previous-window context carried into the next window's prompt:
/// vocabulary hints + the last ~[tailChars] characters of what was said
/// (cut at a word boundary).
String? carryPrompt({
  String? vocabulary,
  String? previousText,
  int tailChars = 200,
}) {
  final parts = <String>[];
  if (vocabulary != null && vocabulary.trim().isNotEmpty) {
    parts.add(vocabulary.trim());
  }
  final prev = previousText?.trim() ?? '';
  if (prev.isNotEmpty) {
    if (prev.length <= tailChars) {
      parts.add(prev);
    } else {
      final tail = prev.substring(prev.length - tailChars);
      final space = tail.indexOf(' ');
      parts.add(space < 0 ? tail : tail.substring(space + 1));
    }
  }
  return parts.isEmpty ? null : parts.join(' ');
}
