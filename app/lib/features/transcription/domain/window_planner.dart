import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/platform/vad_engine.dart';
import 'package:vaultvoice/core/utils/ids.dart';

export 'package:vaultvoice/core/platform/vad_engine.dart' show SpeechSpan;

/// An audio chunk file on the recording timeline.
@immutable
final class PlanChunk {
  const PlanChunk({
    required this.seq,
    required this.path,
    required this.startMs,
    required this.endMs,
  });

  final int seq;

  /// Path as the engine opens it (absolute).
  final String path;
  final int startMs;
  final int endMs;
}

/// One `vv_audio_range`: `[fileStartMs, fileEndMs)` of [path], whose file
/// time 0 sits at [recordingOffsetMs] on the recording timeline.
@immutable
final class WindowRange {
  const WindowRange({
    required this.path,
    required this.fileStartMs,
    required this.fileEndMs,
    required this.recordingOffsetMs,
  });

  final String path;
  final int fileStartMs;
  final int fileEndMs;

  /// The chunk's start on the recording timeline: recording ms =
  /// `recordingOffsetMs + file ms`.
  final int recordingOffsetMs;

  int get durationMs => fileEndMs - fileStartMs;
  int get recordingStartMs => recordingOffsetMs + fileStartMs;
  int get recordingEndMs => recordingOffsetMs + fileEndMs;

  @override
  bool operator ==(Object other) =>
      other is WindowRange &&
      other.path == path &&
      other.fileStartMs == fileStartMs &&
      other.fileEndMs == fileEndMs &&
      other.recordingOffsetMs == recordingOffsetMs;

  @override
  int get hashCode =>
      Object.hash(path, fileStartMs, fileEndMs, recordingOffsetMs);

  @override
  String toString() =>
      'WindowRange(${path.split('/').last} $fileStartMs–$fileEndMs '
      '@$recordingOffsetMs)';
}

/// A transcription window: 30–120 s of speech cut only inside silences,
/// with silences longer than [WindowPlanConfig.skipSilenceMs] removed.
@immutable
final class SpeechWindow {
  const SpeechWindow({required this.index, required this.ranges});

  final int index;
  final List<WindowRange> ranges;

  /// Audio handed to whisper (speech + short kept pauses).
  int get audioMs => ranges.fold(0, (a, r) => a + r.durationMs);
  int get startMs => ranges.first.recordingStartMs;
  int get endMs => ranges.last.recordingEndMs;

  /// Stable identity of the audio this window covers (checkpoint key and
  /// near-real-time cache key). Paths are compared by file name only so a
  /// moved storage root (iOS container change) does not invalidate it.
  String get key => ranges
      .map(
        (r) =>
            '${r.path.split('/').last}:${r.fileStartMs}-${r.fileEndMs}'
            '@${r.recordingOffsetMs}',
      )
      .join('|');

  @override
  bool operator ==(Object other) =>
      other is SpeechWindow &&
      other.index == index &&
      listEquals(other.ranges, ranges);

  @override
  int get hashCode => Object.hash(index, Object.hashAll(ranges));
}

/// Windowing parameters (vv-whisper-stt → Long-form windowing).
@immutable
final class WindowPlanConfig {
  const WindowPlanConfig({
    this.minWindowMs = 30000,
    this.maxWindowMs = 120000,
    this.skipSilenceMs = 2000,
    this.trailingSilenceMs = 1000,
  });

  /// A window closes at the first silence after this much audio.
  final int minWindowMs;

  /// Never more audio than this in one window.
  final int maxWindowMs;

  /// Silences longer than this are not sent to whisper.
  final int skipSilenceMs;

  /// Near-real-time: a window is final only once this much audio after its
  /// last speech has been analysed (the speech really ended).
  final int trailingSilenceMs;
}

/// The windows for a recording.
@immutable
final class WindowPlan {
  const WindowPlan(this.windows, {required this.complete});

  final List<SpeechWindow> windows;

  /// False when planned against a horizon (recording still running): only
  /// [windows] are final, more may follow.
  final bool complete;
}

/// Plans 30–120 s speech windows (STT-04).
///
/// - [speech] spans are clipped to the chunks, sorted and merged; a span
///   longer than [WindowPlanConfig.maxWindowMs] (continuous speech without
///   any VAD silence — practically never) is split hard at the maximum.
/// - Windows are filled greedily: a span that would push the window past
///   the maximum starts the next window; once a window holds at least the
///   minimum it closes after the current span. Cuts are therefore only in
///   silences between spans, never mid-word.
/// - Inside a window, pauses up to [WindowPlanConfig.skipSilenceMs] are kept
///   (natural speech rhythm); longer silences are removed.
/// - [vadRan] with empty [speech] means silence only: no windows.
/// - Without VAD data ([speech] empty, not [vadRan]) every chunk is one
///   span and spans
///   are not merged, so windows cut at chunk boundaries (the recorder's own
///   cut points) — the pre-VAD behaviour.
/// - [horizonMs] (near-real-time): only windows whose last span ended at
///   least [WindowPlanConfig.trailingSilenceMs] before the horizon are
///   returned. The result is a prefix of the plan of the complete
///   recording (same windows, same indexes), so their transcripts can be
///   reused when the job runs.
WindowPlan planWindows({
  required List<PlanChunk> chunks,
  required List<SpeechSpan> speech,
  WindowPlanConfig config = const WindowPlanConfig(),
  int? horizonMs,
  bool vadRan = false,
}) {
  final sortedChunks = [...chunks]
    ..sort((a, b) => a.startMs.compareTo(b.startMs));
  if (sortedChunks.isEmpty) {
    return WindowPlan(const [], complete: horizonMs == null);
  }
  // VAD that ran and found nothing is silence, not missing VAD data.
  final fallback = speech.isEmpty && !vadRan;
  final spans = fallback
      ? [
          for (final c in sortedChunks)
            if (c.endMs > c.startMs) SpeechSpan(c.startMs, c.endMs),
        ]
      : _normalize(speech, sortedChunks);
  final pieces = _splitLong(spans, config.maxWindowMs);

  final windows = <SpeechWindow>[];
  var current = <SpeechSpan>[];
  var currentMs = 0;

  // Audio of [span] when appended to [window] (incl. a kept pause).
  int cost(List<SpeechSpan> window, SpeechSpan span) {
    if (window.isEmpty) return span.durationMs;
    final gap = span.startMs - window.last.endMs;
    return span.durationMs + (gap <= config.skipSilenceMs ? gap : 0);
  }

  void close() {
    windows.add(
      SpeechWindow(
        index: windows.length,
        ranges: _toRanges(current, sortedChunks, config.skipSilenceMs),
      ),
    );
    current = [];
    currentMs = 0;
  }

  for (final span in pieces) {
    if (horizonMs != null &&
        span.endMs + config.trailingSilenceMs > horizonMs) {
      // Speech may still be going on: nothing from here on is final.
      break;
    }
    var c = cost(current, span);
    if (current.isNotEmpty && currentMs + c > config.maxWindowMs) {
      close();
      c = span.durationMs;
    }
    current.add(span);
    currentMs += c;
    if (currentMs >= config.minWindowMs) close();
  }
  if (current.isNotEmpty && horizonMs == null) close();
  return WindowPlan(windows, complete: horizonMs == null);
}

List<SpeechSpan> _normalize(List<SpeechSpan> speech, List<PlanChunk> chunks) {
  final lo = chunks.first.startMs;
  final hi = chunks.map((c) => c.endMs).reduce((a, b) => a > b ? a : b);
  final sorted = [
    for (final s in speech)
      if (s.endMs > lo && s.startMs < hi && s.endMs > s.startMs)
        SpeechSpan(
          s.startMs < lo ? lo : s.startMs,
          s.endMs > hi ? hi : s.endMs,
        ),
  ]..sort((a, b) => a.startMs.compareTo(b.startMs));
  final out = <SpeechSpan>[];
  for (final s in sorted) {
    if (out.isNotEmpty && s.startMs <= out.last.endMs) {
      final last = out.removeLast();
      out.add(
        SpeechSpan(last.startMs, s.endMs > last.endMs ? s.endMs : last.endMs),
      );
    } else {
      out.add(s);
    }
  }
  return out;
}

List<SpeechSpan> _splitLong(List<SpeechSpan> spans, int maxMs) => [
  for (final s in spans)
    for (var t = s.startMs; t < s.endMs; t += maxMs)
      SpeechSpan(t, t + maxMs < s.endMs ? t + maxMs : s.endMs),
];

/// Continuous intervals of a window (short pauses joined, long silences
/// dropped) intersected with the chunk files.
List<WindowRange> _toRanges(
  List<SpeechSpan> spans,
  List<PlanChunk> chunks,
  int skipSilenceMs,
) {
  final intervals = <SpeechSpan>[];
  for (final s in spans) {
    if (intervals.isNotEmpty &&
        s.startMs - intervals.last.endMs <= skipSilenceMs) {
      intervals.add(SpeechSpan(intervals.removeLast().startMs, s.endMs));
    } else {
      intervals.add(s);
    }
  }
  return [
    for (final iv in intervals)
      for (final c in chunks)
        if (c.endMs > iv.startMs && c.startMs < iv.endMs)
          WindowRange(
            path: c.path,
            fileStartMs:
                (iv.startMs > c.startMs ? iv.startMs : c.startMs) - c.startMs,
            fileEndMs: (iv.endMs < c.endMs ? iv.endMs : c.endMs) - c.startMs,
            recordingOffsetMs: c.startMs,
          ),
  ];
}

/// Decode-parameter identity shared by the transcribe step and the
/// near-real-time transcriber (window cache key).
String sttParamsKey(String modelId, String language) =>
    fnv1a32('$modelId|$language');
