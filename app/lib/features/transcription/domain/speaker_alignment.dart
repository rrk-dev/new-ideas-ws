import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/platform/diarization_engine.dart';

/// A transcript segment as the aligner sees it.
@immutable
final class AlignSegment {
  const AlignSegment({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.body,
    this.tokensJson,
  });

  final int id;
  final int startMs;
  final int endMs;
  final String body;

  /// `[{text,p,t0_ms,t1_ms}]` (STT-06), null without token timestamps.
  final String? tokensJson;
}

/// A segment (or a part of one split at a speaker change) with its speaker.
@immutable
final class AlignedPiece {
  const AlignedPiece({
    required this.sourceId,
    required this.startMs,
    required this.endMs,
    required this.body,
    required this.speaker,
    required this.tokensJson,
    required this.isSplit,
  });

  final int sourceId;
  final int startMs;
  final int endMs;
  final String body;

  /// 0-based cluster index, null when there are no turns at all.
  final int? speaker;
  final String? tokensJson;

  /// True when the source segment was cut at a speaker change.
  final bool isSplit;
}

/// Assigns every segment the speaker with the maximum time overlap. A segment
/// that spans a speaker change — each side at least [minSplitMs] long — is
/// split at the token boundary nearest to the change (needs token times;
/// without them the dominant speaker wins). Segments in silence between
/// turns take the nearest turn's speaker. Pieces come back in time order.
List<AlignedPiece> alignSpeakers(
  List<AlignSegment> segments,
  List<SpeakerTurn> turns, {
  int minSplitMs = 1000,
}) {
  final sorted = [...turns]..sort((a, b) => a.startMs.compareTo(b.startMs));
  final out = <AlignedPiece>[];
  for (final s in segments) {
    out.addAll(_alignOne(s, sorted, minSplitMs));
  }
  return out;
}

typedef _Run = ({int speaker, int startMs, int endMs});

List<AlignedPiece> _alignOne(
  AlignSegment s,
  List<SpeakerTurn> turns,
  int minSplitMs,
) {
  if (turns.isEmpty) return [_whole(s, null)];
  final runs = _runs(s, turns);
  if (runs.isEmpty) return [_whole(s, _nearest(s, turns))];

  // A short interjection is absorbed by the surrounding speaker.
  final significant = <_Run>[];
  for (final r in runs) {
    if (r.endMs - r.startMs < minSplitMs) continue;
    if (significant.isNotEmpty && significant.last.speaker == r.speaker) {
      final last = significant.removeLast();
      significant.add((
        speaker: last.speaker,
        startMs: last.startMs,
        endMs: r.endMs,
      ));
    } else {
      significant.add(r);
    }
  }
  final tokens = _tokens(s);
  if (significant.length >= 2 && tokens != null) {
    final pieces = _split(s, significant, tokens);
    if (pieces != null) return pieces;
  }
  final overlap = <int, int>{};
  for (final r in runs) {
    overlap[r.speaker] = (overlap[r.speaker] ?? 0) + r.endMs - r.startMs;
  }
  var best = runs.first.speaker;
  for (final e in overlap.entries) {
    if (e.value > overlap[best]!) best = e.key;
  }
  return [_whole(s, best)];
}

AlignedPiece _whole(AlignSegment s, int? speaker) => AlignedPiece(
  sourceId: s.id,
  startMs: s.startMs,
  endMs: s.endMs,
  body: s.body,
  speaker: speaker,
  tokensJson: s.tokensJson,
  isSplit: false,
);

/// Turns clipped to the segment, adjacent same-speaker runs merged.
List<_Run> _runs(AlignSegment s, List<SpeakerTurn> turns) {
  final runs = <_Run>[];
  for (final t in turns) {
    final a = t.startMs < s.startMs ? s.startMs : t.startMs;
    final b = t.endMs > s.endMs ? s.endMs : t.endMs;
    if (b <= a) continue;
    if (runs.isNotEmpty && runs.last.speaker == t.speaker) {
      final last = runs.removeLast();
      runs.add((
        speaker: last.speaker,
        startMs: last.startMs,
        endMs: b > last.endMs ? b : last.endMs,
      ));
    } else {
      runs.add((speaker: t.speaker, startMs: a, endMs: b));
    }
  }
  return runs;
}

int _nearest(AlignSegment s, List<SpeakerTurn> turns) {
  final mid = (s.startMs + s.endMs) ~/ 2;
  var best = turns.first;
  var bestD = 1 << 62;
  for (final t in turns) {
    final d = mid < t.startMs
        ? t.startMs - mid
        : (mid > t.endMs ? mid - t.endMs : 0);
    if (d < bestD) {
      bestD = d;
      best = t;
    }
  }
  return best.speaker;
}

typedef _Token = ({String text, int t0, int t1, Map<String, Object?> json});

/// Token timestamps shifted so the first token starts at the segment start
/// (per-chunk transcripts store chunk-relative token times).
List<_Token>? _tokens(AlignSegment s) {
  final raw = s.tokensJson;
  if (raw == null) return null;
  try {
    final list = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
    final timed = [
      for (final t in list)
        if (t['t0_ms'] is int && t['t1_ms'] is int) t,
    ];
    if (timed.length < 2) return null;
    var delta = s.startMs - (timed.first['t0_ms']! as int);
    if (delta.abs() <= 500) delta = 0;
    return [
      for (final t in timed)
        (
          text: t['text']! as String,
          t0: (t['t0_ms']! as int) + delta,
          t1: (t['t1_ms']! as int) + delta,
          json: t,
        ),
    ];
  } on Object {
    return null;
  }
}

List<AlignedPiece>? _split(
  AlignSegment s,
  List<_Run> runs,
  List<_Token> tokens,
) {
  // Boundary between two significant runs: midpoint of the gap between them.
  final bounds = [
    for (var i = 0; i + 1 < runs.length; i++)
      (runs[i].endMs + runs[i + 1].startMs) ~/ 2,
  ];
  final groups = List.generate(runs.length, (_) => <_Token>[]);
  for (final t in tokens) {
    final mid = (t.t0 + t.t1) ~/ 2;
    var g = 0;
    while (g < bounds.length && mid >= bounds[g]) {
      g++;
    }
    groups[g].add(t);
  }
  if (groups.any((g) => g.isEmpty)) return null;
  return [
    for (var i = 0; i < runs.length; i++)
      AlignedPiece(
        sourceId: s.id,
        startMs: i == 0 ? s.startMs : groups[i].first.t0,
        endMs: i == runs.length - 1 ? s.endMs : groups[i].last.t1,
        body: groups[i].map((t) => t.text).join().trim(),
        speaker: runs[i].speaker,
        tokensJson: jsonEncode([for (final t in groups[i]) t.json]),
        isSplit: true,
      ),
  ];
}
