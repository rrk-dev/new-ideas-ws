import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/capture_backend.dart';
import 'package:vaultvoice/features/recording/domain/pcm_fade.dart';

/// Writes one recording as rolling chunk files
/// `audio/<recording_id>/chunk_<seq:04d>.<ext>` with an `audio_chunks` row
/// per chunk (`vv-audio-capture` → Format contract).
///
/// * Time base: ms from recording start **excluding paused spans** — derived
///   from the sample count, so it is exact and chunk start/end ms line up.
/// * Chunks roll over at exactly [chunkSamples]: no sample is dropped or
///   duplicated at a boundary (a single contiguous sample stream).
/// * A *segment* is one open-microphone span (start→pause, resume→stop).
///   Each starts in a new chunk with a [fadeSamples] fade-in and ends with a
///   fade-out, so pause/resume never clicks. Gaps are `markers` rows.
///
/// Not thread-safe: the caller serializes calls.
class RecordingChunkWriter {
  RecordingChunkWriter({
    required this.recordingId,
    required this._paths,
    required this._codec,
    required RecordingsRepository recordings,
    Duration chunkDuration = AudioFormat.defaultChunkDuration,
    this.fadeSamples = PcmFade.defaultSamples,
  }) : _repo = recordings,
       chunkSamples = AudioFormat.samplesFor(chunkDuration);

  final String recordingId;
  final StoragePaths _paths;
  final AudioChunkCodec _codec;
  final RecordingsRepository _repo;

  /// Samples per full chunk (5 min ⇒ 4 800 000).
  final int chunkSamples;
  final int fadeSamples;

  AudioChunkWriter? _chunk;
  int _seq = -1; // seq of the open (or last) chunk
  int _chunkStartSample = 0;
  int _totalSamples = 0;
  int _segmentSamples = 0; // samples since the segment began
  bool _inSegment = false;
  Failure? _failure;

  /// Recorded samples so far (gaps excluded).
  int get totalSamples => _totalSamples;

  /// Recorded duration so far (gaps excluded).
  Duration get recorded => AudioFormat.durationOf(_totalSamples);

  /// Number of chunk files created so far.
  int get chunkCount => _seq + 1;

  /// Relative directory holding the chunks.
  String get relativeDir =>
      _paths.relativize(_paths.audioDir(recordingId)).replaceAll(r'\', '/');

  /// Relative path of chunk [seq].
  String chunkPath(int seq) => p.posix.join(
    relativeDir,
    'chunk_${seq.toString().padLeft(4, '0')}.${_codec.id.extension}',
  );

  /// Starts a segment: the next samples go to a new chunk and fade in.
  void beginSegment() {
    _inSegment = true;
    _segmentSamples = 0;
  }

  /// Appends 16 kHz mono PCM16 [pcm] (whole samples), rolling over chunks.
  Future<Result<void>> append(Uint8List pcm) => _guard(() async {
    if (!_inSegment) throw StateError('append outside a segment');
    var data = pcm.length.isOdd ? pcm.sublist(0, pcm.length - 1) : pcm;
    if (_segmentSamples < fadeSamples) {
      data = PcmFade.fadeInFrom(
        data,
        offset: _segmentSamples,
        samples: fadeSamples,
      );
    }
    var offset = 0;
    while (offset < data.length) {
      final chunk = _chunk ?? await _openChunk();
      final room = (chunkSamples - _samplesIn(chunk)) * 2;
      final n = math.min(room, data.length - offset);
      await chunk.append(Uint8List.sublistView(data, offset, offset + n));
      offset += n;
      final samples = n ~/ 2;
      _totalSamples += samples;
      _segmentSamples += samples;
      if (_samplesIn(chunk) >= chunkSamples) await _closeChunk();
    }
  });

  /// Makes everything appended durable (≤ 1 s cadence, AUD-07) and updates
  /// the open chunk's row.
  Future<Result<void>> flush() => _guard(() async {
    final chunk = _chunk;
    if (chunk == null) return;
    await chunk.flush();
    await _upsertRow(chunk, bytes: chunk.fileBytes);
  });

  /// Ends the current segment: drops the last [discardSamples] samples
  /// (audio captured after a call event — never kept), fades out the new
  /// tail, finalizes the chunk and, when [gap] is given, writes a gap marker
  /// at the resulting position.
  Future<Result<void>> endSegment({
    int discardSamples = 0,
    GapKind? gap,
  }) => _guard(() async {
    if (_inSegment) {
      // Never discard into the previous segment (it ended before the event).
      var remaining = math.min(math.max(discardSamples, 0), _segmentSamples);
      while (remaining > 0) {
        // The discard may reach back past a chunk rollover: reopen it.
        final chunk = _chunk ?? await _reopenChunk();
        final have = _samplesIn(chunk);
        final drop = math.min(remaining, have);
        await chunk.truncate((have - drop) * 2);
        _totalSamples -= drop;
        _segmentSamples -= drop;
        remaining -= drop;
        if (remaining > 0) await _closeChunk(); // empty ⇒ deleted
      }
      // A pause exactly at a rollover leaves no open chunk: reopen the
      // segment's last one so its tail is still faded out.
      final chunk =
          _chunk ??
          (_segmentSamples > 0 && _seq >= 0 ? await _reopenChunk() : null);
      if (chunk != null) {
        final keep = _samplesIn(chunk);
        final tail = math.min(fadeSamples, keep);
        if (tail > 0) {
          final from = (keep - tail) * 2;
          final faded = PcmFade.fadeOut(await chunk.readTail(from));
          await chunk.truncate(from);
          await chunk.append(faded);
        }
        await _closeChunk();
      }
      _inSegment = false;
    }
    if (gap != null) {
      final marker = await _repo.addMarker(
        MarkersCompanion.insert(
          recordingId: recordingId,
          atMs: AudioFormat.msOf(_totalSamples),
          kind: gap == GapKind.callInterruption
              ? MarkerKind.callInterruption
              : MarkerKind.gap,
          label: Value(gap.wireName),
        ),
      );
      if (marker case Err(:final failure)) throw _FailureException(failure);
    }
  });

  /// First IO/DB failure seen, if any.
  Failure? get failure => _failure;

  int _samplesIn(AudioChunkWriter chunk) => chunk.dataBytes ~/ 2;

  Future<AudioChunkWriter> _openChunk() async {
    _seq++;
    _chunkStartSample = _totalSamples;
    final chunk = await _codec.create(_paths.resolve(chunkPath(_seq)));
    _chunk = chunk;
    await _upsertRow(chunk, bytes: chunk.fileBytes);
    return chunk;
  }

  Future<AudioChunkWriter> _reopenChunk() async {
    if (_seq < 0) throw StateError('no chunk to reopen');
    final chunk = await _codec.reopen(_paths.resolve(chunkPath(_seq)));
    _chunk = chunk;
    _chunkStartSample = _totalSamples - _samplesIn(chunk);
    return chunk;
  }

  Future<void> _closeChunk() async {
    final chunk = _chunk;
    if (chunk == null) return;
    _chunk = null;
    final length = await chunk.close();
    if (chunk.dataBytes == 0) {
      // Everything was discarded: no empty chunk on disk or in the DB.
      final file = File(_paths.resolve(chunkPath(_seq)));
      if (file.existsSync()) await file.delete();
      final deleted = await _repo.deleteChunk(recordingId, _seq);
      if (deleted case Err(:final failure)) throw _FailureException(failure);
      _seq--;
      return;
    }
    await _upsertRow(chunk, bytes: length);
  }

  Future<void> _upsertRow(AudioChunkWriter chunk, {required int bytes}) async {
    final r = await _repo.upsertChunk(
      AudioChunksCompanion.insert(
        recordingId: recordingId,
        seq: _seq,
        path: chunkPath(_seq),
        sampleRate: AudioFormat.sampleRate,
        startMs: AudioFormat.msOf(_chunkStartSample),
        endMs: AudioFormat.msOf(_chunkStartSample + _samplesIn(chunk)),
        bytes: bytes,
      ),
    );
    if (r case Err(:final failure)) throw _FailureException(failure);
  }

  Future<Result<void>> _guard(Future<void> Function() body) async {
    if (_failure case final f?) return Err(f);
    try {
      await body();
      return const Ok<void>(null);
    } on _FailureException catch (e) {
      return Err(_failure = e.failure);
    } on FileSystemException {
      return Err(_failure = const StorageFailure('chunk io failed'));
    } on Object catch (e) {
      return Err(_failure = UnexpectedFailure(e.runtimeType.toString()));
    }
  }
}

final class _FailureException implements Exception {
  const _FailureException(this.failure);

  final Failure failure;
}
