import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Tokens below this probability are underlined as low-confidence
/// (vv-whisper-stt → Transcript viewer/editor).
const double kLowConfidenceP = 0.5;

/// One decoded token of a segment (`transcript_segments.tokens_json`).
@immutable
final class SegmentToken {
  const SegmentToken({required this.text, required this.p});

  final String text;

  /// Probability 0..1.
  final double p;
}

/// Parses `tokens_json` (`[{text,p,t0_ms,t1_ms}]`); malformed or missing
/// JSON yields no tokens (the viewer then shows no highlighting).
List<SegmentToken> parseTokensJson(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final raw = jsonDecode(json);
    if (raw is! List) return const [];
    return [
      for (final t in raw)
        if (t is Map && t['text'] is String && t['p'] is num)
          SegmentToken(
            text: t['text'] as String,
            p: (t['p'] as num).toDouble(),
          ),
    ];
  } on FormatException {
    return const [];
  }
}

/// Character range `[start, end)` in a segment's text.
typedef TextSpanRange = ({int start, int end});

/// Low-confidence ranges of [text] from its [tokens]. Tokens are located in
/// order (whisper tokens concatenate to the segment text, modulo the
/// leading space we trim and special tokens like `[_BEG_]`, which are
/// skipped because they are not found). Whitespace-only tokens never
/// highlight.
List<TextSpanRange> lowConfidenceRanges(
  String text,
  List<SegmentToken> tokens, {
  double threshold = kLowConfidenceP,
}) {
  final out = <TextSpanRange>[];
  var cursor = 0;
  for (final t in tokens) {
    final piece = t.text.trim();
    if (piece.isEmpty || piece.startsWith('[_') || piece.startsWith('<|')) {
      continue;
    }
    final at = text.indexOf(piece, cursor);
    if (at < 0) continue;
    cursor = at + piece.length;
    if (t.p >= threshold) continue;
    if (out.isNotEmpty && out.last.end >= at) {
      out[out.length - 1] = (start: out.last.start, end: cursor);
    } else {
      out.add((start: at, end: cursor));
    }
  }
  return out;
}

/// A segment as the viewer shows it.
@immutable
final class TranscriptSegmentView {
  const TranscriptSegmentView({
    required this.id,
    required this.seq,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.originalText,
    this.speaker,
    this.tokens = const [],
  });

  /// Row id (edits address it).
  final int id;
  final int seq;
  final int startMs;
  final int endMs;
  final String text;

  /// Pre-edit text (set by the first edit, kept forever).
  final String? originalText;

  /// Speaker label or the user's display name for it; null without
  /// diarization.
  final String? speaker;
  final List<SegmentToken> tokens;

  bool get edited => originalText != null && originalText != text;

  /// Copy with the speaker's display name.
  TranscriptSegmentView withSpeaker(String? name) => TranscriptSegmentView(
    id: id,
    seq: seq,
    startMs: startMs,
    endMs: endMs,
    text: text,
    originalText: originalText,
    speaker: name,
    tokens: tokens,
  );

  /// Low-confidence ranges of the current text. Token probabilities belong
  /// to the STT output, so an edited segment shows none.
  List<TextSpanRange> get lowConfidence =>
      originalText != null && originalText != text
      ? const []
      : lowConfidenceRanges(text, tokens);
}

/// What a timeline marker records.
enum TranscriptMarkerKind {
  /// User bookmark (AUD-08 "Mark").
  user,

  /// Audio gap (recovery, low storage).
  gap,

  /// Recording stopped by a call (SEC-09).
  callInterruption,
}

/// A user marker (AUD-08) or other timeline marker in the transcript.
@immutable
final class TranscriptMarkerView {
  const TranscriptMarkerView({
    required this.id,
    required this.atMs,
    this.label,
    this.kind = TranscriptMarkerKind.user,
  });

  final int id;
  final int atMs;
  final String? label;
  final TranscriptMarkerKind kind;
}

/// One row of the transcript list.
sealed class TranscriptItem {
  const TranscriptItem();

  /// Recording time the row sits at.
  int get atMs;
}

final class SegmentItem extends TranscriptItem {
  const SegmentItem(this.segment, this.index);

  final TranscriptSegmentView segment;

  /// Index into the segment list (playback highlight).
  final int index;

  @override
  int get atMs => segment.startMs;
}

final class MarkerItem extends TranscriptItem {
  const MarkerItem(this.marker);

  final TranscriptMarkerView marker;

  @override
  int get atMs => marker.atMs;
}

/// Interleaves [markers] with [segments] (both on the recording timeline):
/// a marker is placed before the first segment that starts after it, so a
/// marker inside a segment follows that segment and a marker in a pause
/// sits between the two segments around it. Ties (marker at a segment
/// start) put the marker first. Input orders do not matter.
List<TranscriptItem> interleaveMarkers(
  List<TranscriptSegmentView> segments,
  List<TranscriptMarkerView> markers,
) {
  final segs = [...segments]..sort((a, b) => a.startMs.compareTo(b.startMs));
  final marks = [...markers]..sort((a, b) => a.atMs.compareTo(b.atMs));
  final out = <TranscriptItem>[];
  var m = 0;
  for (final (i, s) in segs.indexed) {
    while (m < marks.length && marks[m].atMs <= s.startMs) {
      out.add(MarkerItem(marks[m++]));
    }
    out.add(SegmentItem(s, i));
  }
  while (m < marks.length) {
    out.add(MarkerItem(marks[m++]));
  }
  return out;
}

/// Index of the segment playing at [positionMs] (recording time): the last
/// segment with `startMs <= position`, if the position is before its end;
/// in a gap between segments the previous one stays highlighted until the
/// next starts. -1 before the first segment. [segments] sorted by start.
int activeSegmentIndex(List<TranscriptSegmentView> segments, int positionMs) {
  var lo = 0;
  var hi = segments.length - 1;
  var found = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (segments[mid].startMs <= positionMs) {
      found = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return found;
}

/// A find match: segment row id + character range.
typedef FindMatch = ({int segmentId, int start, int end});

/// All occurrences of [query] in [segments] (case-insensitive unless
/// [caseSensitive]). Empty query → no matches.
List<FindMatch> findInTranscript(
  List<TranscriptSegmentView> segments,
  String query, {
  bool caseSensitive = false,
}) {
  if (query.isEmpty) return const [];
  final q = caseSensitive ? query : query.toLowerCase();
  final out = <FindMatch>[];
  for (final s in segments) {
    final t = caseSensitive ? s.text : s.text.toLowerCase();
    var from = 0;
    while (true) {
      final at = t.indexOf(q, from);
      if (at < 0) break;
      out.add((segmentId: s.id, start: at, end: at + q.length));
      from = at + q.length;
    }
  }
  return out;
}

/// Replace-all edits: segment row id → new text, only for segments that
/// change. Scoped to the given transcript's [segments].
Map<int, String> replaceInTranscript(
  List<TranscriptSegmentView> segments,
  String find,
  String replacement, {
  bool caseSensitive = false,
}) {
  if (find.isEmpty) return const {};
  final pattern = RegExp(RegExp.escape(find), caseSensitive: caseSensitive);
  return {
    for (final s in segments)
      if (pattern.hasMatch(s.text))
        s.id: s.text.replaceAll(pattern, replacement),
  };
}
