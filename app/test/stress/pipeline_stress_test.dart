import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

import '../db/db_test_utils.dart';
import '../fakes/fake_clock.dart';
import '../fakes/fake_vault_writer.dart';
import '../unit/pipeline/pipeline_test_utils.dart';

/// QA-04 stress tests over the real orchestrator with scripted engines: queue
/// depth, kill/relaunch mid-queue, storage and vault failures. The on-device
/// half (3 h recording, calls, reboot, OS upgrades) is in
/// docs/test-plans/stress.md.
class _Run {
  _Run(this.db, this.paths, {ScriptedStt? stt}) : stt = stt ?? ScriptedStt();

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final ScriptedStt stt;
  final llm = ScriptedLlm();
  final vault = FakeVaultWriter();
  final clock = FakeClock(t0);
  final released = <HeavyModel>[];
  late final PipelineOrchestrator o;

  Future<PipelineOrchestrator> start() async {
    o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: stt,
        llm: llm,
        vault: vault,
        clock: clock,
        gate: HeavyModelGate(release: (m) async => released.add(m)),
      ),
      newId: sequentialIds(),
    );
    addTearDown(o.dispose);
    await o.start();
    return o;
  }
}

Future<List<JobState>> _states(VaultVoiceDatabase db, List<String> ids) async =>
    [for (final id in ids) (await loadJob(db, id)).state];

Future<void> _unpark(
  PipelineOrchestrator o,
  VaultVoiceDatabase db,
  String id,
) async {
  final job = await loadJob(db, id);
  expectOk(
    job.state == JobState.waiting
        ? await o.resolveWaiting(id)
        : await o.retry(id),
  );
}

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    await seedVaultTarget(db);
  });

  test('[QA-04/AC1] 50 queued recordings process back to back, none lost, '
      'one heavy model at a time', () async {
    final run = _Run(db, paths);
    for (var i = 0; i < 50; i++) {
      await seedRecordingWithChunks(db, 'r$i', chunks: 2);
    }
    final o = await run.start();
    final ids = <String>[];
    for (var i = 0; i < 50; i++) {
      ids.add(expectOk(await o.enqueue('r$i')));
    }
    await o.whenIdle();

    expect(await _states(db, ids), everyElement(JobState.done));
    expect(run.stt.calls, hasLength(100));
    expect(run.vault.notes, hasLength(50));
    expect(await db.select(db.exports).get(), hasLength(50));
  });

  test('[QA-04/AC1] a 3 hour recording (360 chunks) resumes after a kill '
      'without re-transcribing committed chunks', () async {
    final dir = Directory.systemTemp.createTempSync('vv_stress_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/vaultvoice.sqlite');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final db1 = VaultVoiceDatabase(NativeDatabase(file));
    await seedRecordingWithChunks(db1, 'long', chunks: 360);
    await seedVaultTarget(db1);
    final run1 = _Run(db1, paths, stt: ScriptedStt(blockOn: 200));
    final o1 = await run1.start();
    final id = expectOk(await o1.enqueue('long'));
    await until(() => run1.stt.blocked);
    await o1.dispose();
    await db1.close();

    final db2 = VaultVoiceDatabase(NativeDatabase(file));
    addTearDown(db2.close);
    final run2 = _Run(db2, paths);
    final o2 = await run2.start();
    await o2.whenIdle();

    expect((await loadJob(db2, id)).state, JobState.done);
    expect(run2.stt.calls.length, lessThanOrEqualTo(160));
    final segments = expectOk(
      await db2.transcriptsRepository.segments(transcriptIdFor(id)),
    );
    expect(segments, hasLength(360));
    expect(run2.vault.notes, hasLength(1));
  });

  test('[QA-04/AC1] a kill in the middle of a 20-job queue loses no job and '
      'exports each note once', () async {
    final dir = Directory.systemTemp.createTempSync('vv_stress_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/vaultvoice.sqlite');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final db1 = VaultVoiceDatabase(NativeDatabase(file));
    for (var i = 0; i < 20; i++) {
      await seedRecordingWithChunks(db1, 'r$i', chunks: 2);
    }
    await seedVaultTarget(db1);
    final run1 = _Run(db1, paths, stt: ScriptedStt(blockOn: 15));
    final o1 = await run1.start();
    final ids = <String>[
      for (var i = 0; i < 20; i++) expectOk(await o1.enqueue('r$i')),
    ];
    await until(() => run1.stt.blocked);
    await o1.dispose();
    await db1.close();

    final db2 = VaultVoiceDatabase(NativeDatabase(file));
    addTearDown(db2.close);
    final run2 = _Run(db2, paths);
    final o2 = await run2.start();
    await o2.whenIdle();

    expect(await _states(db2, ids), everyElement(JobState.done));
    expect(await db2.select(db2.exports).get(), hasLength(20));
    expect(run1.vault.notes.length + run2.vault.notes.length, 20);
  });

  test('[QA-04/AC1] low storage during export keeps the transcript and a '
      'retry completes the job', () async {
    final run = _Run(db, paths);
    await seedRecordingWithChunks(db, 'r1');
    run.vault.failWith(const StorageFailure('no space left on device'));
    final o = await run.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();

    expect((await loadJob(db, id)).state, isNot(JobState.done));
    expect(run.vault.notes, isEmpty);
    expect(
      expectOk(await db.transcriptsRepository.segments(transcriptIdFor(id))),
      isNotEmpty,
    );

    run.vault.clearFailure();
    final parked = (await loadJob(db, id)).state;
    if (parked == JobState.failed || parked == JobState.waiting) {
      await _unpark(o, db, id);
    } else {
      run.clock.advance(const Duration(hours: 1)); // past the retry backoff
      o.poke();
    }
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
    expect(run.vault.notes, hasLength(1));
  });

  test('[QA-04/AC1] vault permission revoked mid-queue parks jobs and they '
      'finish once access returns', () async {
    final run = _Run(db, paths);
    for (var i = 0; i < 5; i++) {
      await seedRecordingWithChunks(db, 'r$i', chunks: 1);
    }
    run.vault.access = VaultAccess.revoked;
    final o = await run.start();
    final ids = <String>[
      for (var i = 0; i < 5; i++) expectOk(await o.enqueue('r$i')),
    ];
    await o.whenIdle();
    for (final s in await _states(db, ids)) {
      expect(s, isIn([JobState.waiting, JobState.failed]));
    }
    expect(run.vault.notes, isEmpty);

    run.vault.access = VaultAccess.ok;
    for (final id in ids) {
      await _unpark(o, db, id);
    }
    await o.whenIdle();
    expect(await _states(db, ids), everyElement(JobState.done));
    expect(run.vault.notes, hasLength(5));
  });
}
