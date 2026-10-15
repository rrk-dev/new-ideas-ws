import 'dart:async';

import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/features/transcription/data/live_transcriber.dart';
import 'package:vaultvoice/features/transcription/domain/window_planner.dart';

/// Drives a [LiveTranscriber] from the database while a recording is being
/// captured: every finalized chunk / new VAD span moves the horizon and
/// decodes the windows that became final (STT-04 near-real-time mode).
///
/// It only *reads* what the recorder wrote (chunks, `speech_segments`); it
/// never starts, resumes or extends a recording (SEC-09). [allowed] is
/// checked before every update: [nearRealTimeAllowed] + "no other heavy
/// model loaded" (the caller wires both).
class LiveTranscriptionService {
  LiveTranscriptionService({
    required this.recordings,
    required this.paths,
    required this.create,
    required this.allowed,
  });

  final RecordingsRepository recordings;
  final StoragePaths paths;
  final LiveTranscriber Function(String recordingId) create;
  final bool Function() allowed;

  final _active = <String, _Live>{};

  bool isWatching(String recordingId) => _active.containsKey(recordingId);

  /// Starts following [recordingId] (idempotent).
  void watch(String recordingId) {
    if (_active.containsKey(recordingId)) return;
    final live = _Live(create(recordingId));
    _active[recordingId] = live;
    var chunks = <PlanChunk>[];
    var speech = <SpeechSpan>[];
    void kick() {
      if (chunks.isEmpty || !allowed()) return;
      final horizon = chunks
          .map((c) => c.endMs)
          .reduce((a, b) => a > b ? a : b);
      live.pending = live.transcriber.update(
        chunks: chunks,
        speech: [
          for (final s in speech)
            if (s.endMs <= horizon) s,
        ],
        horizonMs: horizon,
        cancel: live.cancel,
      );
    }

    live.subs
      ..add(
        recordings.watchChunks(recordingId).listen((rows) {
          chunks = [
            for (final c in rows)
              PlanChunk(
                seq: c.seq,
                path: paths.resolve(c.path),
                startMs: c.startMs,
                endMs: c.endMs,
              ),
          ];
          kick();
        }),
      )
      ..add(
        recordings.watchSpeechSegments(recordingId).listen((rows) {
          speech = [for (final s in rows) SpeechSpan(s.startMs, s.endMs)];
          kick();
        }),
      );
  }

  /// The recording stopped (or was discarded): stop following it. Windows
  /// already decoded stay in the cache for the pipeline job.
  Future<void> stop(String recordingId) async {
    final live = _active.remove(recordingId);
    if (live == null) return;
    live.cancel.cancel();
    for (final s in live.subs) {
      await s.cancel();
    }
    await live.pending;
  }

  /// Waits for the updates in flight (tests, shutdown).
  Future<void> idle() async {
    for (final l in _active.values) {
      await l.pending;
    }
  }

  Future<void> dispose() async {
    for (final id in [..._active.keys]) {
      await stop(id);
    }
  }
}

class _Live {
  _Live(this.transcriber);

  final LiveTranscriber transcriber;
  final cancel = CancelToken();
  final subs = <StreamSubscription<Object?>>[];
  Future<int> pending = Future.value(0);
}
