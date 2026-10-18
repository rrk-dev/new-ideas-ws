import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/mindmap/data/mind_map_strategy.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_generator.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_vault_writer.dart';
import 'pipeline_test_utils.dart';

/// Blocks the first call until released (simulating a kill mid-step), then
/// answers a one-branch tree.
class _Strategy implements MindMapStrategy {
  _Strategy({this.block = false});

  bool block;
  MindMapNode? tree = const MindMapNode(
    id: 'n0',
    label: 'Root',
    children: [MindMapNode(id: 'n1', label: 'Branch')],
  );
  int calls = 0;
  bool blocked = false;

  @override
  Future<Result<MindMapResult>> generate(
    StepContext ctx,
    MindMapInput input,
  ) async {
    calls++;
    if (block) {
      blocked = true;
      while (!ctx.cancel.isCancelled) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      return const Err(CancelledFailure());
    }
    return Ok(
      MindMapResult(
        method: MindMapMethod.projection,
        tree: tree,
        schemaValid: true,
      ),
    );
  }
}

PipelineOrchestrator _orchestrator(
  VaultVoiceDatabase db,
  StoragePaths paths,
  MindMapStrategy? strategy,
) {
  final o = PipelineOrchestrator.withEngines(
    db: db,
    paths: paths,
    engines: PipelineEngines(
      stt: ScriptedStt(),
      llm: ScriptedLlm(),
      vault: FakeVaultWriter(),
      mindMap: strategy,
    ),
  );
  addTearDown(o.dispose);
  return o;
}

Future<int> _maps(VaultVoiceDatabase db) async =>
    (await db.select(db.mindMaps).get()).length;

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    await seedRecordingWithChunks(db, 'r1', chunks: 1);
    await seedVaultTarget(db);
  });

  test('on_demand (default): the step is skipped and nothing is stored, '
      'a request runs it', () async {
    final s = _Strategy();
    final o = _orchestrator(db, paths, s);
    await o.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
    expect(s.calls, 0);
    expect(await _maps(db), 0);

    expectOk(
      await db.settingsRepository.set(
        SettingKeys.mindMapRequestFor('r1'),
        true,
      ),
    );
    expectOk(await o.rerun(id, PipelineStepId.mindMap));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
    expect(s.calls, 1);
    expect(await _maps(db), 1);
    expect(
      expectOk(
        await db.settingsRepository.get(SettingKeys.mindMapRequestFor('r1')),
      ),
      isNull,
    );
  });

  test('auto mode runs the step for every recording and re-running keeps '
      'exactly one map', () async {
    expectOk(
      await db.settingsRepository.set(SettingKeys.processingMindMap, 'auto'),
    );
    final s = _Strategy();
    final o = _orchestrator(db, paths, s);
    await o.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect(s.calls, 1);
    expect(await _maps(db), 1);
    final row = expectOk(await db.mindMapsRepository.forRecording('r1'))!;
    expect(row.nodeCount, 2);
    expect(row.method, 'projection');

    expectOk(await o.rerun(id, PipelineStepId.mindMap));
    await o.whenIdle();
    expect(s.calls, 2);
    expect(await _maps(db), 1);
  });

  test('[MAP-01/AC2] a rejected tree is never stored and drops a stale '
      'one', () async {
    expectOk(
      await db.settingsRepository.set(SettingKeys.processingMindMap, 'auto'),
    );
    final s = _Strategy();
    final o = _orchestrator(db, paths, s);
    await o.start();
    final id = expectOk(await o.enqueue('r1'));
    await o.whenIdle();
    expect(await _maps(db), 1);

    s.tree = null;
    expectOk(await o.rerun(id, PipelineStepId.mindMap));
    await o.whenIdle();
    expect((await loadJob(db, id)).state, JobState.done);
    expect(await _maps(db), 0);
  });

  test('[MAP-01/AC4] killing the app mid-step leaves no map and the '
      'resumed step stores exactly one', () async {
    final dir = Directory.systemTemp.createTempSync('vv_map_kill_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/vaultvoice.sqlite');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final db1 = VaultVoiceDatabase(NativeDatabase(file));
    await seedRecordingWithChunks(db1, 'r1', chunks: 1);
    await seedVaultTarget(db1);
    expectOk(
      await db1.settingsRepository.set(SettingKeys.processingMindMap, 'auto'),
    );
    final hang = _Strategy(block: true);
    final o1 = _orchestrator(db1, paths, hang);
    await o1.start();
    final id = expectOk(await o1.enqueue('r1'));
    await until(() => hang.blocked);
    await o1.dispose();
    await db1.close();

    final db2 = VaultVoiceDatabase(NativeDatabase(file));
    addTearDown(db2.close);
    expect((await loadJob(db2, id)).state, JobState.mapping);
    expect(await _maps(db2), 0);

    final ok = _Strategy();
    final o2 = _orchestrator(db2, paths, ok);
    await o2.start();
    await o2.whenIdle();
    expect((await loadJob(db2, id)).state, JobState.done);
    expect(ok.calls, 1);
    expect(await _maps(db2), 1);
  });
}
