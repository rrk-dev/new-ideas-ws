import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/recording/data/audio_import_service.dart';
import 'package:vaultvoice/features/recording/data/pigeon/audio_import_api.g.dart';
import 'package:vaultvoice/features/recording/data/pigeon_audio_decoder.dart';
import 'package:vaultvoice/features/recording/data/wav_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_import.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_pcm_mic_source.dart';
import '../../helpers/deterministic.dart';

/// Writes [seconds] of a 440 Hz tone at [rate]/[channels] as raw PCM16.
class FakeDecoder implements AudioDecoder {
  FakeDecoder({
    this.rate = 16000,
    this.channels = 1,
    this.seconds = 3,
    this.refuse,
    this.creationDate,
  });

  final int rate;
  final int channels;
  final double seconds;
  final DecodeError? refuse;
  final DateTime? creationDate;
  final calls = <String>[];

  @override
  Future<DecodeResult> decodeToPcm(String srcPath, String dstPath) async {
    calls.add(srcPath);
    expect(File(srcPath).existsSync(), isTrue, reason: 'decodes the copy');
    if (refuse case final r?) return DecodeRefused(r);
    final frames = (rate * seconds).round();
    final b = ByteData(frames * channels * 2);
    for (var i = 0; i < frames; i++) {
      final v = (8000 * math.sin(2 * math.pi * 440 * i / rate)).round();
      for (var c = 0; c < channels; c++) {
        b.setInt16((i * channels + c) * 2, v, Endian.little);
      }
    }
    File(dstPath).writeAsBytesSync(b.buffer.asUint8List());
    return Decoded(
      DecodedPcm(
        sampleRate: rate,
        channels: channels,
        frames: frames,
        creationDate: creationDate,
      ),
    );
  }
}

class _Rig {
  _Rig({
    required this.decoder,
    this.platform = ImportPlatform.android,
    Duration chunk = const Duration(seconds: 5),
  }) : db = memoryDb(),
       dir = Directory.systemTemp.createTempSync('vv_import_') {
    paths = StoragePaths(p.join(dir.path, 'vv'));
    service = AudioImportService(
      decoder: decoder,
      recordings: db.recordingsRepository,
      paths: paths,
      codec: const WavChunkCodec(),
      clock: testClock(),
      ids: testIds(prefix: 'imp'),
      platform: platform,
      disk: FakeDiskSpaceProbe(),
      chunkDuration: chunk,
      enqueue: (id) async => enqueued.add(id),
    );
    addTearDown(() => dir.deleteSync(recursive: true));
  }

  final FakeDecoder decoder;
  final ImportPlatform platform;
  final VaultVoiceDatabase db;
  final Directory dir;
  late final StoragePaths paths;
  late final AudioImportService service;
  final enqueued = <String>[];

  File source(String name) =>
      File(p.join(dir.path, name))..writeAsBytesSync(List.filled(1000, 7));

  bool get workEmpty {
    final w = Directory(p.join(paths.root, 'work'));
    return !w.existsSync() || w.listSync().isEmpty;
  }
}

final attested = DateTime.utc(2026, 10, 14, 12);

void main() {
  group('format table', () {
    test('[AUD-06/AC1] per-platform table: iOS m4a/AAC, mp3, wav, flac, caf; '
        'Android adds ogg/opus; Ogg/Opus refused on iOS', () {
      bool ios(String e) => ImportFormats.byExtension(e)!.ios;
      bool android(String e) => ImportFormats.byExtension(e)!.android;
      for (final e in ['m4a', 'aac', 'mp3', 'wav', 'flac', 'caf']) {
        expect(ios(e), isTrue, reason: e);
      }
      for (final e in ['m4a', 'aac', 'mp3', 'wav', 'flac', 'ogg', 'opus']) {
        expect(android(e), isTrue, reason: e);
      }
      expect(ios('ogg'), isFalse);
      expect(ios('opus'), isFalse);
      expect(ImportFormats.byExtension('.M4A')!.id, 'M4A/AAC');
      expect(ImportFormats.byExtension('xyz'), isNull);
      expect(
        ImportFormats.extensionsFor(ImportPlatform.ios),
        isNot(contains('opus')),
      );
    });

    test(
      '[AUD-06/AC1] docs/audio-import.md lists exactly ImportFormats.all',
      () {
        final doc = File('../docs/audio-import.md').readAsStringSync();
        final rows = RegExp(
          r'^\| ([^|]+) \| ([^|]+) \| (✅|❌) \| (✅|❌) \|$',
          multiLine: true,
        ).allMatches(doc).toList();
        expect(rows, hasLength(ImportFormats.all.length));
        for (final (i, f) in ImportFormats.all.indexed) {
          final m = rows[i];
          expect(m.group(1)!.trim(), f.id);
          expect(m.group(2)!.trim(), f.extensions.join(', '));
          expect(m.group(3) == '✅', f.ios, reason: '${f.id} iOS');
          expect(m.group(4) == '✅', f.android, reason: '${f.id} Android');
        }
      },
    );
  });

  group('import service', () {
    test('[AUD-06/AC1] a 44.1 kHz stereo file becomes 16 kHz mono chunks in '
        'the AUD-01 layout, attested, dated and queued', () async {
      final created = DateTime.utc(2025, 3, 1, 8, 15);
      final rig = _Rig(
        decoder: FakeDecoder(
          rate: 44100,
          channels: 2,
          seconds: 12,
          creationDate: created,
        ),
      );
      final src = rig.source('memo.m4a');
      final out = await rig.service.importFile(src.path, attestedAt: attested);
      final done = out as ImportDone;
      expect(done.duration.inMilliseconds, closeTo(12000, 5));
      final row = expectOk(
        await rig.db.recordingsRepository.get(done.recordingId),
      );
      expect(row.source, RecordingSource.imported);
      expect(row.status, RecordingStatus.recorded);
      expect(row.importAttestedAt, attested);
      expect(row.createdAt, created);
      expect(row.durationMs, closeTo(12000, 5));
      final chunks = expectOk(
        await rig.db.recordingsRepository.chunksOf(done.recordingId),
      );
      expect(chunks.length, 3, reason: '12 s in 5 s chunks');
      var samples = 0;
      for (final c in chunks) {
        final bytes = File(rig.paths.resolve(c.path)).readAsBytesSync();
        final h = WavHeader.parse(Uint8List.sublistView(bytes, 0, 44))!;
        expect(h.isContractFormat, isTrue);
        samples += h.dataBytes ~/ 2;
        expect(c.sampleRate, 16000);
      }
      expect(samples, closeTo(12 * 16000, 80));
      expect(rig.enqueued, [done.recordingId]);
      expect(rig.workEmpty, isTrue, reason: 'temporary files deleted');
      expect(src.existsSync(), isTrue, reason: 'picker source kept');
    });

    test('16 kHz mono decodes are written without conversion; share copies '
        'are deleted; date falls back to the shared-file date', () async {
      final rig = _Rig(decoder: FakeDecoder(seconds: 2));
      final src = rig.source('abc');
      final shared = DateTime.utc(2024, 6, 2);
      final out = await rig.service.importFile(
        src.path,
        attestedAt: attested,
        extension: 'wav',
        sourceDate: shared,
        deleteSource: true,
      );
      final done = out as ImportDone;
      final row = expectOk(
        await rig.db.recordingsRepository.get(done.recordingId),
      );
      expect(row.createdAt, shared);
      expect(src.existsSync(), isFalse);
      final chunks = expectOk(
        await rig.db.recordingsRepository.chunksOf(done.recordingId),
      );
      final bytes = File(rig.paths.resolve(chunks.single.path))
          .readAsBytesSync();
      final pcm = Pcm.samples(Uint8List.sublistView(bytes, 44));
      expect(pcm.length, 32000);
      // Middle of the file is the decoder's signal unchanged.
      final mid = pcm[16000];
      expect(mid, (8000 * math.sin(2 * math.pi * 440 * 16000 / 16000)).round());
    });

    test('[AUD-06/AC1] Ogg/Opus on iOS is refused with the format, before any '
        'copy or decode', () async {
      final rig = _Rig(decoder: FakeDecoder(), platform: ImportPlatform.ios);
      final out = await rig.service.importFile(
        rig.source('voice.opus').path,
        attestedAt: attested,
      );
      expect((out as ImportUnsupported).format!.id, 'Ogg/Opus');
      expect(rig.decoder.calls, isEmpty);
      expect(rig.enqueued, isEmpty);
      expect(
        expectOk(
          await rig.db.recordingsRepository.findByStatus(
            RecordingStatus.recorded,
          ),
        ),
        isEmpty,
      );
    });

    test('[AUD-06/AC1] decoder refusals map to clear outcomes and leave no '
        'row or temporary file', () async {
      for (final (err, check) in <(DecodeError, bool Function(ImportOutcome))>[
        (DecodeError.unsupported, (o) => o is ImportUnsupported),
        (DecodeError.noAudio, (o) => o is ImportNoAudio),
        (DecodeError.failed, (o) => o is ImportFailed),
      ]) {
        final rig = _Rig(decoder: FakeDecoder(refuse: err));
        final out = await rig.service.importFile(
          rig.source('x.3gp').path,
          attestedAt: attested,
        );
        expect(check(out), isTrue, reason: '$err → $out');
        expect(rig.workEmpty, isTrue);
        expect(rig.enqueued, isEmpty);
        expect(
          expectOk(
            await rig.db.recordingsRepository.findByStatus(
              RecordingStatus.inProgress,
            ),
          ),
          isEmpty,
        );
      }
    });

    test('a decode with zero samples is "no audio"', () async {
      final rig = _Rig(decoder: FakeDecoder(seconds: 0));
      final out = await rig.service.importFile(
        rig.source('empty.wav').path,
        attestedAt: attested,
      );
      expect(out, isA<ImportNoAudio>());
      expect(rig.enqueued, isEmpty);
    });

    test('low storage refuses the import', () async {
      final rig = _Rig(decoder: FakeDecoder());
      final service = AudioImportService(
        decoder: rig.decoder,
        recordings: rig.db.recordingsRepository,
        paths: rig.paths,
        codec: const WavChunkCodec(),
        clock: testClock(),
        ids: testIds(),
        platform: ImportPlatform.android,
        disk: FakeDiskSpaceProbe(10 * 1024 * 1024),
        enqueue: (_) async {},
      );
      final out = await service.importFile(
        rig.source('a.mp3').path,
        attestedAt: attested,
      );
      expect(out, isA<ImportFailed>());
      expect(rig.decoder.calls, isEmpty);
    });
  });

  group('pigeon adapters', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const prefix = 'dev.flutter.pigeon.vaultvoice.AudioImportHostApi';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = AudioImportHostApi.pigeonChannelCodec;

    void reply(String method, Object? Function(Object? args) body) {
      messenger.setMockMessageHandler('$prefix.$method', (msg) async {
        final args = codec.decodeMessage(msg);
        return codec.encodeMessage(body(args));
      });
      addTearDown(
        () => messenger.setMockMessageHandler('$prefix.$method', null),
      );
    }

    test('decoder maps results and error codes', () async {
      reply(
        'decodeToPcm',
        (_) => [
          DecodedAudio(
            sampleRate: 44100,
            channels: 2,
            frames: 10,
            creationDateMs: 1000,
          ),
        ],
      );
      final ok = await PigeonAudioDecoder().decodeToPcm('a', 'b') as Decoded;
      expect(ok.pcm.sampleRate, 44100);
      expect(ok.pcm.creationDate, DateTime.fromMillisecondsSinceEpoch(1000));

      for (final (code, want) in [
        ('unsupported', DecodeError.unsupported),
        ('no_audio', DecodeError.noAudio),
        ('failed', DecodeError.failed),
      ]) {
        reply('decodeToPcm', (_) => [code, 'm', null]);
        final r = await PigeonAudioDecoder().decodeToPcm('a', 'b');
        expect((r as DecodeRefused).error, want);
      }
    });

    test('inbox takes pending shares', () async {
      reply(
        'takePendingShares',
        (_) => [
          [
            SharedAudioFile(path: '/x/1.ogg', fileExtension: 'ogg'),
            SharedAudioFile(path: '/x/2', creationDateMs: 5),
          ],
        ],
      );
      final inbox = PigeonSharedAudioInbox();
      addTearDown(inbox.dispose);
      final files = await inbox.take();
      expect(files.map((f) => f.extension), ['ogg', null]);
      expect(files.last.sourceDate, DateTime.fromMillisecondsSinceEpoch(5));
      final changed = expectLater(inbox.changes, emits(null));
      await inbox.sharesAvailable();
      await changed;
    });

    test('inbox returns nothing when the host is missing', () async {
      final inbox = PigeonSharedAudioInbox();
      addTearDown(inbox.dispose);
      expect(await inbox.take(), isEmpty);
      expect(
        await PigeonAudioDecoder().decodeToPcm('a', 'b'),
        isA<DecodeRefused>(),
      );
    });
  });

  test('convertPcmFile resamples 48 kHz stereo to 16 kHz mono', () {
    final dir = Directory.systemTemp.createTempSync('vv_conv_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File(p.join(dir.path, 'in.pcm'))
      ..writeAsBytesSync(Uint8List(48000 * 2 * 2)); // 1 s silence
    final dst = p.join(dir.path, 'out.pcm');
    convertPcmFile(src.path, dst, rate: 48000, channels: 2);
    expect(File(dst).lengthSync(), closeTo(32000, 64));
  });
}
