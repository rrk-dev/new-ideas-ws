import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/recording/data/record_capture_backend.dart';
import 'package:vaultvoice/features/recording/data/wav_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/audio_session_monitor.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';
import 'package:vaultvoice/features/recording/domain/storage_policy.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_call_guard.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_pcm_mic_source.dart';
import '../../helpers/deterministic.dart';

/// Real [RecordCaptureBackend] + [RecordingController] wired to a fake
/// microphone, fake call guard, in-memory DB and a temp storage root.
class CaptureRig {
  CaptureRig({
    Duration chunkDuration = const Duration(seconds: 5),
    StoragePolicy storage = const StoragePolicy(),
    AudioChunkCodec codec = const WavChunkCodec(),
    Duration flushInterval = const Duration(seconds: 1),
    AudioSessionMonitor audioSession = const NoAudioSessionMonitor(),
    this.foreground = true,
    Set<StartSource>? allowedStarts,
    bool pauseOnInputRemoved = false,
    bool rejectNonMicrophoneInputs = false,
  }) : db = memoryDb(),
       dir = Directory.systemTemp.createTempSync('vv_capture_') {
    paths = StoragePaths(dir.path);
    backend = RecordCaptureBackend(
      mic: mic,
      recordings: db.recordingsRepository,
      paths: () async => paths,
      disk: disk,
      clock: clock,
      ids: testIds(prefix: 'rec'),
      codec: codec,
      storage: storage,
      chunkDuration: chunkDuration,
      flushInterval: flushInterval,
      audioSession: audioSession,
      pauseOnInputRemoved: pauseOnInputRemoved,
      rejectNonMicrophoneInputs: rejectNonMicrophoneInputs,
    );
    controller = RecordingController(
      capture: backend,
      callGuard: guard,
      clock: clock,
      isAppInForeground: () => foreground,
      allowedStarts: allowedStarts,
    );
    addTearDown(() async {
      await controller.dispose();
      await backend.dispose();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  }

  final VaultVoiceDatabase db;
  final Directory dir;
  late final StoragePaths paths;
  final mic = FakePcmMicSource();
  final disk = FakeDiskSpaceProbe();
  final guard = FakeCallGuard();
  final FakeClock clock = testClock();
  late final RecordCaptureBackend backend;
  late final RecordingController controller;
  bool foreground;

  /// Absolute index of the next sample [speak] produces.
  int nextSample = 0;

  /// Captures [d] of audio in [block]-sized deliveries, advancing the clock
  /// by each block's duration before it "arrives".
  void speak(
    Duration d, {
    Duration block = const Duration(milliseconds: 100),
    int Function(int i)? signal,
    bool silent = false,
  }) {
    var left = AudioFormat.samplesFor(d);
    final per = AudioFormat.samplesFor(block);
    final silence = Uint8List(per * 2);
    while (left > 0) {
      final n = left < per ? left : per;
      clock.advance(AudioFormat.durationOf(n));
      mic.emit(
        silent
            ? Uint8List.sublistView(silence, 0, n * 2)
            : signal == null
            ? Pcm.counter(n, start: nextSample)
            : Pcm.of(n, signal, start: nextSample),
        clock.now(),
      );
      nextSample += n;
      left -= n;
    }
  }

  /// Like [speak] but waits for the writes after every [block], as when
  /// audio arrives in real time (keeps the write queue shallow).
  Future<void> speakPaced(
    Duration d, {
    Duration block = const Duration(seconds: 1),
    bool silent = false,
  }) async {
    var left = d;
    while (left > Duration.zero) {
      final step = left < block ? left : block;
      speak(step, block: block, silent: silent);
      left -= step;
      await backend.idle;
    }
  }

  /// Waits for queued chunk writes.
  Future<void> settle() async {
    await pumpEventQueue();
    await backend.idle;
  }

  Future<List<AudioChunkRow>> chunks(String recordingId) =>
      db.recordingsRepository.watchChunks(recordingId).first;

  Future<RecordingRow> row(String id) async =>
      (await db.recordingsRepository.get(id)).valueOrNull!;

  Future<List<MarkerRow>> markers(String id) =>
      db.recordingsRepository.watchMarkers(id).first;

  /// The file of [chunk].
  File file(AudioChunkRow chunk) => File(paths.resolve(chunk.path));

  /// Every recorded sample, chunk files concatenated in order; each file
  /// must be a valid contract-format WAV.
  Future<List<int>> recordedSamples(String recordingId) async {
    final out = <int>[];
    for (final c in await chunks(recordingId)) {
      final bytes = file(c).readAsBytesSync();
      final info = WavHeader.parse(Uint8List.sublistView(bytes, 0, 44));
      expect(info, isNotNull, reason: 'chunk ${c.seq} header');
      expect(info!.isContractFormat, isTrue, reason: 'chunk ${c.seq}');
      expect(info.dataBytes, bytes.length - 44, reason: 'chunk ${c.seq}');
      out.addAll(Pcm.samples(Uint8List.sublistView(bytes, 44)));
    }
    return out;
  }
}
