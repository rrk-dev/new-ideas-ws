import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// `hh:mm:ss` for a transcript offset (evidence timestamps, vv-llm-inference).
String formatTimestamp(int ms) {
  final s = ms ~/ 1000;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two(s ~/ 60 % 60)}:${two(s % 60)}';
}

/// Milliseconds of an `hh:mm:ss` string, or null.
int? parseTimestamp(String? t) {
  if (t == null) return null;
  final m = RegExp(r'^(\d{2}):([0-5]\d):([0-5]\d)$').firstMatch(t);
  if (m == null) return null;
  return ((int.parse(m[1]!) * 60 + int.parse(m[2]!)) * 60 + int.parse(m[3]!)) *
      1000;
}

/// One transcript segment as the prompt shows it:
/// `[hh:mm:ss] Speaker: text` (speaker omitted without diarization).
@immutable
final class TranscriptLine {
  const TranscriptLine({
    required this.startMs,
    required this.text,
    this.speaker,
  });

  final int startMs;
  final String? speaker;
  final String text;

  String render() {
    final who = speaker == null || speaker!.isEmpty ? '' : '$speaker: ';
    return '[${formatTimestamp(startMs)}] $who${text.trim()}';
  }
}

/// A contiguous range of transcript lines for one map call.
@immutable
final class TranscriptChunk {
  const TranscriptChunk({
    required this.index,
    required this.start,
    required this.end,
    required this.overlapLines,
    required this.tokens,
  });

  final int index;

  /// Line range `[start, end)` into the chunker's input.
  final int start;
  final int end;

  /// Leading lines repeated from the previous chunk (context overlap).
  final int overlapLines;

  /// Estimated transcript tokens (sum of per-line counts).
  final int tokens;

  Map<String, Object?> toJson() => {'s': start, 'e': end, 'o': overlapLines};

  @override
  bool operator ==(Object other) =>
      other is TranscriptChunk &&
      other.index == index &&
      other.start == start &&
      other.end == end &&
      other.overlapLines == overlapLines;

  @override
  int get hashCode => Object.hash(index, start, end, overlapLines);
}

/// Splits a transcript into map chunks of at most [maxTokens] transcript
/// tokens on segment boundaries (a segment is never cut), preferring to end a
/// chunk where the speaker changes, with about [overlapTokens] of the
/// previous chunk's last lines repeated at the start of the next one.
///
/// [lineTokens]`[i]` is the exact token count of `lines[i].render()` as
/// counted alone (its BOS stands in for the joining newline). Lines longer
/// than a chunk must be split first ([splitLongLines]).
List<TranscriptChunk> chunkTranscript(
  List<TranscriptLine> lines,
  List<int> lineTokens, {
  required int maxTokens,
  required int overlapTokens,
  double speakerCutWindow = 0.2,
}) {
  assert(lines.length == lineTokens.length, 'one count per line');
  final chunks = <TranscriptChunk>[];
  var start = 0;
  var overlap = 0;
  var prevEnd = 0;
  while (start < lines.length) {
    var end = start;
    var sum = 0;
    while (end < lines.length && sum + lineTokens[end] <= maxTokens) {
      sum += lineTokens[end];
      end++;
    }
    if (overlap > 0 && end <= prevEnd) {
      // The overlap leaves no room for a new line: restart without it.
      start = prevEnd;
      overlap = 0;
      continue;
    }
    if (end == start) {
      // A single line over budget: emit it alone; the caller re-splits.
      end = start + 1;
      sum = lineTokens[start];
    } else if (end < lines.length) {
      // Prefer a speaker boundary within the last [speakerCutWindow] of the
      // chunk (the next chunk then starts with a new turn).
      final floor = maxTokens * (1 - speakerCutWindow);
      var acc = sum;
      for (var cut = end; cut > start + overlap + 1; cut--) {
        if (acc < floor) break;
        final a = lines[cut - 1].speaker;
        final b = lines[cut].speaker;
        if (a != null && b != null && a != b) {
          end = cut;
          sum = acc;
          break;
        }
        acc -= lineTokens[cut - 1];
      }
    }
    chunks.add(
      TranscriptChunk(
        index: chunks.length,
        start: start,
        end: end,
        overlapLines: overlap,
        tokens: sum,
      ),
    );
    if (end >= lines.length) break;
    prevEnd = end;
    // Next chunk starts ~overlapTokens before `end`, but always advances.
    var next = end;
    var acc = 0;
    while (next - 1 > start && acc + lineTokens[next - 1] <= overlapTokens) {
      acc += lineTokens[next - 1];
      next--;
    }
    overlap = end - next;
    start = next;
  }
  return chunks;
}

/// Splits lines whose token count exceeds [maxLineTokens] into word pieces
/// with the same timestamp/speaker (long unpunctuated STT segments). Token
/// counts of the pieces are estimated proportionally; callers recount.
List<TranscriptLine> splitLongLines(
  List<TranscriptLine> lines,
  List<int> lineTokens,
  int maxLineTokens,
) {
  final out = <TranscriptLine>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (lineTokens[i] <= maxLineTokens) {
      out.add(l);
      continue;
    }
    final words = l.text.trim().split(RegExp(r'\s+'));
    final pieces = (lineTokens[i] / maxLineTokens).ceil() + 1;
    final per = (words.length / pieces).ceil().clamp(1, words.length);
    final totalChars = l.text.runes.length;
    for (var w = 0; w < words.length; w += per) {
      final to = w + per > words.length ? words.length : w + per;
      final text = words.sublist(w, to).join(' ');
      // Text without whitespace (e.g. Chinese, one huge token) cannot be cut
      // at words: cut it by characters, sized from the proportional estimate.
      final estimate = lineTokens[i] * text.runes.length / totalChars;
      if (estimate <= maxLineTokens || text.runes.length < 2) {
        out.add(
          TranscriptLine(startMs: l.startMs, speaker: l.speaker, text: text),
        );
        continue;
      }
      final runes = text.runes.toList();
      final parts = (estimate / maxLineTokens).ceil() + 1;
      final size = (runes.length / parts).ceil().clamp(1, runes.length);
      for (var c = 0; c < runes.length; c += size) {
        out.add(
          TranscriptLine(
            startMs: l.startMs,
            speaker: l.speaker,
            text: String.fromCharCodes(
              runes.sublist(c, math.min(c + size, runes.length)),
            ),
          ),
        );
      }
    }
  }
  return out;
}
