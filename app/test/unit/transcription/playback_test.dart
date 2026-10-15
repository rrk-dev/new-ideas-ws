import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';
import 'package:vaultvoice/features/transcription/data/recording_audio_source.dart';
import 'package:vaultvoice/features/transcription/domain/playback_timeline.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_player.dart';

import '../../fakes/fake_transcript_player.dart';

/// A WAV chunk whose every sample holds its own recording time in ms, so a
/// byte read back from the player's stream says exactly where it is.
File _chunk(Directory dir, String name, int startMs, int durationMs) {
  final samples = durationMs * 16;
  final pcm = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    pcm.setInt16(i * 2, startMs + i ~/ 16, Endian.little);
  }
  return File('${dir.path}/$name')..writeAsBytesSync([
    ...WavHeader.build(dataBytes: samples * 2),
    ...pcm.buffer.asUint8List(),
  ]);
}

Future<List<int>> _collect(Stream<List<int>> s) async => [
  for (final b in await s.toList()) ...b,
];

void main() {
  late Directory dir;
  late PlaybackTimeline timeline;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('vv_playback_');
    addTearDown(() => dir.deleteSync(recursive: true));
    // Three chunks with a 2 s pause between the first two (paused
    // recording): stream time ≠ recording time after 3 s.
    final c0 = _chunk(dir, 'c0.wav', 0, 3000);
    final c1 = _chunk(dir, 'c1.wav', 5000, 3000);
    final c2 = _chunk(dir, 'c2.wav', 8000, 2000);
    timeline = await loadPlaybackTimeline([
      (path: c2.path, startMs: 8000), // order does not matter
      (path: c0.path, startMs: 0),
      (path: c1.path, startMs: 5000),
    ]);
  });

  Future<int> sampleAt(VirtualWav wav, Duration streamPos) async {
    final byte = 44 + streamPos.inMicroseconds * 32 ~/ 1000;
    final bytes = await _collect(wav.range(byte, byte + 2));
    return ByteData.sublistView(Uint8List.fromList(bytes))
        .getInt16(0, Endian.little);
  }

  group(
    '[STT-06/AC3] playback seek accuracy within 250 ms of segment start',
    () {
      // Segment starts across every chunk, incl. chunk edges.
      const starts = [0, 1234, 2999, 5000, 6789, 7999, 8000, 9500, 9999];

      test(
        'stream position for a segment start plays exactly that audio',
        () async {
          final wav = VirtualWav(timeline);
          for (final s in starts) {
            final pos = timeline.streamPositionFor(s);
            final heard = await sampleAt(wav, pos);
            expect(
              (heard - s).abs(),
              lessThanOrEqualTo(250),
              reason: 'start $s',
            );
            expect(heard, s, reason: 'sample-exact for start $s');
            expect(timeline.recordingMsFor(pos), s);
          }
        },
      );

      test(
        'tap → TranscriptPlayback seeks the player to the segment start',
        () async {
          final player = FakeTranscriptPlayer();
          final playback = TranscriptPlayback(player, timeline);
          for (final s in starts) {
            await playback.playFrom(s);
            final target = player.seeks.last;
            expect(
              (timeline.recordingMsFor(target) - s).abs(),
              lessThanOrEqualTo(250),
            );
            expect(player.isPlaying, isTrue);
          }
          expect(player.loads, 1, reason: 'the source is loaded once');
          // Position stream is reported on the recording timeline.
          final positions = <int>[];
          final sub = playback.recordingPositionMs.listen(positions.add);
          player.emitPosition(const Duration(milliseconds: 3500)); // c1 + 500
          await pumpEventQueue();
          expect(positions, [5500]);
          await sub.cancel();
        },
      );

      test('a start inside a pause snaps to the next audio; past the end '
          'clamps', () {
        expect(timeline.streamPositionFor(4000), const Duration(seconds: 3));
        expect(timeline.streamPositionFor(60000), timeline.streamDuration);
        expect(timeline.streamDuration, const Duration(seconds: 8));
      });
    },
  );

  group('VirtualWav', () {
    test('serves a valid header + all PCM, and arbitrary ranges', () async {
      final wav = VirtualWav(timeline);
      expect(wav.length, 44 + 8000 * 32);
      final all = await _collect(wav.range(0, wav.length));
      expect(all, hasLength(wav.length));
      final info = WavHeader.parse(Uint8List.fromList(all.sublist(0, 44)));
      expect(info, isNotNull);
      // A range spanning the header and the first samples.
      final head = await _collect(wav.range(40, 48));
      expect(head, hasLength(8));
      // A range spanning the chunk boundary (stream 3 s).
      const edge = 44 + 3000 * 32;
      final across = await _collect(wav.range(edge - 2, edge + 2));
      final d = ByteData.sublistView(Uint8List.fromList(across));
      expect(d.getInt16(0, Endian.little), 2999);
      expect(d.getInt16(2, Endian.little), 5000);
      expect(await wav.range(wav.length, wav.length + 10).toList(), isEmpty);
    });

    test('RecordingAudioSource answers range requests with lengths', () async {
      final source = RecordingAudioSource(VirtualWav(timeline));
      final r = await source.request(100, 200);
      expect(r.sourceLength, 44 + 8000 * 32);
      expect(r.contentLength, 100);
      expect(r.offset, 100);
      expect(r.contentType, 'audio/wav');
      final full = await source.request();
      expect(full.contentLength, full.sourceLength);
    });

    test('a toggle loads lazily and switches play/pause', () async {
      final player = FakeTranscriptPlayer();
      final playback = TranscriptPlayback(player, timeline);
      await playback.toggle(playing: false);
      expect(player.isPlaying, isTrue);
      await playback.toggle(playing: true);
      expect(player.isPlaying, isFalse);
      expect(player.loads, 1);
      await playback.dispose();
      expect(player.disposed, isTrue);
      unawaited(Future<void>.value());
    });
  });
}
