import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/library/data/recording_deleter.dart';
import 'package:vaultvoice/features/retention/data/recording_purger.dart';

import '../fakes/fake_vault_writer.dart';
import 'db_test_utils.dart';

void main() {
  late Directory tmp;
  late StoragePaths paths;
  late VaultVoiceDatabase db;
  late FakeVaultWriter vault;
  late List<String> stopped;
  late LocalRecordingDeleter deleter;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vv-app02-');
    paths = StoragePaths(tmp.path);
    db = memoryDb();
    vault = FakeVaultWriter();
    stopped = [];
    deleter = LocalRecordingDeleter(
      db: db,
      paths: paths,
      writerFor: (target) => target.id == 'v1' ? vault : null,
      stopJobs: (ids) async => stopped.addAll(ids),
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  /// A fully processed recording: audio chunk file, transcript, extraction,
  /// action item, job + work dir, rendered note, and an export to `v1`.
  Future<void> seedProcessed(String id, {String note = 'Notes/a.md'}) async {
    await seedRecording(db, id);
    final chunk = File(p.join(paths.audioDir(id), 'chunk_0000.wav'));
    await chunk.create(recursive: true);
    await chunk.writeAsBytes(List.filled(44, 0));
    await db.recordingsRepository.upsertChunk(
      AudioChunksCompanion.insert(
        recordingId: id,
        seq: 0,
        path: paths.relativize(chunk.path),
        sampleRate: 16000,
        startMs: 0,
        endMs: 1000,
        bytes: 44,
      ),
    );
    await db
        .into(db.transcripts)
        .insert(
          TranscriptsCompanion.insert(
            id: 't-$id',
            recordingId: id,
            modelId: 'm',
            language: 'en',
            createdAt: t0,
          ),
        );
    await db
        .into(db.transcriptSegments)
        .insert(
          TranscriptSegmentsCompanion.insert(
            transcriptId: 't-$id',
            seq: 0,
            startMs: 0,
            endMs: 900,
            body: 'secret budget',
          ),
        );
    await db
        .into(db.extractions)
        .insert(
          ExtractionsCompanion.insert(
            id: 'e-$id',
            recordingId: id,
            profileId: 'meeting',
            profileVersion: 1,
            modelId: 'm',
            json: const {'summary': 'secret plan'},
            valid: true,
            createdAt: t0,
          ),
        );
    await db
        .into(db.actionItems)
        .insert(
          ActionItemsCompanion.insert(
            recordingId: id,
            extractionId: 'e-$id',
            body: 'Do it',
          ),
        );
    await db
        .into(db.jobs)
        .insert(
          JobsCompanion.insert(
            id: 'j-$id',
            recordingId: id,
            kind: 'process',
            step: 'write',
            status: 'done',
            createdAt: t0,
            updatedAt: t0,
          ),
        );
    await Directory(paths.workDir('j-$id')).create(recursive: true);
    final rendered = File(paths.renderedFile(id));
    await rendered.create(recursive: true);
    await rendered.writeAsString('# note');
    await db.vaultRepository.upsertTarget(
      VaultTargetsCompanion.insert(
        id: 'v1',
        platform: VaultPlatform.appLocal,
        displayName: 'Vault',
        handle: '/vault',
        createdAt: t0,
      ),
    );
    await db.vaultRepository.upsertExport(
      ExportsCompanion.insert(
        id: '$id.v1',
        recordingId: id,
        targetId: 'v1',
        relPath: note,
        contentHash: 'h',
        status: ExportStatus.written,
        updatedAt: t0,
      ),
    );
    await vault.write(NoteDraft(relativePath: note, markdown: '# note'));
  }

  Future<int> rowsFor(String id) async {
    var n = 0;
    for (final table in [
      'recordings',
      'audio_chunks',
      'transcripts',
      'extractions',
      'action_items',
      'jobs',
      'exports',
    ]) {
      final column = table == 'recordings' ? 'id' : 'recording_id';
      n +=
          (await db
                  .customSelect(
                    'SELECT count(*) AS n FROM $table WHERE $column = ?',
                    variables: [Variable(id)],
                  )
                  .getSingle())
              .read<int>('n');
    }
    n +=
        (await db
                .customSelect(
                  'SELECT count(*) AS n FROM transcript_segments '
                  "WHERE transcript_id = 't-$id'",
                )
                .getSingle())
            .read<int>('n');
    n +=
        (await db
                .customSelect(
                  'SELECT count(*) AS n FROM search_index '
                  'WHERE recording_id = ?',
                  variables: [Variable(id)],
                )
                .getSingle())
            .read<int>('n');
    return n;
  }

  bool anyFileFor(String id) =>
      Directory(paths.audioDir(id)).existsSync() ||
      Directory(paths.workDir('j-$id')).existsSync() ||
      File(paths.renderedFile(id)).existsSync();

  test('[APP-02/AC2] deleting removes audio, transcript, DB rows and the '
      'search entries; the exported note goes only when asked', () async {
    await seedProcessed('r1');
    await seedProcessed('r2', note: 'Notes/b.md');
    expect(await rowsFor('r1'), greaterThan(8));
    expect(anyFileFor('r1'), isTrue);

    final kept = expectOk(
      await deleter.delete('r1', deleteExportedNotes: false),
    );
    expect(kept.notesDeleted, 0);
    expect(kept.notesKept, 1);
    expect(vault.notes.containsKey('Notes/a.md'), isTrue);
    expect(await rowsFor('r1'), 0);
    expect(anyFileFor('r1'), isFalse);
    expect(stopped, ['j-r1'], reason: 'its jobs are cancelled first');

    final gone = expectOk(
      await deleter.delete('r2', deleteExportedNotes: true),
    );
    expect(gone.notesDeleted, 1);
    expect(gone.notesKept, 0);
    expect(vault.notes.containsKey('Notes/b.md'), isFalse);
    expect(await rowsFor('r2'), 0);
    expect(anyFileFor('r2'), isFalse);
    // The vault target itself stays.
    expect(await db.select(db.vaultTargets).get(), hasLength(1));
  });

  test('[APP-02/AC2] an unreachable vault folder keeps the note and says '
      'so; the recording is still deleted', () async {
    await seedProcessed('r1');
    vault.access = VaultAccess.revoked;
    final r = expectOk(await deleter.delete('r1', deleteExportedNotes: true));
    expect(r.notesDeleted, 0);
    expect(r.notesKept, 1);
    expect(await rowsFor('r1'), 0);
  });

  test('integration W3 (APP-02 ↔ SEC-04): with the secure purger the same '
      'deletion leaves no rows, FTS entries or files; the exported-note '
      'step still runs first', () async {
    final secure = LocalRecordingDeleter(
      db: db,
      paths: paths,
      writerFor: (target) => target.id == 'v1' ? vault : null,
      stopJobs: (ids) async => stopped.addAll(ids),
      purger: RecordingPurger(db, paths),
    );
    await seedProcessed('r1');
    await seedProcessed('r2', note: 'Notes/b.md');
    final r = expectOk(await secure.delete('r1', deleteExportedNotes: true));
    expect(r.notesDeleted, 1);
    expect(vault.notes.containsKey('Notes/a.md'), isFalse);
    expect(await rowsFor('r1'), 0);
    expect(anyFileFor('r1'), isFalse);
    expect(stopped, ['j-r1']);
    expect(await rowsFor('r2'), greaterThan(8), reason: 'r2 untouched');
    expect(anyFileFor('r2'), isTrue);
  });

  test('integration W3: the secure deleter retries while a cancelled step '
      'is still running, then reports the failure', () async {
    await seedProcessed('r1');
    await (db.update(db.jobs)..where((j) => j.id.equals('j-r1'))).write(
      const JobsCompanion(status: Value('transcribing')),
    );
    final secure = LocalRecordingDeleter(
      db: db,
      paths: paths,
      writerFor: (target) => vault,
      stopJobs: (ids) async {},
      purger: RecordingPurger(db, paths),
      retryDelay: Duration.zero,
    );
    final r = await secure.delete('r1', deleteExportedNotes: false);
    expect(r.isOk, isFalse);
    expect(await rowsFor('r1'), greaterThan(0), reason: 'nothing deleted');
  });
}
