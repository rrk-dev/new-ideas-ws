import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/recording/data/recording_recovery.dart';
import 'package:vaultvoice/features/recording/data/wav_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_pcm_mic_source.dart';
import '../../helpers/deterministic.dart';
import 'capture_rig.dart';

RecordingRecovery _recovery(CaptureRig rig) => RecordingRecovery(
  recordings: rig.db.recordingsRepository,
  paths: rig.paths,
  codec: const WavChunkCodec(),
);

/// Simulates the process dying: timers and microphone stop, but nothing is
/// finalized (no endSegment, no header patch, row stays `recording`).
Future<void> _kill(CaptureRig rig) async {
  await rig.settle();
  await rig.backend.dispose();
}

void main() {
  test('[AUD-07/AC1] force-killing at random points during 10 recordings '
      'leaves 10 recoverable, playable recordings losing ≤ 1 s', () async {
    final random = seededRandom();
    for (var run = 0; run < 10; run++) {
      final rig = CaptureRig(chunkDuration: const Duration(seconds: 2));
      expectOk(await rig.controller.start(StartSource.inAppButton));
      var spoken = Duration.zero;
      final segments = 1 + random.nextInt(3);
      for (var s = 0; s < segments; s++) {
        final d = Duration(milliseconds: 300 + random.nextInt(4000));
        rig.speak(d, block: Duration(milliseconds: 20 + random.nextInt(200)));
        spoken += d;
        if (s < segments - 1) {
          await rig.controller.pause();
          await rig.controller.resume(ResumeSource.inAppButton);
        }
      }
      await _kill(rig);
      final id = rig.backend.recordingId!;
      // A torn write: half a sample at the end of the newest chunk.
      final last = (await rig.chunks(id)).last;
      rig.file(last).writeAsBytesSync([7], mode: FileMode.append);
      // Before repair the header does not describe the file.
      final before = rig.file(last).readAsBytesSync();
      expect(
        WavHeader.parse(Uint8List.sublistView(before, 0, 44))!.dataBytes,
        isNot(before.length - 44),
        reason: 'run $run: header is stale after a kill',
      );
      expect((await rig.row(id)).status, isNot(RecordingStatus.recorded));

      // "Relaunch".
      final recovered = expectOk(await _recovery(rig).recoverOrphans());
      expect(recovered.single.recordingId, id, reason: 'run $run');
      final row = await rig.row(id);
      expect(row.status, RecordingStatus.recorded);
      expect(row.recovered, isTrue);
      // Every chunk is a valid 16 kHz mono WAV again (checked by the rig).
      final samples = await rig.recordedSamples(id);
      final kept = AudioFormat.durationOf(samples.length);
      expect(spoken - kept, lessThanOrEqualTo(const Duration(seconds: 1)));
      expect(spoken - kept, greaterThanOrEqualTo(Duration.zero));
      expect(row.durationMs, kept.inMilliseconds);
      expect(recovered.single.duration, kept);
      // Rows are contiguous and match the files.
      var end = 0;
      for (final c in await rig.chunks(id)) {
        expect(c.startMs, end);
        expect(c.bytes, rig.file(c).lengthSync());
        end = c.endMs;
      }
    }
  });

  group('RecordingRecovery', () {
    late CaptureRig rig;
    setUp(() => rig = CaptureRig());

    Future<void> seed(String id, RecordingStatus status) =>
        seedRecording(rig.db, id, status: status);

    File chunkFile(String id, int seq) => File(
      '${rig.paths.audioDir(id)}/chunk_${seq.toString().padLeft(4, '0')}.wav',
    )..parent.createSync(recursive: true);

    void writeChunk(String id, int seq, int samples, {int headerData = 0}) {
      chunkFile(id, seq).writeAsBytesSync([
        ...WavHeader.build(dataBytes: headerData),
        ...Pcm.counter(samples),
      ]);
    }

    test('rebuilds rows for chunk files the DB never heard of and drops '
        'rows whose file is missing', () async {
      await seed('a', RecordingStatus.inProgress);
      writeChunk('a', 0, 16000);
      writeChunk('a', 1, 8000);
      expectOk(
        await rig.db.recordingsRepository.upsertChunk(
          AudioChunksCompanion.insert(
            recordingId: 'a',
            seq: 2,
            path: 'audio/a/chunk_0002.wav',
            sampleRate: 16000,
            startMs: 1500,
            endMs: 1500,
            bytes: 44,
          ),
        ),
      );
      final r = expectOk(await _recovery(rig).recoverOrphans()).single;
      expect(r.duration, const Duration(milliseconds: 1500));
      expect(r.chunks, 2);
      expect(
        [for (final c in await rig.chunks('a')) (c.seq, c.startMs, c.endMs)],
        [(0, 0, 1000), (1, 1000, 1500)],
      );
      expect(await rig.recordedSamples('a'), hasLength(24000));
    });

    test('a recording killed before any audio is removed', () async {
      await seed('empty', RecordingStatus.recording);
      chunkFile('empty', 0).writeAsBytesSync([1, 2, 3]); // torn header
      expect(expectOk(await _recovery(rig).recoverOrphans()), isEmpty);
      expect((await rig.db.recordingsRepository.get('empty')).isOk, isFalse);
      expect(Directory(rig.paths.audioDir('empty')).existsSync(), isFalse);
    });

    test('leaves finished recordings and the open recording alone', () async {
      await seed('done', RecordingStatus.recorded);
      writeChunk('done', 0, 100);
      await seed('open', RecordingStatus.recording);
      writeChunk('open', 0, 100);
      final r = expectOk(await _recovery(rig).recoverOrphans(skip: {'open'}));
      expect(r, isEmpty);
      expect((await rig.row('open')).status, RecordingStatus.recording);
      // Untouched: the finished recording's (deliberately wrong) header.
      final bytes = chunkFile('done', 0).readAsBytesSync();
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 0);
    });

    test('recovers the in-progress recordings of a crash at a random '
        'byte offset (odd lengths are rounded down)', () async {
      final random = Random(7);
      await seed('odd', RecordingStatus.recording);
      final f = chunkFile('odd', 0);
      final pcm = Pcm.counter(5000);
      final cut = 44 + random.nextInt(pcm.length);
      f.writeAsBytesSync(
        [...WavHeader.build(dataBytes: 0), ...pcm].sublist(0, cut),
      );
      final r = expectOk(await _recovery(rig).recoverOrphans()).single;
      final data = (cut - 44) - (cut - 44) % 2;
      expect(r.duration, AudioFormat.durationOf(data ~/ 2));
      expect(f.lengthSync(), 44 + data);
      final info = WavHeader.parse(f.readAsBytesSync().sublist(0, 44))!;
      expect(info.isContractFormat, isTrue);
      expect(info.dataBytes, data);
    });
  });
}
