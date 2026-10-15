import 'package:flutter/foundation.dart';

/// 16 kHz mono PCM16 (the chunk format, vv-audio-capture).
const int kPlaybackSampleRate = 16000;
const int kPlaybackBytesPerMs = kPlaybackSampleRate * 2 ~/ 1000; // 32

/// One audio chunk as the player sees it: its place on the recording
/// timeline and how many PCM bytes it holds.
@immutable
final class PlaybackChunk {
  const PlaybackChunk({
    required this.path,
    required this.startMs,
    required this.pcmBytes,
  });

  /// Absolute path of the chunk file.
  final String path;

  /// Start on the recording timeline.
  final int startMs;

  /// PCM payload size (container overhead excluded), whole samples.
  final int pcmBytes;

  int get durationMs => pcmBytes ~/ kPlaybackBytesPerMs;
}

/// A slice of one chunk's PCM: bytes `[from, to)` of chunk `index`.
typedef ChunkSlice = ({int index, int from, int to});

/// Maps between the recording timeline (what transcript segments and
/// markers use) and one continuous PCM stream that concatenates the chunks
/// in order (what the player plays). Pauses between chunks are not in the
/// stream, so stream time ≠ recording time after a pause.
@immutable
final class PlaybackTimeline {
  PlaybackTimeline(List<PlaybackChunk> chunks)
    : chunks = List.unmodifiable(
        <PlaybackChunk>[...chunks]
          ..sort((a, b) => a.startMs.compareTo(b.startMs)),
      ) {
    var offset = 0;
    final starts = <int>[];
    for (final c in this.chunks) {
      starts.add(offset);
      offset += c.pcmBytes - c.pcmBytes % 2;
    }
    _streamStarts = starts;
    totalPcmBytes = offset;
  }

  final List<PlaybackChunk> chunks;
  late final List<int> _streamStarts;

  /// PCM bytes of the whole stream.
  late final int totalPcmBytes;

  Duration get streamDuration =>
      Duration(milliseconds: totalPcmBytes ~/ kPlaybackBytesPerMs);

  /// Stream position for recording time [recordingMs]. A time inside a
  /// pause snaps to the start of the next chunk; past the end clamps to the
  /// end. Exact to the sample (byte offsets are whole samples).
  Duration streamPositionFor(int recordingMs) {
    for (final (i, c) in chunks.indexed) {
      final end = c.startMs + c.durationMs;
      if (recordingMs < c.startMs) {
        return _bytesToDuration(_streamStarts[i]);
      }
      if (recordingMs < end) {
        final into = (recordingMs - c.startMs) * kPlaybackBytesPerMs;
        return _bytesToDuration(_streamStarts[i] + into);
      }
    }
    return _bytesToDuration(totalPcmBytes);
  }

  /// Recording time of stream position [position] (inverse of
  /// [streamPositionFor] inside chunks).
  int recordingMsFor(Duration position) {
    final byte = (position.inMicroseconds * kPlaybackBytesPerMs) ~/ 1000;
    for (var i = chunks.length - 1; i >= 0; i--) {
      if (byte >= _streamStarts[i]) {
        final into = byte - _streamStarts[i];
        final ms = into ~/ kPlaybackBytesPerMs;
        return chunks[i].startMs + ms.clamp(0, chunks[i].durationMs);
      }
    }
    return chunks.isEmpty ? 0 : chunks.first.startMs;
  }

  /// The chunk slices covering stream PCM bytes `[from, to)`.
  List<ChunkSlice> slices(int from, int to) {
    final out = <ChunkSlice>[];
    final end = to.clamp(0, totalPcmBytes);
    for (final (i, c) in chunks.indexed) {
      final cs = _streamStarts[i];
      final ce = cs + c.pcmBytes - c.pcmBytes % 2;
      if (ce <= from || cs >= end) continue;
      out.add((
        index: i,
        from: (from - cs).clamp(0, ce - cs),
        to: (end - cs).clamp(0, ce - cs),
      ));
    }
    return out;
  }

  static Duration _bytesToDuration(int bytes) =>
      Duration(microseconds: bytes * 1000 ~/ kPlaybackBytesPerMs);
}
