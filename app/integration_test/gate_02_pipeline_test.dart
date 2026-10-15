import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/step_support.dart';
import 'package:vaultvoice/features/pipeline/domain/heavy_model_gate.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';

import '../test/db/db_test_utils.dart';
import '../test/fakes/fake_clock.dart';
import '../test/fakes/fake_vault_writer.dart';
import '../test/unit/pipeline/pipeline_test_utils.dart';

/// GATE-02 automatable half (docs/test-plans/gates/GATE-02.md): the job
/// pipeline with scripted engines (the real tiny-model run is
/// `production_pipeline_test.dart`, row GATE-02/AC1 in
/// docs/test-plans/device/GATE-02.md). A session is one "app launch"; the
/// database file survives [_Session.kill].
///   cd app && fvm flutter test integration_test/gate_02_pipeline_test.dart
class _Session {
  _Session(this.file, this.paths, {ScriptedStt? stt, ScriptedLlm? llm})
    : stt = stt ?? ScriptedStt(),
      llm = llm ?? ScriptedLlm() {
    db = VaultVoiceDatabase(NativeDatabase(file));
  }

  final File file;
  final StoragePaths paths;
  final ScriptedStt stt;
  final ScriptedLlm llm;
  final vault = FakeVaultWriter();
  final released = <HeavyModel>[];
  late final VaultVoiceDatabase db;
  late final PipelineOrchestrator o;

  Future<void> launch() async {
    o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: stt,
        llm: llm,
        vault: vault,
        clock: FakeClock(t0),
        gate: HeavyModelGate(release: (m) async => released.add(m)),
      ),
      newId: sequentialIds(),
    );
    await o.start();
  }

  /// "Force-kill": the worker stops, the database file is what remains.
  Future<void> kill() async {
    await o.dispose();
    await db.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late File dbFile;
  late StoragePaths paths;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vv_gate02_');
    addTearDown(() => dir.deleteSync(recursive: true));
    dbFile = File('${dir.path}/vaultvoice.sqlite');
    paths = StoragePaths('${dir.path}/vv');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Future<List<String>> segmentBodies(VaultVoiceDatabase db, String job) async =>
      [
        for (final s in expectOk(
          await db.transcriptsRepository.segments(transcriptIdFor(job)),
        ))
          s.body,
      ];

  testWidgets('[GATE-02/AC1] a 30 min recording becomes a transcript and '
      'schema-valid JSON, one heavy model at a time', (tester) async {
    await tester.runAsync(() async {
      final s = _Session(dbFile, paths);
      addTearDown(s.db.close);
      await seedRecordingWithChunks(s.db, 'r1', chunks: 60); // 60 × 30 s
      await seedVaultTarget(s.db);
      await s.launch();
      final job = expectOk(await s.o.enqueue('r1'));
      await s.o.whenIdle();

      expect((await loadJob(s.db, job)).state, JobState.done);
      expect(await segmentBodies(s.db, job), [
        for (var i = 0; i < 60; i++) 'chunk_$i',
      ]);
      final ext = expectOk(
        await s.db.extractionsRepository.get(extractionIdFor(job)),
      );
      expect(ext.valid, isTrue);
      expect(jsonDecode(jsonEncode(ext.json)), isA<Map<String, Object?>>());
      expect(s.released, [HeavyModel.stt, HeavyModel.llm]);
      expect(s.o.gate.loaded, isNull);
    });
  });

  testWidgets('[GATE-02/AC2] a kill during transcription resumes with no '
      'duplicate segments', (tester) async {
    await tester.runAsync(() async {
      final run1 = _Session(dbFile, paths, stt: ScriptedStt(blockOn: 2));
      await seedRecordingWithChunks(run1.db, 'r1', chunks: 5);
      await seedVaultTarget(run1.db);
      await run1.launch();
      final job = expectOk(await run1.o.enqueue('r1'));
      await until(() => run1.stt.blocked);
      await run1.kill();

      final run2 = _Session(dbFile, paths);
      addTearDown(run2.db.close);
      await run2.launch();
      await run2.o.whenIdle();
      expect((await loadJob(run2.db, job)).state, JobState.done);
      expect(await segmentBodies(run2.db, job), [
        for (var i = 0; i < 5; i++) 'chunk_$i',
      ]);
      expect(run2.stt.calls, hasLength(3), reason: 'only chunks 2..4 re-run');
      expect(run2.vault.notes, hasLength(1));
    });
  });

  testWidgets('[GATE-02/AC2] a kill during extraction resumes without '
      'transcribing again or duplicating segments', (tester) async {
    await tester.runAsync(() async {
      final run1 = _Session(dbFile, paths, llm: ScriptedLlm()..blockOn = 0);
      await seedRecordingWithChunks(run1.db, 'r1');
      await seedVaultTarget(run1.db);
      await run1.launch();
      final job = expectOk(await run1.o.enqueue('r1'));
      await until(() => run1.llm.blocked);
      await run1.kill();

      final run2 = _Session(dbFile, paths);
      addTearDown(run2.db.close);
      await run2.launch();
      await run2.o.whenIdle();
      expect((await loadJob(run2.db, job)).state, JobState.done);
      expect(run2.stt.calls, isEmpty, reason: 'transcript was kept');
      expect(await segmentBodies(run2.db, job), [
        'chunk_0',
        'chunk_1',
        'chunk_2',
      ]);
      expect(run2.llm.requests, hasLength(1));
      expect(
        expectOk(await run2.db.extractionsRepository.get(extractionIdFor(job)))
            .valid,
        isTrue,
      );
    });
  });

  testWidgets('[GATE-02/AC3] the whole pipeline run opens no network '
      'connection (airplane mode)', (tester) async {
    await tester.runAsync(() async {
      final attempts = <String>[];
      await HttpOverrides.runZoned(
        () async {
          final s = _Session(dbFile, paths);
          addTearDown(s.db.close);
          await seedRecordingWithChunks(s.db, 'r1');
          await seedVaultTarget(s.db);
          await s.launch();
          final job = expectOk(await s.o.enqueue('r1'));
          await s.o.whenIdle();
          expect((await loadJob(s.db, job)).state, JobState.done);
        },
        createHttpClient: (c) {
          attempts.add('HttpClient');
          throw const SocketException('offline');
        },
      );
      expect(attempts, isEmpty);
    });
  });
}
