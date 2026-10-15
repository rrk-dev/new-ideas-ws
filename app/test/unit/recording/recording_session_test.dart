import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/data/recording_session_service.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

import 'capture_rig.dart';

void main() {
  test('[AUD-08/AC2] markers are persisted with kind = user and at_ms on the '
      'recording time base (paused spans excluded)', () async {
    final rig = CaptureRig();
    final service = RecordingSessionService(
      recordings: rig.db.recordingsRepository,
      settings: rig.db.settingsRepository,
    );
    await rig.controller.start(StartSource.inAppButton);
    final id = rig.backend.recordingId!;
    await rig.speakPaced(const Duration(seconds: 3));
    await rig.settle();
    expect(rig.backend.recorded, const Duration(seconds: 3));
    await service.addMarker(id, rig.backend.recorded);

    await rig.controller.pause();
    rig.clock.advance(const Duration(minutes: 5)); // paused: not counted
    await rig.controller.resume(ResumeSource.inAppButton);
    await rig.speakPaced(const Duration(seconds: 2));
    await rig.settle();
    await service.addMarker(id, rig.backend.recorded);
    await rig.controller.stop();

    final user = (await rig.markers(id))
        .where((m) => m.kind == MarkerKind.user)
        .toList();
    expect([for (final m in user) m.atMs], [3000, 5000]);
    expect(user.every((m) => m.recordingId == id), isTrue);
  });

  test('setup, consent time, details and destination are stored', () async {
    final rig = CaptureRig();
    final service = RecordingSessionService(
      recordings: rig.db.recordingsRepository,
      settings: rig.db.settingsRepository,
    );
    await rig.controller.start(StartSource.inAppButton);
    final id = rig.backend.recordingId!;
    final consentAt = DateTime.utc(2026, 10, 14, 9);
    await service.applySetup(
      id,
      const RecordingSetup(profileId: 'interview', destinationId: 'v1'),
      consentConfirmedAt: consentAt,
    );
    var row = await rig.row(id);
    expect(row.profileId, 'interview');
    expect(row.consentConfirmedAt, consentAt);
    expect(
      (await rig.db.settingsRepository.get(recordingDestinationKey(id)))
          .valueOrNull,
      'v1',
    );
    await rig.controller.stop();
    await service.saveDetails(
      id,
      title: '  Weekly sync ',
      tags: RecordingSessionService.parseTags(' team, ,sync, team '),
      setup: const RecordingSetup(profileId: 'meeting'),
    );
    row = await rig.row(id);
    expect(row.title, 'Weekly sync');
    expect(row.tags, ['team', 'sync']);
    expect(row.profileId, 'meeting');
    expect(
      (await rig.db.settingsRepository.get(recordingDestinationKey(id)))
          .valueOrNull,
      isNull,
      reason: 'Auto = no override',
    );
    expect(rig.controller.state.phase, RecordingPhase.stopped);
  });

  test('[SEC-07/AC2] consent time is stored; spoken-consent marker is '
      'kind consent', () async {
    final rig = CaptureRig();
    final service = RecordingSessionService(
      recordings: rig.db.recordingsRepository,
      settings: rig.db.settingsRepository,
    );
    await rig.controller.start(StartSource.inAppButton);
    final id = rig.backend.recordingId!;
    final at = DateTime.utc(2026, 10, 14, 9);
    await service.applySetup(
      id,
      const RecordingSetup(profileId: 'meeting'),
      consentConfirmedAt: at,
    );
    expect((await rig.row(id)).consentConfirmedAt, at);
    final m = await service.addSpokenConsentMarker(
      id,
      const Duration(seconds: 3),
    );
    expect(m, isA<Ok<int>>());
    final markers = await rig.db.recordingsRepository.watchMarkers(id).first;
    expect(markers.single.kind, MarkerKind.consent);
  });

  test('[AUD-08] finish() queues per processing.auto_process; processNow '
      'jumps the queue', () async {
    final rig = CaptureRig();
    final calls = <(String, bool)>[];
    final service = RecordingSessionService(
      recordings: rig.db.recordingsRepository,
      settings: rig.db.settingsRepository,
      enqueue: (id, {userInitiated = false}) async {
        calls.add((id, userInitiated));
        return const Ok<void>(null);
      },
    );
    expect(await service.finish('r1'), isTrue, reason: 'default on');
    await rig.db.settingsRepository.set('processing.auto_process', false);
    expect(await service.finish('r2'), isFalse);
    expect(await service.processNow('r2'), isTrue);
    expect(calls, [('r1', false), ('r2', true)]);
    final none = RecordingSessionService(
      recordings: rig.db.recordingsRepository,
      settings: rig.db.settingsRepository,
    );
    expect(await none.finish('r3'), isFalse);
  });

  test('[AUD-08] a failed enqueue is reported as not queued', () async {
    final rig = CaptureRig();
    final service = RecordingSessionService(
      recordings: rig.db.recordingsRepository,
      settings: rig.db.settingsRepository,
      enqueue: (id, {userInitiated = false}) async =>
          const Err<void>(UnexpectedFailure('queue')),
    );
    expect(await service.finish('r1'), isFalse);
    expect(await service.processNow('r1'), isFalse);
  });
}
