// StreamAudioSource is marked @experimental in just_audio 0.10.6; it is the
// only way to stream (decrypting) chunk readers without temp files
// (vv-whisper-stt). Re-verify on every just_audio upgrade.
// ignore_for_file: experimental_member_use
import 'package:just_audio/just_audio.dart';
import 'package:vaultvoice/features/transcription/data/recording_audio_source.dart';
import 'package:vaultvoice/features/transcription/domain/playback_timeline.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_player.dart';

/// [TranscriptPlayer] on just_audio 0.10.6 (`AudioPlayer.setAudioSource`
/// with a [StreamAudioSource]; API verified against the pinned package).
/// Playback only — never records (SEC-09).
class JustAudioTranscriptPlayer implements TranscriptPlayer {
  JustAudioTranscriptPlayer({
    AudioPlayer? player,
    this.reader = const WavChunkPcmReader(),
  }) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final ChunkPcmReader reader;

  @override
  Future<void> load(PlaybackTimeline timeline) async {
    await _player.setAudioSource(
      RecordingAudioSource(VirtualWav(timeline, reader: reader)),
    );
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<void> seek(Duration streamPosition) => _player.seek(streamPosition);

  @override
  Future<void> play() async {
    // `play()` completes when playback stops; don't await it.
    _player.play().ignore();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}
