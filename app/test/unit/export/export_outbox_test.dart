import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/export_outbox.dart';
import 'package:vaultvoice/features/export/domain/pending_export.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_vault_writer.dart';
import '../pipeline/pipeline_test_utils.dart';

/// Picker that returns [next] (null = cancelled) and records releases.
class _Folders implements VaultFolderAccess {
  VaultFolder? next;
  final picks = <VaultFolder?>[];
  final released = <String>[];

  @override
  Future<Result<VaultFolder?>> pick({VaultFolder? previous}) async {
    picks.add(previous);
    return Ok(next);
  }

  @override
  Future<VaultAccess> checkAccess(VaultFolder folder) async => VaultAccess.ok;

  @override
  VaultWriter writerFor(VaultFolder folder) => throw UnimplementedError();

  @override
  Future<void> release(VaultFolder folder) async => released.add(folder.handle);
}

void main() {
  late VaultVoiceDatabase db;
  late StoragePaths paths;
  late Map<String, FakeVaultWriter> byHandle;
  late FakeVaultWriter appLocal;
  late _Folders folders;
  late PipelineOrchestrator o;
  late ExportOutbox outbox;
  final clock = FakeClock(t0);

  FakeVaultWriter writer(String handle) =>
      byHandle.putIfAbsent(handle, FakeVaultWriter.new);

  Future<void> start() async {
    o = PipelineOrchestrator.withEngines(
      db: db,
      paths: paths,
      engines: PipelineEngines(
        stt: ScriptedStt(),
        llm: ScriptedLlm(),
        vault: FakeVaultWriter(),
        clock: clock,
        // Writers are keyed by handle: a re-grant to another folder gets a
        // different writer, like a different SAF tree / bookmark.
        vaultResolver: (t) =>
            t.platform == VaultPlatform.appLocal ? appLocal : writer(t.handle),
      ),
      newId: sequentialIds(),
    );
    addTearDown(o.dispose);
    await o.start();
    outbox = ExportOutbox(
      db: db,
      client: () async => o,
      folders: folders,
      writerFor: (t) =>
          t.platform == VaultPlatform.appLocal ? appLocal : writer(t.handle),
      clock: clock,
    );
  }

  Future<JobSnapshot> process(String recordingId) async {
    final id = expectOk(await o.enqueue(recordingId));
    await o.whenIdle();
    return await loadJob(db, id);
  }

  int notesIn(FakeVaultWriter w) =>
      w.notes.keys.where((k) => !k.contains('/attachments/')).length;

  setUp(() async {
    db = memoryDb();
    paths = tempPaths();
    byHandle = {};
    appLocal = FakeVaultWriter();
    folders = _Folders();
    await seedRecordingWithChunks(db, 'r1');
    await start();
  });

  test('[EXP-06/AC1] revoking folder permission, then re-granting, results '
      'in exactly one note per recording', () async {
    await seedVaultTarget(db, 'v'); // handle content://tree/v
    writer('content://tree/v').access = VaultAccess.revoked;

    final waiting = await process('r1');
    expect(waiting.state, JobState.waiting);
    expect(waiting.waitingReason, WaitingReason.destination);
    final pending = await outbox.snapshot();
    expect(pending.single.reason, PendingReason.accessRevoked);
    expect(pending.single.targetId, 'v');
    // The note is safe in app storage meanwhile.
    expect(await paths.renderedFileExists('r1'), isTrue);

    // User re-grants the same folder.
    writer('content://tree/v').access = VaultAccess.ok;
    folders.next = const VaultFolder(
      kind: VaultTargetKind.saf,
      handle: 'content://tree/v',
      displayName: 'Vault',
    );
    expect(expectOk(await outbox.regrant('v')), isTrue);
    expect(folders.picks.single?.handle, 'content://tree/v');
    await o.whenIdle();

    expect((await loadJob(db, waiting.id)).state, JobState.done);
    expect(notesIn(writer('content://tree/v')), 1);
    expect(await outbox.snapshot(), isEmpty);

    // Revoke again and re-export (e.g. re-render): still exactly one note.
    writer('content://tree/v').access = VaultAccess.revoked;
    expectOk(await o.rerun(waiting.id, PipelineStepId.render));
    await o.whenIdle();
    expect(
      (await outbox.snapshot()).single.reason,
      PendingReason.accessRevoked,
    );
    writer('content://tree/v').access = VaultAccess.ok;
    expect(await outbox.recheck(), 1);
    await o.whenIdle();
    expect(notesIn(writer('content://tree/v')), 1);
    final row = (await db.select(db.exports).get()).single;
    expect(row.status, ExportStatus.written);
  });

  test('[EXP-06/AC1] re-granting a different folder writes the note there '
      'once and releases the old grant', () async {
    await seedVaultTarget(db, 'v');
    writer('content://tree/v').access = VaultAccess.revoked;
    final job = await process('r1');
    folders.next = const VaultFolder(
      kind: VaultTargetKind.saf,
      handle: 'content://tree/new',
      displayName: 'New vault',
    );
    expect(expectOk(await outbox.regrant('v', sameFolder: false)), isTrue);
    await o.whenIdle();
    expect((await loadJob(db, job.id)).state, JobState.done);
    expect(notesIn(writer('content://tree/new')), 1);
    expect(notesIn(writer('content://tree/v')), 0);
    expect(folders.released, ['content://tree/v']);
    final target = expectOk(await db.vaultRepository.getTarget('v'));
    expect(target.handle, 'content://tree/new');
    expect(target.displayName, 'New vault');
  });

  test('cancelled picker changes nothing', () async {
    await seedVaultTarget(db, 'v');
    writer('content://tree/v').access = VaultAccess.revoked;
    await process('r1');
    folders.next = null;
    expect(expectOk(await outbox.regrant('v')), isFalse);
    expect(
      (await outbox.snapshot()).single.reason,
      PendingReason.accessRevoked,
    );
  });

  test(
    'no folder: the job waits; "Save on this device" exports once',
    () async {
      final job = await process('r1');
      expect(job.waitingReason, WaitingReason.destination);
      expect(
        (await outbox.snapshot()).single.reason,
        PendingReason.noDestination,
      );
      expectOk(await outbox.saveOnDevice());
      await o.whenIdle();
      expect((await loadJob(db, job.id)).state, JobState.done);
      expect(notesIn(appLocal), 1);
      expect(
        expectOk(await db.vaultRepository.getTarget(kAppLocalTargetId))
            .platform,
        VaultPlatform.appLocal,
      );
      // Idempotent: a second call neither duplicates the target nor the note.
      expectOk(await outbox.saveOnDevice());
      await o.whenIdle();
      expect(notesIn(appLocal), 1);
      expect(await db.vaultRepository.watchTargets().first, hasLength(1));
    },
  );

  test('no folder: "Choose a folder" adds a target and exports', () async {
    final job = await process('r1');
    folders.next = const VaultFolder(
      kind: VaultTargetKind.saf,
      handle: 'content://tree/picked',
      displayName: 'Picked',
    );
    expect(expectOk(await outbox.addFolder()), isTrue);
    await o.whenIdle();
    expect((await loadJob(db, job.id)).state, JobState.done);
    expect(notesIn(writer('content://tree/picked')), 1);
  });

  test('unreachable storage / disk full: retried by the pipeline, shown as '
      'retrying; the note is never lost', () async {
    await seedVaultTarget(db, 'v');
    writer('content://tree/v').failWith(const StorageFailure('disk full'));
    final job = await process('r1');
    expect(job.state, isNot(JobState.done));
    expect(job.notBefore, isNotNull, reason: 'backoff retry scheduled');
    final p = (await outbox.snapshot()).single;
    expect(p.reason, PendingReason.retrying);
    expect(p.attempts, greaterThanOrEqualTo(1));
    expect(await paths.renderedFileExists('r1'), isTrue);
  });

  test('retry of a failed job and of a finished job', () async {
    await seedVaultTarget(db, 'v');
    final job = await process('r1');
    expect(job.state, JobState.done);
    // Pretend the export row failed after the job finished (e.g. the user
    // removed the note's folder and the outbox shows it): retry re-runs the
    // write step only.
    final row = (await db.select(db.exports).get()).single;
    expectOk(
      await db.vaultRepository.updateExport(
        row.id,
        const ExportsCompanion(status: Value(ExportStatus.failed)),
      ),
    );
    final p = (await outbox.snapshot()).single;
    expect(p.reason, PendingReason.failed);
    expectOk(await outbox.retry(p));
    await o.whenIdle();
    expect(await outbox.snapshot(), isEmpty);
    expect(notesIn(writer('content://tree/v')), 1);
  });

  test('the pending list streams changes', () async {
    final stream = outbox.watch();
    final first = await stream.first;
    expect(first, isEmpty);
    await process('r1');
    expect(await outbox.watch().firstWhere((l) => l.isNotEmpty), hasLength(1));
  });
}

extension on StoragePaths {
  Future<bool> renderedFileExists(String id) async =>
      File(renderedFile(id)).existsSync();
}
