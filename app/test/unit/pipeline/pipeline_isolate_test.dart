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

/// Engines whose hooks fail in different ways after the worker started.
PipelineEngines faultyEngines(PipelineWorkerContext ctx) => PipelineEngines(
  stt: ScriptedStt(),
  llm: ScriptedLlm(),
  vault: FakeVaultWriter(),
  // Synchronous throw inside a command handler.
  onMemoryPressure: () => throw StateError('hook failed'),
  // Uncaught asynchronous error (fatal for the isolate), or an abrupt
  // isolate exit while a command is pending.
  onForeground: ({required foreground}) {
    if (foreground) {
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }
    unawaited(Future<void>.error(StateError('async hook failed')));
  },
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

  test('[FND-05/AC3] a command that throws in the worker is answered and '
      'the worker keeps serving commands', () async {
    final db = memoryDb();
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
    final client = await PipelineIsolateClient.spawn(
      database: await db.serializableConnection(),
      storageRoot: tempPaths().root,
      engines: faultyEngines,
    );
    addTearDown(client.dispose);
    await client.memoryPressure().timeout(const Duration(seconds: 5));
    final id = await client.enqueue('r1').timeout(const Duration(seconds: 5));
    expect(id.isOk, isTrue, reason: 'worker still alive');
  });

  test('[FND-05/AC3] a worker crash after startup fails pending and later '
      'commands instead of hanging, and is reported', () async {
    final db = memoryDb();
    final client = await PipelineIsolateClient.spawn(
      database: await db.serializableConnection(),
      storageRoot: tempPaths().root,
      engines: faultyEngines,
    );
    addTearDown(client.dispose);
    // Uncaught async error in the worker (fatal for the isolate).
    await client.setForeground(foreground: false);
    await client.terminated.timeout(const Duration(seconds: 5));
    expect(
      (await client.cancel('x').timeout(const Duration(seconds: 5)))
          .failureOrNull,
      isA<UnexpectedFailure>(),
    );
    await client.dispose().timeout(const Duration(seconds: 5));
  });

  test('[FND-05/AC3] a pending command completes when the worker exits '
      'abruptly', () async {
    final db = memoryDb();
    final client = await PipelineIsolateClient.spawn(
      database: await db.serializableConnection(),
      storageRoot: tempPaths().root,
      engines: faultyEngines,
    );
    addTearDown(client.dispose);
    // The hook kills the isolate before the reply is sent.
    await client
        .setForeground(foreground: true)
        .timeout(const Duration(seconds: 5));
    await client.terminated.timeout(const Duration(seconds: 5));
    expect(
      (await client.enqueue('r1').timeout(const Duration(seconds: 5)))
          .failureOrNull,
      isA<UnexpectedFailure>(),
    );
  });
}
