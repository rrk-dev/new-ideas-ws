import 'dart:async';

import 'package:vaultvoice/features/transcription/domain/playback_timeline.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_player.dart';

/// Records seeks/plays; positions are pushed by the test.
class FakeTranscriptPlayer implements TranscriptPlayer {
  final seeks = <Duration>[];
  int loads = 0;
  bool isPlaying = false;
  bool disposed = false;
  PlaybackTimeline? timeline;

  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  void emitPosition(Duration d) => _position.add(d);

  @override
  Future<void> load(PlaybackTimeline timeline) async {
    loads++;
    this.timeline = timeline;
  }

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> seek(Duration streamPosition) async => seeks.add(streamPosition);

  @override
  Future<void> play() async {
    isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _playing.close();
  }
}
