import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/features/export/domain/pending_export.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

final _t = DateTime.utc(2026, 10, 14);

JobSnapshot job(
  String id,
  String rec,
  JobState state, {
  PipelineStepId step = PipelineStepId.write,
  WaitingReason? waiting,
  int minutes = 0,
}) => JobSnapshot(
  id: id,
  recordingId: rec,
  state: state,
  step: step,
  createdAt: _t.add(Duration(minutes: minutes)),
  updatedAt: _t,
  waitingReason: waiting,
);

ExportRow row(String rec, String target, ExportStatus s, {int attempts = 1}) =>
    ExportRow(
      id: '$rec.$target',
      recordingId: rec,
      targetId: target,
      relPath: 'n.md',
      contentHash: '',
      status: s,
      attempts: attempts,
      updatedAt: _t,
    );

final _target = VaultTargetRow(
  id: 'v',
  platform: VaultPlatform.androidSaf,
  displayName: 'Vault',
  handle: 'h',
  createdAt: _t,
);

void main() {
  test('reasons from job state + outbox rows', () {
    final list = buildPendingExports(
      jobs: [
        job('j1', 'r1', JobState.waiting, waiting: WaitingReason.destination),
        job('j2', 'r2', JobState.rendered),
        job('j3', 'r3', JobState.failed),
        job('j4', 'r4', JobState.done),
      ],
      exports: [
        row('r1', 'v', ExportStatus.failed),
        row('r2', 'v', ExportStatus.failed, attempts: 2),
        row('r3', 'v', ExportStatus.failed),
        row('r4', 'v', ExportStatus.written),
      ],
      targets: [_target],
      titles: const {'r1': 'One'},
    );
    expect(
      {for (final p in list) p.recordingId: p.reason},
      {
        'r1': PendingReason.accessRevoked,
        'r2': PendingReason.retrying,
        'r3': PendingReason.failed,
      },
    );
    expect(list.first.title, 'One');
    expect(list.first.targetName, 'Vault');
  });

  test('waiting jobs without rows: no destination vs revoked', () {
    final jobs = [
      job('j1', 'r1', JobState.waiting, waiting: WaitingReason.destination),
    ];
    expect(
      buildPendingExports(
        jobs: jobs,
        exports: const [],
        targets: const [],
        titles: const {},
      ).single.reason,
      PendingReason.noDestination,
    );
    expect(
      buildPendingExports(
        jobs: jobs,
        exports: const [],
        targets: [_target],
        titles: const {},
      ).single.reason,
      PendingReason.accessRevoked,
    );
  });

  test('re-processing (latest job before the write step) is not pending; '
      'other waiting reasons are ignored', () {
    final list = buildPendingExports(
      jobs: [
        job('old', 'r1', JobState.done),
        job(
          'new',
          'r1',
          JobState.transcribing,
          step: PipelineStepId.transcribe,
          minutes: 5,
        ),
        job('j2', 'r2', JobState.waiting, waiting: WaitingReason.modelMissing),
      ],
      exports: [row('r1', 'v', ExportStatus.failed)],
      targets: [_target],
      titles: const {},
    );
    expect(list, isEmpty);
  });
}
