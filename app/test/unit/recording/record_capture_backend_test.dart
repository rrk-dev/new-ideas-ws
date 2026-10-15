import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/pcm_mic_source.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';
import 'package:vaultvoice/features/recording/domain/storage_policy.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_pcm_mic_source.dart';
import 'capture_rig.dart';

const _ms = Duration(milliseconds: 1);
const _fade = 160; // PcmFade.defaultSamples

int _n(int ms) => AudioFormat.samplesFor(_ms * ms);

/// A codec that only counts bytes (no disk) — for the 2-hour session.
class _CountingCodec implements AudioChunkCodec {
  final writers = <String, _CountingWriter>{};

  @override
  ChunkCodecId get id => ChunkCodecId.wav;

  @override
  Future<AudioChunkWriter> create(String path) async =>
      writers[path] = _CountingWriter();

  @override
  Future<AudioChunkWriter> reopen(String path) async => writers[path]!;

  @override
  Future<int> recover(String path) async => writers[path]?.dataBytes ?? 0;
}

class _CountingWriter implements AudioChunkWriter {
  @override
  int dataBytes = 0;
  int flushes = 0;
  bool closed = false;

  @override
  int get fileBytes => 44 + dataBytes;

  @override
  Future<void> append(Uint8List pcm) async => dataBytes += pcm.length;

  @override
  Future<void> flush() async => flushes++;

  @override
  Future<Uint8List> readTail(int fromDataByte) async =>
      Uint8List(dataBytes - fromDataByte);

  @override
  Future<void> truncate(int dataBytes) async => this.dataBytes = dataBytes;

  @override
  Future<int> close() async {
    closed = true;
    return fileBytes;
  }
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'condition not reached in 2 s');
}

void main() {
  group('continuous capture', () {
    test('[AUD-01/AC1] continuous recording is written as gapless, '
        'sample-exact 16 kHz mono WAV chunks', () async {
      final rig = CaptureRig(chunkDuration: const Duration(seconds: 2));
      expectOk(await rig.controller.start(StartSource.inAppButton));
      // Delivery blocks deliberately not aligned to chunk boundaries.
      rig.speak(_ms * 7300, block: _ms * 64);
      final done = expectOk(await rig.controller.stop());
      final id = done.recordingId!;

      final chunks = await rig.chunks(id);
      expect(
        [for (final c in chunks) (c.seq, c.startMs, c.endMs)],
        [(0, 0, 2000), (1, 2000, 4000), (2, 4000, 6000), (3, 6000, 7300)],
      );
      for (final c in chunks) {
        expect(c.sampleRate, 16000);
        expect(c.bytes, rig.file(c).lengthSync());
        expect(
          c.path,
          'audio/$id/chunk_${c.seq.toString().padLeft(4, '0')}'
          '.wav',
        );
      }
      final got = await rig.recordedSamples(id);
      final want = Pcm.samples(Pcm.counter(_n(7300)));
      expect(got.length, want.length, reason: 'no dropped/duplicated sample');
      // Identical except the 10 ms fade-in/out at the segment ends: chunk
      // boundaries are seamless.
      expect(
        got.sublist(_fade, got.length - _fade),
        want.sublist(_fade, want.length - _fade),
      );
      expect(done.duration, _ms * 7300);
      final row = await rig.row(id);
      expect(row.status, RecordingStatus.recorded);
      expect(row.source, RecordingSource.mic);
      expect(row.durationMs, 7300);
      expect(row.stopReason, StopReason.user);
    });

    test('[AUD-01/AC1] a 2-hour session rolls into 24 contiguous 5-minute '
        'chunks with the exact duration', () async {
      final codec = _CountingCodec();
      final rig = CaptureRig(
        chunkDuration: const Duration(minutes: 5),
        codec: codec,
      );
      expectOk(await rig.controller.start(StartSource.inAppButton));
      await rig.speakPaced(const Duration(hours: 2), silent: true);
      final done = expectOk(await rig.controller.stop());
      final chunks = await rig.chunks(done.recordingId!);
      expect(chunks, hasLength(24));
      for (var i = 0; i < 24; i++) {
        expect(chunks[i].startMs, i * 300000);
        expect(chunks[i].endMs, (i + 1) * 300000);
        expect(chunks[i].bytes, 44 + 300 * AudioFormat.bytesPerSecond);
      }
      expect(codec.writers.values.every((w) => w.closed), isTrue);
      expect(done.duration, const Duration(hours: 2));
      expect((await rig.row(done.recordingId!)).durationMs, 7200000);
    });

    test('everything appended is flushed to disk within the flush interval '
        '(file valid without closing)', () async {
      final rig = CaptureRig(flushInterval: _ms * 100);
      expectOk(await rig.controller.start(StartSource.inAppButton));
      rig.speak(_ms * 500);
      await Future<void>.delayed(_ms * 250);
      await rig.settle();
      final id = rig.backend.recordingId!;
      final chunk = (await rig.chunks(id)).single;
      final bytes = rig.file(chunk).readAsBytesSync();
      expect(bytes.length, 44 + _n(500) * 2);
      expect(
        ByteData.sublistView(bytes).getUint32(40, Endian.little),
        _n(500) * 2,
      );
      expect(chunk.bytes, bytes.length);
      expect(chunk.endMs, 500);
      expect((await rig.row(id)).status, RecordingStatus.recording);
      expect((await rig.row(id)).durationMs, 500);
      await rig.controller.stop();
    });
  });

  group('calls (SEC-09)', () {
    test('[AUD-01/AC2] a call while recording stops capture at once, never '
        'writes audio from after the call event and stays paused until the '
        'user resumes', () async {
      final rig = CaptureRig();
      expectOk(await rig.controller.start(StartSource.inAppButton));
      rig.speak(const Duration(seconds: 3));
      // Platform event time is 400 ms before the newest delivered audio
      // (delivery latency).
      rig.guard.emit(
        CallGuardSignal.callActive,
        rig.clock.now().subtract(_ms * 400),
      );
      // Synchronously: the controller is paused and capture stopped.
      expect(rig.controller.state.phase, RecordingPhase.paused);
      expect(rig.controller.state.pauseCause, PauseCause.call);
      // Audio still in flight from the platform is dropped, not written.
      if (rig.mic.micOpen) rig.speak(_ms * 200);
      await rig.settle();
      expect(rig.mic.micOpen, isFalse);

      final id = rig.backend.recordingId!;
      // 3000 − 400 (after the event) − 250 (safety margin) = 2350 ms kept.
      expect(await rig.recordedSamples(id), hasLength(_n(2350)));
      final marker = (await rig.markers(id)).single;
      expect(marker.kind, MarkerKind.callInterruption);
      expect(marker.label, 'call_interruption');
      expect(marker.atMs, 2350);
      expect((await rig.row(id)).status, RecordingStatus.inProgress);

      // Hang-up never resumes.
      rig.guard.emit(CallGuardSignal.callEnded, rig.clock.now());
      await rig.settle();
      expect(rig.controller.state.phase, RecordingPhase.paused);
      expect(rig.mic.opens, 1);
      expect(rig.mic.micOpen, isFalse);

      // Only the user's tap resumes, into a new chunk.
      expectOk(await rig.controller.resume(ResumeSource.inAppButton));
      expect(rig.mic.opens, 2);
      rig.speak(const Duration(seconds: 1));
      final done = expectOk(await rig.controller.stop());
      expect(
        [for (final c in await rig.chunks(id)) (c.startMs, c.endMs)],
        [(0, 2350), (2350, 3350)],
      );
      expect(done.duration, _ms * 3350);
    });

    test('[AUD-01/AC2] start is refused while a call rings: the microphone is '
        'never opened and nothing is persisted', () async {
      final rig = CaptureRig()..guard.inCall = true;
      final r = await rig.controller.start(StartSource.inAppButton);
      expect(
        (r.failureOrNull! as RecordingBlockedFailure).reason,
        RecordingBlockReason.inCall,
      );
      expect(rig.mic.opens, 0);
      expect(rig.mic.permissionRequests, 0);
      expect(await rig.db.recordingsRepository.watchAll().first, isEmpty);
    });

    test(
      '[AUD-01/AC2] the discard reaches back across a chunk rollover',
      () async {
        final rig = CaptureRig(chunkDuration: const Duration(seconds: 1));
        expectOk(await rig.controller.start(StartSource.inAppButton));
        rig.speak(_ms * 1100);
        rig.guard.emit(
          CallGuardSignal.callActive,
          rig.clock.now().subtract(_ms * 600),
        );
        await rig.settle();
        final id = rig.backend.recordingId!;
        // 1100 − 600 − 250 = 250 ms kept; the post-rollover chunk is gone.
        final chunks = await rig.chunks(id);
        expect(
          [for (final c in chunks) (c.seq, c.startMs, c.endMs)],
          [(0, 0, 250)],
        );
        expect(await rig.recordedSamples(id), hasLength(_n(250)));
        expect(
          rig.dir.listSync(recursive: true).whereType<Object>(),
          isNotEmpty,
        );
        await rig.controller.stop();
      },
    );
  });

  group('pause / resume', () {
    test('[AUD-01/AC3] pause/resume produces no duplicated or dropped '
        'samples and no click at the boundary', () async {
      final rig = CaptureRig();
      expectOk(await rig.controller.start(StartSource.inAppButton));
      // Worst case for a click: full-scale positive before the pause,
      // full-scale negative after it.
      rig.speak(_ms * 1000, signal: (_) => 30000);
      final pauseAt = rig.nextSample;
      expectOk(await rig.controller.pause());
      expect(rig.mic.micOpen, isFalse);
      rig.clock.advance(const Duration(seconds: 30)); // paused span
      expectOk(await rig.controller.resume(ResumeSource.inAppButton));
      rig.speak(_ms * 1000, signal: (_) => -30000);
      final done = expectOk(await rig.controller.stop());
      final id = done.recordingId!;

      final got = await rig.recordedSamples(id);
      expect(got, hasLength(rig.nextSample), reason: 'no dup/drop');
      expect(done.duration, const Duration(seconds: 2), reason: 'gap excluded');
      var maxStep = 0;
      for (var i = 1; i < got.length; i++) {
        maxStep = max(maxStep, (got[i] - got[i - 1]).abs());
      }
      // Without ramps the boundary would jump by 60 000.
      expect(maxStep, lessThan(1000));
      expect(got.sublist(_fade, pauseAt - _fade).toSet(), {30000});
      expect(got.sublist(pauseAt + _fade, got.length - _fade).toSet(), {
        -30000,
      });
      final marker = (await rig.markers(id)).single;
      expect(marker.kind, MarkerKind.gap);
      expect(marker.label, 'user_pause');
      expect(marker.atMs, 1000);
    });
  });

  group('pause at a chunk rollover', () {
    test('[AUD-01/AC3] pausing exactly at a chunk boundary still fades the '
        'segment out (no click on resume)', () async {
      final rig = CaptureRig(chunkDuration: const Duration(seconds: 1));
      expectOk(await rig.controller.start(StartSource.inAppButton));
      rig.speak(_ms * 1000, signal: (_) => 30000);
      final pauseAt = rig.nextSample;
      expectOk(await rig.controller.pause());
      expectOk(await rig.controller.resume(ResumeSource.inAppButton));
      rig.speak(_ms * 1000, signal: (_) => -30000);
      final done = expectOk(await rig.controller.stop());
      final got = await rig.recordedSamples(done.recordingId!);
      var maxStep = 0;
      for (var i = 1; i < got.length; i++) {
        maxStep = max(maxStep, (got[i] - got[i - 1]).abs());
      }
      expect(maxStep, lessThan(1000));
      expect(got[pauseAt - 1].abs(), lessThan(1000));
    });
  });

  group('storage, permission, platform', () {
    test(
      'refuses to start below 200 MB free (microphone never opened)',
      () async {
        final rig = CaptureRig()..disk.free = 150 * StoragePolicy.mb;
        final r = await rig.controller.start(StartSource.inAppButton);
        expect(r.failureOrNull, isA<StorageFailure>());
        expect(rig.mic.opens, 0);
        expect(await rig.db.recordingsRepository.watchAll().first, isEmpty);
      },
    );

    test('warns below 500 MB and stops + finalizes below 100 MB', () async {
      final rig = CaptureRig(
        storage: const StoragePolicy(checkInterval: Duration(milliseconds: 20)),
      )..disk.free = 400 * StoragePolicy.mb;
      final notices = <CaptureNotice>[];
      rig.controller.notices.listen(notices.add);
      expectOk(await rig.controller.start(StartSource.inAppButton));
      rig.speak(_ms * 300);
      await _until(() => notices.contains(CaptureNotice.lowStorageWarning));
      rig.disk.free = 50 * StoragePolicy.mb;
      await _until(() => rig.controller.state.phase == RecordingPhase.stopped);
      expect(rig.controller.state.stopCause, StopCause.lowStorage);
      // The low-storage stop is fire-and-forget: the phase flips to `stopped`
      // synchronously, then close() finalizes the row asynchronously. Wait for
      // that write instead of racing it (settle() only drains work queued so
      // far, which is not enough on a slow runner).
      var rows = await rig.db.recordingsRepository.watchAll().first;
      for (
        var i = 0;
        i < 200 && rows.single.status != RecordingStatus.recorded;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        rows = await rig.db.recordingsRepository.watchAll().first;
      }
      await rig.settle();
      expect(rows.single.status, RecordingStatus.recorded);
      expect(rows.single.stopReason, StopReason.lowStorage);
      expect(rig.mic.micOpen, isFalse);
    });

    test(
      'denied microphone permission → PermissionFailure, nothing kept',
      () async {
        final rig = CaptureRig()..mic.permission = false;
        final r = await rig.controller.start(StartSource.inAppButton);
        expect(r.failureOrNull, isA<PermissionFailure>());
        expect(rig.mic.opens, 0);
        expect(await rig.db.recordingsRepository.watchAll().first, isEmpty);
      },
    );

    test('a failing microphone open removes the recording row', () async {
      final rig = CaptureRig()
        ..mic.openFailure = const UnexpectedFailure('PlatformException');
      final r = await rig.controller.start(StartSource.inAppButton);
      expect(r.isOk, isFalse);
      expect(await rig.db.recordingsRepository.watchAll().first, isEmpty);
    });

    test('a platform that delivers 48 kHz is resampled to 16 kHz', () async {
      final rig = CaptureRig();
      expectOk(await rig.controller.start(StartSource.inAppButton));
      rig.mic.emitEvent(
        const MicFormatChanged(MicFormat(sampleRate: 48000, channels: 1)),
      );
      for (var b = 0; b < 10; b++) {
        rig.clock.advance(_ms * 100);
        rig.mic.emit(
          Pcm.of(
            4800,
            (i) => (8000 * sin(2 * pi * 500 * i / 48000)).round(),
            start: b * 4800,
          ),
          rig.clock.now(),
        );
      }
      final done = expectOk(await rig.controller.stop());
      expect(await rig.recordedSamples(done.recordingId!), hasLength(16000));
      expect(done.duration, const Duration(seconds: 1));
    });

    test('an OS pause of the microphone becomes a pause that only a tap '
        'ends', () async {
      final rig = CaptureRig();
      expectOk(await rig.controller.start(StartSource.inAppButton));
      rig.speak(_ms * 500);
      rig.mic.emitEvent(const MicInterrupted());
      await _until(() => rig.controller.state.phase == RecordingPhase.paused);
      expect(rig.controller.state.pauseCause, PauseCause.audioInterruption);
      await rig.settle();
      expect(rig.mic.micOpen, isFalse);
      final id = rig.backend.recordingId!;
      expect((await rig.markers(id)).single.label, 'audio_interruption');
      await Future<void>.delayed(_ms * 50);
      expect(rig.mic.opens, 1);
      await rig.controller.stop();
    });

    test('a failing microphone stream pauses with captureError', () async {
      final rig = CaptureRig();
      expectOk(await rig.controller.start(StartSource.inAppButton));
      rig.speak(_ms * 200);
      rig.mic.emitEvent(const MicFailed('PlatformException'));
      await _until(() => rig.controller.state.phase == RecordingPhase.paused);
      expect(rig.controller.state.pauseCause, PauseCause.captureError);
      await rig.controller.stop();
    });

    test('the selected input applies to the next open', () async {
      final rig = CaptureRig();
      const bt = AudioInputDevice(
        id: 'bt',
        label: 'Headset',
        kind: AudioInputKind.bluetooth,
      );
      expect(expectOk(await rig.backend.inputDevices()), hasLength(1));
      rig.backend.selectInput(bt);
      expect(rig.mic.opens, 0, reason: 'selecting never opens the mic');
      expectOk(await rig.controller.start(StartSource.inAppButton));
      expect(rig.mic.requests.single.device, same(bt));
      expect(
        rig.mic.requests.single.androidSource,
        MicAudioSource.voiceRecognition,
      );
      await rig.controller.stop();
    });
  });
}
