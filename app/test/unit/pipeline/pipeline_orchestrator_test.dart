import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_vault_writer.dart';
import 'pipeline_test_utils.dart';

class _Harness {
  _Harness(this.db, this.paths, {ScriptedStt? stt, ScriptedLlm? llm})
    : stt = stt ?? ScriptedStt(),
      llm = llm ?? ScriptedLlm();

  final VaultVoiceDatabase db;
  final StoragePaths paths;
  final ScriptedStt stt;
  final ScriptedLlm llm;
  final vault = FakeVaultWriter();
  final clock = FakeClock(t0);
  final released = <HeavyModel>[];

  /// Runs after each release is recorded (throw to simulate an unload
  /// failure).
  Future<void> Function(HeavyModel model)? onRelease;
  final events = <JobEvent>[];
  late final PipelineOrchestrator o;

  Future<PipelineOrchestrator> start({
    PipelineConfig config = const PipelineConfig(),
    String Function()? ids,
    bool run = true,
  }) async {
    o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: stt,
        llm: llm,
        vault: vault,
        clock: clock,
        gate: HeavyModelGate(
          release: (m) async {
            released.add(m);
            await onRelease?.call(m);
          },
        ),
      ),
      config: config,
      newId: ids ?? sequentialIds(),
    );
    o.events.listen(events.add);
    addTearDown(o.dispose);
    if (run) await o.start();
    return o;
  }

  List<JobState> statesOf(String jobId) => [
    for (final e in events)
      if (e.jobId == jobId &&
          (events.indexOf(e) == 0 ||
              events[events.indexOf(e) - 1].state != e.state))
        e.state,
  ];
}

/// The note path of the default filename pattern (EXP-02, FND-11) for a
/// recording created at [t0] without a title.
String noteName(String profile) {
  final d = t0.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}-$profile.md';
}

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;
  late _Harness h;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    h = _Harness(db, paths);
    await seedRecordingWithChunks(db, 'r1');
    await seedVaultTarget(db);
  });

  test('[FND-05/AC3] a recording runs queued → … → done with all outputs, '
      'one heavy model at a time', () async {
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();

    final job = await loadJob(db, id);
    expect(job.state, JobState.done);
    expect(job.progress, 1);
    expect(h.statesOf(id), [
      JobState.queued,
      JobState.transcribing,
      JobState.transcribed,
      JobState.extracting,
      JobState.extracted,
      JobState.rendering,
      JobState.rendered,
      JobState.writing,
      JobState.done,
    ]);
    // Progress events are emitted while active.
    expect(
      h.events.where((e) => e.state == JobState.transcribing).length,
      greaterThan(3),
    );

    final segments = expectOk(
      await db.transcriptsRepository.segments(transcriptIdFor(id)),
    );
    expect(
      [for (final s in segments) s.body],
      ['chunk_0', 'chunk_1', 'chunk_2'],
    );
    expect([for (final s in segments) s.startMs], [0, 30000, 60000]);
    final ext = expectOk(
      await db.extractionsRepository.get(extractionIdFor(id)),
    );
    expect(ext.valid, isTrue);
    expect(ext.profileId, 'meeting');
    final items = await db.select(db.actionItems).get();
    expect([for (final i in items) i.body], ['Send notes']);
    expect(File(paths.renderedFile('r1')).existsSync(), isTrue);
    expect(h.vault.notes.keys, [noteName('meeting')]);
    expect(h.vault.notes[noteName('meeting')], contains('chunk_1'));
    final export = (await db.select(db.exports).get()).single;
    expect(export.status, ExportStatus.written);
    expect(export.attempts, 1);

    // STT was released before the LLM was loaded; the LLM is released once
    // the queue is empty (FND-11).
    expect(h.released, [HeavyModel.stt, HeavyModel.llm]);
    expect(o.gate.loaded, isNull);
    expect(h.stt.calls, hasLength(3));
    expect(h.llm.requests, hasLength(1));
  });

  test('[AUD-08] the destination picked on the Record screen is used by '
      'the write step', () async {
    await seedVaultTarget(db, 'v2');
    expectOk(
      await db.settingsRepository.set(recordingDestinationKey('r1'), 'v2'),
    );
    final o = await h.start();
    expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    final export = (await db.select(db.exports).get()).single;
    expect(export.targetId, 'v2');
  });

  test('[FND-05/AC3] user-initiated jobs jump the queue; enqueue is '
      'idempotent per recording', () async {
    await seedRecordingWithChunks(db, 'r2', chunks: 1);
    final o = await h.start(run: false);
    final background = expectOk(await o.enqueue('r1'));
    expect(expectOk(await o.enqueue('r1')), background);
    h.clock.advance(const Duration(seconds: 1));
    final urgent = expectOk(await o.enqueue('r2', userInitiated: true));
    await o.start();
    await o.whenIdle();
    final doneOrder = [
      for (final e in h.events)
        if (e.state == JobState.done) e.jobId,
    ];
    expect(doneOrder, [urgent, background]);

    expect(
      (await o.processNow(background)).failureOrNull,
      isA<UnexpectedFailure>(),
      reason: 'done jobs cannot be bumped',
    );
  });

  test('[FND-05/AC1] killing mid-transcription and relaunching resumes from '
      'the last checkpoint without data loss', () async {
    final dir = Directory.systemTemp.createTempSync('vv_kill_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/vaultvoice.sqlite');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    // First run: chunk 1 hangs; the app is killed while transcribing it.
    final db1 = VaultVoiceDatabase(NativeDatabase(file));
    await seedRecordingWithChunks(db1, 'r1');
    await seedVaultTarget(db1);
    final run1 = _Harness(db1, paths, stt: ScriptedStt(blockOn: 1));
    final o1 = await run1.start();
    final id = expectOk(await o1.enqueue('r1'));
    await until(() => run1.stt.blocked);
    await o1.dispose(); // worker stops; nothing else is written
    await db1.close();

    // On disk: still transcribing, chunk 0 committed with its checkpoint.
    final db2 = VaultVoiceDatabase(NativeDatabase(file));
    addTearDown(db2.close);
    final killed = await loadJob(db2, id);
    expect(killed.state, JobState.transcribing);
    expect(killed.checkpoint['nextChunk'], 1);
    expect(
      expectOk(await db2.transcriptsRepository.segments(transcriptIdFor(id)))
          .map((s) => s.body),
      ['chunk_0'],
    );

    // Relaunch: recovered and resumed at chunk 1.
    final run2 = _Harness(db2, paths);
    final o2 = await run2.start();
    await o2.whenIdle();
    expect(run2.stt.calls, [
      paths.resolve('audio/r1/chunk_1.wav'),
      paths.resolve('audio/r1/chunk_2.wav'),
    ]);
    final job = await loadJob(db2, id);
    expect(job.state, JobState.done);
    final segments = expectOk(
      await db2.transcriptsRepository.segments(transcriptIdFor(id)),
    );
    expect(
      [for (final s in segments) s.body],
      ['chunk_0', 'chunk_1', 'chunk_2'],
    );
    expect(run2.statesOf(id).first, JobState.queued); // recovered
    expect(await db2.select(db2.exports).get(), hasLength(1));
    expect(run2.vault.notes.keys, [noteName('meeting')]);
  });

  test('[FND-05/AC1] a resume with changed STT parameters restarts '
      'transcription and replaces stale segments', () async {
    final run1 = _Harness(db, paths, stt: ScriptedStt(blockOn: 2));
    final o1 = await run1.start();
    final id = expectOk(await o1.enqueue('r1'));
    await until(() => run1.stt.blocked);
    await o1.dispose();

    final run2 = _Harness(db, paths);
    final o2 = await run2.start(
      config: const PipelineConfig(sttModelId: 'ggml-small'),
    );
    await o2.whenIdle();
    expect(run2.stt.calls, hasLength(3));
    final t = expectOk(await db.transcriptsRepository.latestFor('r1'))!;
    expect(t.modelId, 'ggml-small');
    expect(
      expectOk(await db.transcriptsRepository.segments(t.id)),
      hasLength(3),
    );
    expect((await loadJob(db, id)).state, JobState.done);
  });

  test('[FND-05/AC2] re-running extraction with another profile reuses the '
      'transcript and never calls STT', () async {
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect(h.stt.calls, hasLength(3));
    final transcriptBefore = expectOk(
      await db.transcriptsRepository.segments(transcriptIdFor(id)),
    );

    h.llm.output = '{"summary":"eng"}';
    expectOk(
      await o.rerun(id, PipelineStepId.extract, profileId: 'engineering'),
    );
    await o.whenIdle();

    expect(h.stt.calls, hasLength(3), reason: 'STT must not run again');
    expect(h.llm.requests, hasLength(2));
    expect(h.llm.requests.last.prompt, contains('engineering'));
    expect(h.llm.requests.last.prompt, contains('chunk_2'));
    final ext = expectOk(
      await db.extractionsRepository.get(extractionIdFor(id)),
    );
    expect(ext.profileId, 'engineering');
    expect(ext.json, {'summary': 'eng'});
    expect(
      expectOk(await db.recordingsRepository.get('r1')).profileId,
      'engineering',
    );
    expect(
      expectOk(await db.transcriptsRepository.segments(transcriptIdFor(id))),
      hasLength(transcriptBefore.length),
    );
    expect((await loadJob(db, id)).state, JobState.done);
    expect(h.statesOf(id).sublist(9), [
      JobState.transcribed,
      JobState.extracting,
      JobState.extracted,
      JobState.rendering,
      JobState.rendered,
      JobState.writing,
      JobState.done,
    ]);
    // Re-rendering the same note: the vault is written again only if the
    // content changed; the export row is updated, never duplicated.
    expect(await db.select(db.exports).get(), hasLength(1));
    // Stable identity (EXP-02): the re-export updates the same file even
    // though the profile in the filename pattern changed.
    expect(h.vault.notes.keys, [noteName('meeting')]);
    expect(h.vault.notes[noteName('meeting')], contains('eng'));

    // Re-write only: unchanged content is not written to the vault again
    // (a sentinel in the existing file survives).
    h.vault.notes[noteName('meeting')] = 'sentinel';
    expectOk(await o.rerun(id, PipelineStepId.write));
    await o.whenIdle();
    expect(h.vault.notes, {noteName('meeting'): 'sentinel'});
    expect((await loadJob(db, id)).state, JobState.done);
  });

  test('[FND-05/AC2] rerun guards', () async {
    await seedRecordingWithChunks(db, 'r2', chunks: 1);
    final o = await h.start(run: false);
    final id = expectOk(await o.enqueue('r2'));
    expect(
      (await o.rerun(id, PipelineStepId.extract)).failureOrNull,
      isA<StorageFailure>(),
      reason: 'no transcript to re-extract from',
    );
    expect(
      (await o.rerun(id, PipelineStepId.diarize)).failureOrNull,
      isA<UnexpectedFailure>(),
      reason: 'step not configured',
    );
    expect(
      (await o.rerun('nope', PipelineStepId.extract)).failureOrNull,
      isA<StorageFailure>(),
    );
    // Re-transcribe is always allowed.
    expectOk(await o.rerun(id, PipelineStepId.transcribe));
  });

  test('[FND-05/AC3] transient failures retry with backoff, then fail; '
      'manual retry recovers', () async {
    h.llm.failures.addAll(List.filled(4, const OutOfMemoryFailure()));
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();

    var job = await loadJob(db, id);
    expect(job.state, JobState.transcribed);
    expect(job.step, PipelineStepId.extract);
    expect(job.failureKind, FailureKind.retryable);
    expect(job.errorDetail, 'OutOfMemoryFailure');
    expect(job.notBefore, t0.add(const Duration(seconds: 30)));

    // Not before the backoff has elapsed.
    o.poke();
    await o.whenIdle();
    expect(h.llm.requests, hasLength(1));

    for (final wait in const [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
    ]) {
      h.clock.advance(wait);
      o.poke();
      await o.whenIdle();
    }
    job = await loadJob(db, id);
    expect(job.state, JobState.failed);
    expect(job.attempts, 4);
    expect(h.llm.requests, hasLength(4));
    expect(h.stt.calls, hasLength(3), reason: 'retries resume at extract');

    expectOk(await o.retry(id));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
  });

  test('[FND-05/AC3] a failing model release (STT→LLM switch) is retried '
      'with backoff; the worker stays alive and runs the next job', () async {
    await seedRecordingWithChunks(db, 'r2', chunks: 1);
    var failing = true;
    h.onRelease = (m) async {
      if (failing && m == HeavyModel.stt) {
        failing = false;
        throw StateError('release failed');
      }
    };
    final o = await h.start();
    final id1 = expectOk(await o.enqueue('r1'));
    h.clock.advance(const Duration(seconds: 1));
    final id2 = expectOk(await o.enqueue('r2'));
    await o.whenIdle().timeout(const Duration(seconds: 5));

    var job1 = await loadJob(db, id1);
    expect(job1.state, JobState.transcribed, reason: 'not stranded');
    expect(job1.step, PipelineStepId.extract);
    expect(job1.failureKind, FailureKind.retryable);
    expect(job1.errorDetail, 'ModelSwitchFailure');
    expect(job1.notBefore, h.clock.now().add(const Duration(seconds: 30)));
    expect(
      (await loadJob(db, id2)).state,
      JobState.done,
      reason: 'the worker loop survived and processed the next job',
    );
    expect(h.llm.requests, hasLength(1), reason: 'only job 2 extracted');

    h.clock.advance(const Duration(seconds: 30));
    o.poke();
    await o.whenIdle().timeout(const Duration(seconds: 5));
    job1 = await loadJob(db, id1);
    expect(job1.state, JobState.done);
    expect(h.stt.calls, hasLength(4), reason: 'retry resumed at extract');
  });

  test('[FND-05/AC3] a release that keeps failing ends in failed(retryable) '
      'and the STT model is not considered unloaded', () async {
    h.onRelease = (m) async {
      if (m == HeavyModel.stt) throw StateError('release failed');
    };
    final gateSeen = <HeavyModel?>[];
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle().timeout(const Duration(seconds: 5));
    gateSeen.add(o.gate.loaded);
    for (final wait in const [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
    ]) {
      h.clock.advance(wait);
      o.poke();
      await o.whenIdle().timeout(const Duration(seconds: 5));
    }
    final job = await loadJob(db, id);
    expect(job.state, JobState.failed);
    expect(job.failureKind, FailureKind.retryable);
    expect(job.attempts, 4);
    expect(h.llm.requests, isEmpty, reason: 'LLM never ran beside STT');
    expect(gateSeen, [HeavyModel.stt]);
  });

  test('[FND-05/AC3] a failing release while the queue is idle does not '
      'stop the worker', () async {
    h.onRelease = (_) async => throw StateError('release failed');
    final o = await h.start();
    final id1 = expectOk(await o.enqueue('r1'));
    await o.whenIdle().timeout(const Duration(seconds: 5));
    await seedRecordingWithChunks(db, 'r2', chunks: 1);
    final id2 = expectOk(await o.enqueue('r2'));
    await o.whenIdle().timeout(const Duration(seconds: 5));
    // Job 1 fails its switch to the LLM and is parked for retry; job 2 is
    // still picked up after the idle release threw.
    expect((await loadJob(db, id1)).failureKind, FailureKind.retryable);
    expect((await loadJob(db, id2)).state, isNot(JobState.queued));
  });

  test('[FND-05/AC3] permanent failures fail at once with a content-free '
      'detail', () async {
    h.stt.failures.add(const NativeFailure(-3, 'secret transcript text'));
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    final job = await loadJob(db, id);
    expect(job.state, JobState.failed);
    expect(job.failureKind, FailureKind.permanent);
    expect(job.errorDetail, 'NativeFailure');
    expect(h.stt.calls, hasLength(1));
  });

  test('[FND-05/AC3] cancelling a running step stops it and wins over the '
      'step result; the job can be retried', () async {
    h.stt.blockOn = 1;
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await until(() => h.stt.blocked);
    expectOk(await o.cancel(id));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.cancelled);
    expect(h.llm.requests, isEmpty);
    expect(
      (await o.cancel(id)).failureOrNull,
      isA<UnexpectedFailure>(),
      reason: 'already cancelled',
    );

    expectOk(await o.retry(id));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
  });

  test('[FND-05/AC3] a step finishing after cancel has its outputs '
      'discarded', () async {
    h.llm
      ..blockOn = 0
      ..ignoreCancel = true;
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await until(() => h.llm.blocked);
    expectOk(await o.cancel(id));
    h.llm.release.complete();
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.cancelled);
    expect(
      await db.extractionsRepository.get(extractionIdFor(id)),
      isA<Err<ExtractionRow>>(),
    );
  });

  test('[FND-05/AC3] pause interrupts, resume continues from the '
      'checkpoint', () async {
    h.stt.blockOn = 1;
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await until(() => h.stt.blocked);
    expectOk(await o.pause(id));
    await o.whenIdle();
    final paused = await loadJob(db, id);
    expect(paused.state, JobState.paused);
    expect(paused.checkpoint['nextChunk'], 1);
    expect((await o.resume(id)).isOk, isTrue);
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
    expect(h.stt.calls, hasLength(4)); // chunk 1 re-run once, chunk 0 not
    expect((await o.resume(id)).failureOrNull, isA<UnexpectedFailure>());
  });

  test('[FND-05/AC3] waiting(destination) and waiting(modelMissing) resume '
      'once resolved', () async {
    await db.vaultRepository.deleteTarget('v1');
    final o = await h.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    var job = await loadJob(db, id);
    expect(job.state, JobState.waiting);
    expect(job.waitingReason, WaitingReason.destination);
    expect(job.step, PipelineStepId.write);

    await seedVaultTarget(db);
    expectOk(await o.resolveWaiting(id));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);

    await seedRecordingWithChunks(db, 'r2', chunks: 1);
    h.stt.failures.add(const ModelMissingFailure('ggml-base'));
    final id2 = expectOk(await o.enqueue('r2'));
    await o.whenIdle();
    job = await loadJob(db, id2);
    expect(job.state, JobState.waiting);
    expect(job.waitingReason, WaitingReason.modelMissing);
    expectOk(await o.resolveWaiting(id2));
    await o.whenIdle();
    expect((await loadJob(db, id2)).state, JobState.done);
  });

  test(
    '[FND-05/AC3] bad input fails permanently; unknown ids are errors',
    () async {
      await seedRecording(db, 'empty'); // no audio chunks
      final o = await h.start();
      final id = expectOk(await o.enqueue('empty'));
      await o.whenIdle();
      final job = await loadJob(db, id);
      expect(job.state, JobState.failed);
      expect(job.failureKind, FailureKind.permanent);

      expect((await o.enqueue('missing')).failureOrNull, isA<StorageFailure>());
      expect((await o.enqueue('r1', profileId: 'p')).isOk, isTrue);
      expect((await o.cancel('missing')).failureOrNull, isA<StorageFailure>());
      expect((await o.pause(id)).failureOrNull, isA<UnexpectedFailure>());
    },
  );

  group('custom steps', () {
    test('disabled steps are skipped; thrown errors and failing commits are '
        'classified', () async {
      final o = PipelineOrchestrator(
        db: db,
        clock: h.clock,
        newId: sequentialIds(),
        steps: [
          _TestStep(PipelineStepId.transcribe),
          _TestStep(PipelineStepId.diarize, enabled: false),
          _TestStep(
            PipelineStepId.extract,
            result: () => throw StateError('boom'),
          ),
        ],
      );
      addTearDown(o.dispose);
      await o.start();
      final id = expectOk(await o.enqueue('r1'));
      await o.whenIdle();
      var job = await loadJob(db, id);
      expect(job.state, JobState.failed);
      expect(job.step, PipelineStepId.extract);
      expect(job.errorDetail, 'UnexpectedFailure');

      final o2 = PipelineOrchestrator(
        db: db,
        clock: h.clock,
        newId: () => 'k1',
        steps: [
          _TestStep(
            PipelineStepId.transcribe,
            result: () => StepSucceeded(
              commit: () async => throw const StepAbort(StorageFailure('io')),
            ),
          ),
        ],
      );
      addTearDown(o2.dispose);
      await o2.start();
      await seedRecording(db, 'r3');
      expectOk(await o2.enqueue('r3'));
      await o2.whenIdle();
      job = await loadJob(db, 'k1');
      expect(job.state, JobState.queued);
      expect(job.failureKind, FailureKind.retryable);
      expect(job.notBefore, isNotNull);
    });

    test('[FND-05/AC3] an unexpected exception outside a step does not '
        'kill the worker loop', () async {
      final o = PipelineOrchestrator(
        db: db,
        clock: h.clock,
        newId: sequentialIds(),
        steps: [_TestStep(PipelineStepId.transcribe, canRunThrows: 1)],
      );
      addTearDown(o.dispose);
      await o.start();
      final id = expectOk(await o.enqueue('r1'));
      await o.whenIdle().timeout(const Duration(seconds: 5));
      expect((await loadJob(db, id)).state, JobState.done);
    });

    test('an orchestrator without steps refuses to enqueue', () async {
      final o = PipelineOrchestrator(db: db, steps: const []);
      addTearDown(o.dispose);
      expect((await o.enqueue('r1')).failureOrNull, isA<UnexpectedFailure>());
      await o.dispose();
      await o.whenIdle(); // completes immediately once stopped
    });
  });
}

class _TestStep implements PipelineStep {
  _TestStep(
    this.id, {
    this.enabled = true,
    StepResult Function()? result,
    this.canRunThrows = 0,
  }) : _result = result ?? (() => const StepSucceeded());

  @override
  final PipelineStepId id;
  final bool enabled;

  /// The first [canRunThrows] calls of [canRun] throw (a bug outside the
  /// step's run, i.e. outside the orchestrator's step try/catch).
  int canRunThrows;
  final StepResult Function() _result;

  @override
  HeavyModel? get model => null;

  @override
  bool canRun(JobSnapshot job) {
    if (canRunThrows > 0) {
      canRunThrows--;
      throw StateError('canRun bug');
    }
    return enabled;
  }

  @override
  Future<StepResult> run(StepContext ctx) async => _result();
}
