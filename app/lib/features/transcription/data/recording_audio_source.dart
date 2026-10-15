// StreamAudioSource is marked @experimental in just_audio 0.10.6; it is the
// only way to stream (decrypting) chunk readers without temp files
// (vv-whisper-stt). Re-verify on every just_audio upgrade.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';
import 'package:vaultvoice/features/transcription/domain/playback_timeline.dart';

/// Reads the PCM payload of one chunk file. The seam for SEC-01: the
/// default reads plain WAV chunks; an encrypted codec supplies a reader
/// that decrypts on the fly (no plaintext temp files).
abstract interface class ChunkPcmReader {
  /// PCM bytes in [path] (whole samples).
  Future<int> pcmBytes(String path);

  /// PCM bytes `[from, to)` of [path].
  Stream<List<int>> read(String path, int from, int to);
}

/// [ChunkPcmReader] for the default WAV codec (44-byte header written by
/// `WavChunkCodec`).
class WavChunkPcmReader implements ChunkPcmReader {
  const WavChunkPcmReader();

  @override
  Future<int> pcmBytes(String path) async =>
      WavHeader.recoverableDataBytes(await File(path).length());

  @override
  Stream<List<int>> read(String path, int from, int to) =>
      File(path).openRead(WavHeader.length + from, WavHeader.length + to);
}

/// Builds the [PlaybackTimeline] of a recording's chunks
/// (`(absolutePath, startMs)` in any order).
Future<PlaybackTimeline> loadPlaybackTimeline(
  List<({String path, int startMs})> chunks, {
  ChunkPcmReader reader = const WavChunkPcmReader(),
}) async => PlaybackTimeline([
  for (final c in chunks)
    PlaybackChunk(
      path: c.path,
      startMs: c.startMs,
      pcmBytes: await reader.pcmBytes(c.path),
    ),
]);

/// The bytes of one virtual WAV file = 44-byte header + every chunk's PCM in
/// timeline order. Byte offsets map 1:1 to stream time (PCM), so a seek is
/// sample-exact.
class VirtualWav {
  VirtualWav(this.timeline, {this.reader = const WavChunkPcmReader()})
    : header = WavHeader.build(dataBytes: timeline.totalPcmBytes);

  final PlaybackTimeline timeline;
  final ChunkPcmReader reader;
  final Uint8List header;

  int get length => header.length + timeline.totalPcmBytes;

  /// Bytes `[start, end)` of the virtual file (end clamped to [length]).
  Stream<List<int>> range(int start, int end) async* {
    final stop = end.clamp(0, length);
    if (start >= stop) return;
    if (start < header.length) {
      yield header.sublist(start, stop.clamp(0, header.length));
    }
    final from = (start - header.length).clamp(0, timeline.totalPcmBytes);
    final to = stop - header.length;
    if (to <= from) return;
    for (final s in timeline.slices(from, to)) {
      yield* reader.read(timeline.chunks[s.index].path, s.from, s.to);
    }
  }
}

/// just_audio source over [VirtualWav] (vv-whisper-stt: a
/// `StreamAudioSource` over the chunk reader, so encrypted chunks decrypt on
/// the fly). just_audio serves it through its loopback-only proxy
/// (127.0.0.1) — no network egress (docs/privacy-audit.md).
class RecordingAudioSource extends StreamAudioSource {
  RecordingAudioSource(this.wav) : super(tag: 'recording');

  final VirtualWav wav;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? wav.length;
    return StreamAudioResponse(
      sourceLength: wav.length,
      contentLength: (e.clamp(0, wav.length) - s).clamp(0, wav.length),
      offset: s,
      stream: wav.range(s, e),
      contentType: 'audio/wav',
    );
  }
}
