import 'dart:async';

import 'package:vaultvoice/features/transcription/domain/playback_timeline.dart';

/// Plays a recording's audio as one continuous stream (just_audio in the
/// app, a fake in tests). Positions are *stream* time; the
/// [TranscriptPlayback] controller maps them to recording time.
abstract interface class TranscriptPlayer {
  /// Prepares [timeline] for playback (does not start it).
  Future<void> load(PlaybackTimeline timeline);

  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;

  Future<void> seek(Duration streamPosition);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
}

/// Creates a [TranscriptPlayer] (one per open transcript screen).
typedef TranscriptPlayerFactory = TranscriptPlayer Function();

/// Transcript-aware playback: seek to a segment's recording time, observe
/// the current recording time (current-segment highlight).
class TranscriptPlayback {
  TranscriptPlayback(this.player, this.timeline);

  final TranscriptPlayer player;
  final PlaybackTimeline timeline;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await player.load(timeline);
    _loaded = true;
  }

  /// Current position on the recording timeline.
  Stream<int> get recordingPositionMs =>
      player.positionStream.map(timeline.recordingMsFor);

  Stream<bool> get playing => player.playingStream;

  /// Seeks to recording time [recordingMs] and plays (tap on a segment).
  Future<void> playFrom(int recordingMs) async {
    await _ensureLoaded();
    await player.seek(timeline.streamPositionFor(recordingMs));
    await player.play();
  }

  Future<void> toggle({required bool playing}) async {
    await _ensureLoaded();
    await (playing ? player.pause() : player.play());
  }

  Future<void> dispose() => player.dispose();
}
