import 'dart:async';
import 'dart:isolate';

import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_isolate.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';
import '../../helpers/test_container.dart';
import 'pipeline_test_utils.dart';

/// Records the isolate the engines were built in.
String? enginesIsolate;

PipelineEngines fakeEngines(PipelineWorkerContext _) {
  enginesIsolate = Isolate.current.debugName;
  return PipelineEngines(
    stt: ScriptedStt(),
    llm: ScriptedLlm(),
    vault: FakeVaultWriter(),
  );
}

/// Engines whose condition hooks write to the shared DB (observable from
/// the test isolate).
PipelineEngines conditionEngines(PipelineWorkerContext ctx) => PipelineEngines(
  stt: ScriptedStt(),
  llm: ScriptedLlm(),
  vault: FakeVaultWriter(),
  onForeground: ({required foreground}) =>
      ctx.db.settingsRepository.set('test.foreground', foreground),
  onMemoryPressure: () => ctx.db.settingsRepository.set('test.pressure', true),
  dispose: () => ctx.db.settingsRepository.set('test.disposed', true),
);

void main() {
  test('[FND-05/AC3] the worker runs on its own isolate; commands and events '
      'cross the boundary', () async {
    final db = memoryDb();
    final paths = tempPaths();
    await seedRecordingWithChunks(db, 'r1', chunks: 2);
    await seedVaultTarget(db);

    final client = await PipelineIsolateClient.spawn(
      database: await db.serializableConnection(),
      storageRoot: paths.root,
      engines: fakeEngines,
    );
    final events = <JobEvent>[];
    client.events.listen(events.add);

    final id = (await client.enqueue('r1')).valueOrNull!;
    await until(() => events.any((e) => e.state == JobState.done));
    // The engines were never created on the test (UI) isolate.
    expect(enginesIsolate, isNull);
    expect(
      (await loadJob(db, id)).state,
      JobState.done,
      reason: 'the worker writes through the shared connection',
    );
    expect(events.first.recordingId, 'r1');

    // Every command is forwarded.
    expect(
      (await client.processNow(id)).failureOrNull,
      isA<UnexpectedFailure>(),
    );
    expect((await client.cancel(id)).failureOrNull, isA<UnexpectedFailure>());
    expect((await client.pause(id)).failureOrNull, isA<UnexpectedFailure>());
    expect((await client.resume(id)).failureOrNull, isA<UnexpectedFailure>());
    expect(
      (await client.resolveWaiting(id)).failureOrNull,
      isA<UnexpectedFailure>(),
    );
    expect((await client.retry(id)).failureOrNull, isA<UnexpectedFailure>());
    events.clear();
    expect(
      (await client.rerun(id, PipelineStepId.extract, profileId: 'x')).isOk,
      isTrue,
    );
    await until(() => events.any((e) => e.state == JobState.done));

    await client.dispose();
    await client.dispose(); // idempotent
    expect(
      (await client.enqueue('r1')).failureOrNull,
      isA<UnexpectedFailure>(),
    );
  });

  test('[FND-05/AC3] providers spawn the worker over the app database and '
      'stream jobs', () async {
    final paths = tempPaths();
    final container = createContainer(
      overrides: [
        storagePathsProvider.overrideWith((ref) async => paths),
        pipelineEnginesFactoryProvider.overrideWith((ref) async => fakeEngines),
      ],
    );
    final db = container.read(vaultVoiceDatabaseProvider);
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
    expect(container.read(pipelineConfigProvider).defaultProfileId, 'meeting');

    final client = await container.read(pipelineClientProvider.future);
    final id = (await client.enqueue('r1', userInitiated: true)).valueOrNull!;

    final done = Completer<void>();
    final sub = container.listen(recordingJobsProvider('r1'), (_, next) {
      final jobs = next.value ?? const <JobSnapshot>[];
      if (jobs.any((j) => j.id == id && j.state == JobState.done) &&
          !done.isCompleted) {
        done.complete();
      }
    }, fireImmediately: true);
    addTearDown(sub.close);
    await done.future.timeout(const Duration(seconds: 10));
    // Riverpod 3 pauses unlistened providers: subscribe like a widget does.
    final jobsSub = container.listen(pipelineJobsProvider, (_, _) {});
    addTearDown(jobsSub.close);
    final jobs = await container.read(pipelineJobsProvider.future);
    expect(jobs.single.priority, 10);
  });

  test('[FND-11/AC1] lifecycle and memory pressure reach the worker '
      'engines; dispose frees them', () async {
    final db = memoryDb();
    final client = await PipelineIsolateClient.spawn(
      database: await db.serializableConnection(),
      storageRoot: tempPaths().root,
      engines: conditionEngines,
    );
    Future<Object?> setting(String key) async =>
        (await db.settingsRepository.get(key)).valueOrNull;
    // The hooks are fire-and-forget in the worker: poll the shared DB.
    Future<void> expectSetting(String key, Object value) async {
      final sw = Stopwatch()..start();
      while (await setting(key) != value) {
        if (sw.elapsed > const Duration(seconds: 5)) fail('$key != $value');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    await client.setForeground(foreground: false);
    await expectSetting('test.foreground', false);
    await client.setForeground(foreground: true);
    await expectSetting('test.foreground', true);
    await client.memoryPressure();
    await expectSetting('test.pressure', true);
    await client.dispose();
    expect(await setting('test.disposed'), isTrue);
    // After dispose the calls are no-ops.
    await client.setForeground(foreground: false);
    await client.memoryPressure();
    expect(await setting('test.foreground'), isTrue);
  });
}
