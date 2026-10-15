import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/call_guard.dart';
import 'package:vaultvoice/features/recording/data/recording_recovery.dart';
import 'package:vaultvoice/features/recording/data/wav_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

import '../test/db/db_test_utils.dart';
import '../test/unit/recording/capture_rig.dart';

/// GATE-01 automatable half (docs/test-plans/gates/GATE-01.md). The real
/// capture backend, chunk writer, controller and recovery run against a fake
/// microphone and fake call guard; real-device rows are in
/// docs/test-plans/device/GATE-01.md.
///   cd app && fvm flutter test integration_test/gate_01_recording_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('[GATE-01/AC2] a 10 min locked recording yields valid 16 kHz '
      'mono WAV chunks whose duration matches the timer within 0.5 s', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final rig = CaptureRig();
      expectOk(await rig.controller.start(StartSource.inAppButton));
      final id = rig.backend.recordingId!;
      await rig.speakPaced(const Duration(minutes: 10));
      await rig.settle();
      final timer = rig.controller.elapsed;
      final stopped = expectOk(await rig.controller.stop());

      final samples = await rig.recordedSamples(id); // validates each header
      final audio = AudioFormat.durationOf(samples.length);
      expect(
        (audio - timer).abs(),
        lessThanOrEqualTo(const Duration(milliseconds: 500)),
      );
      expect(stopped.duration, audio);
      expect((await rig.row(id)).status, RecordingStatus.recorded);
    });
  });

  testWidgets('[GATE-01/AC3] a call stops capture without call audio, stays '
      'paused until Resume, and Record is refused during a call', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final rig = CaptureRig();
      expectOk(await rig.controller.start(StartSource.inAppButton));
      final id = rig.backend.recordingId!;
      await rig.speakPaced(const Duration(seconds: 3));
      await rig.settle();

      rig.guard.emit(CallGuardSignal.callActive, rig.clock.now());
      await rig.settle();
      expect(rig.controller.state.phase, RecordingPhase.paused);
      expect(rig.controller.state.pauseCause, PauseCause.call);

      expect(rig.mic.micOpen, isFalse, reason: 'microphone released');
      rig.guard.emit(CallGuardSignal.callEnded, rig.clock.now());
      await rig.settle();
      expect(
        rig.controller.state.phase,
        RecordingPhase.paused,
        reason: 'never auto-resumes',
      );

      final during = await rig.controller.stop();
      expect(during.isOk, isTrue);
      final samples = await rig.recordedSamples(id);
      // The safety margin may trim audio from just before the ring, never
      // keep any after it.
      expect(
        AudioFormat.durationOf(samples.length),
        lessThanOrEqualTo(const Duration(seconds: 3)),
      );

      final other = CaptureRig()..guard.inCall = true;
      final refused = await other.controller.start(StartSource.inAppButton);
      expect(refused.isOk, isFalse);
      expect(
        (refused.failureOrNull! as RecordingBlockedFailure).reason,
        RecordingBlockReason.inCall,
      );
      expect(other.controller.state.phase, RecordingPhase.idle);
    });
  });

  testWidgets('[GATE-01/AC3] Resume is a user tap and is refused while the '
      'call is still active', (tester) async {
    await tester.runAsync(() async {
      final rig = CaptureRig();
      expectOk(await rig.controller.start(StartSource.inAppButton));
      rig.guard.emit(CallGuardSignal.callActive, rig.clock.now());
      await rig.settle();
      final early = await rig.controller.resume(ResumeSource.inAppButton);
      expect(early.isOk, isFalse);
      rig.guard.emit(CallGuardSignal.callEnded, rig.clock.now());
      await rig.settle();
      expectOk(await rig.controller.resume(ResumeSource.inAppButton));
      expect(rig.controller.state.phase, RecordingPhase.recording);
    });
  });

  testWidgets('[GATE-01/AC4] a force-killed recording is recovered, valid and '
      'playable on relaunch', (tester) async {
    await tester.runAsync(() async {
      final rig = CaptureRig(chunkDuration: const Duration(seconds: 2));
      expectOk(await rig.controller.start(StartSource.inAppButton));
      await rig.speakPaced(const Duration(seconds: 7));
      await rig.settle();
      final id = rig.backend.recordingId!;
      await rig.backend.dispose(); // process dies: nothing is finalized

      final recovered = expectOk(
        await RecordingRecovery(
          recordings: rig.db.recordingsRepository,
          paths: rig.paths,
          codec: const WavChunkCodec(),
        ).recoverOrphans(),
      );
      expect(recovered.single.recordingId, id);
      final row = await rig.row(id);
      expect(row.status, RecordingStatus.recorded);
      expect(row.recovered, isTrue);
      final kept = AudioFormat.durationOf(
        (await rig.recordedSamples(id)).length,
      );
      expect(
        const Duration(seconds: 7) - kept,
        lessThanOrEqualTo(const Duration(seconds: 1)),
      );
    });
  });
}
