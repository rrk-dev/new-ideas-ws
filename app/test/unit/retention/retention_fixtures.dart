import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';

import '../../db/db_test_utils.dart';

/// Sensitive marker text written into every content-bearing place.
String secretFor(String id) => 'Confidential merger notes for $id';

/// Seeds recording [id] everywhere the app stores something about it: rows
/// in every child table, audio chunk files, a
/// work directory and the rendered note. Returns the job id.
Future<String> seedFullRecording(
  VaultVoiceDatabase db,
  StoragePaths paths,
  String id, {
  DateTime? createdAt,
  String jobStatus = 'done',
  bool exported = true,
  RecordingStatus status = RecordingStatus.recorded,
}) async {
  final secret = secretFor(id);
  final jobId = 'job-$id';
  await seedRecording(db, id, createdAt: createdAt, status: status);
  for (final seq in [0, 1]) {
    final rel = p.join('audio', id, 'chunk_$seq.wav');
    File(paths.resolve(rel))
      ..createSync(recursive: true)
      ..writeAsStringSync('RIFF$secret');
    await db
        .into(db.audioChunks)
        .insert(
          AudioChunksCompanion.insert(
            recordingId: id,
            seq: seq,
            path: rel,
            sampleRate: 16000,
            startMs: seq * 1000,
            endMs: seq * 1000 + 1000,
            bytes: 100,
          ),
        );
  }
  await db
      .into(db.speechSegments)
      .insert(
        SpeechSegmentsCompanion.insert(recordingId: id, startMs: 0, endMs: 9),
      );
  await db
      .into(db.markers)
      .insert(
        MarkersCompanion.insert(
          recordingId: id,
          atMs: 5,
          kind: MarkerKind.user,
        ),
      );
  await db
      .into(db.speakers)
      .insert(SpeakersCompanion.insert(recordingId: id, label: 'Speaker 1'));
  await db
      .into(db.transcripts)
      .insert(
        TranscriptsCompanion.insert(
          id: 'tr-$id',
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
          transcriptId: 'tr-$id',
          seq: 0,
          startMs: 0,
          endMs: 900,
          body: secret,
        ),
      );
  await db
      .into(db.jobs)
      .insert(
        JobsCompanion.insert(
          id: jobId,
          recordingId: id,
          kind: 'process',
          step: 'write',
          status: jobStatus,
          createdAt: t0,
          updatedAt: t0,
        ),
      );
  File(p.join(paths.workDir(jobId), 'prompt.txt'))
    ..createSync(recursive: true)
    ..writeAsStringSync(secret);
  await db
      .into(db.extractions)
      .insert(
        ExtractionsCompanion.insert(
          id: 'ex-$id',
          recordingId: id,
          profileId: 'meeting',
          profileVersion: 1,
          modelId: 'llm',
          json: {'summary': secret},
          valid: true,
          createdAt: t0,
        ),
      );
  await db
      .into(db.actionItems)
      .insert(
        ActionItemsCompanion.insert(
          recordingId: id,
          extractionId: 'ex-$id',
          body: secret,
        ),
      );
  await db
      .into(db.mindMaps)
      .insert(
        MindMapsCompanion.insert(
          id: '$id.mindmap',
          recordingId: id,
          method: 'projection',
          json: {'id': 'n0', 'label': secret, 'children': <Object?>[]},
          nodeCount: 1,
          createdAt: t0,
        ),
      );
  await db
      .into(db.reminderExports)
      .insert(
        ReminderExportsCompanion.insert(
          itemKey: 'key-$id',
          recordingId: id,
          calendarItemId: 'cal-$id',
          reminderCalendarId: 'list-$id',
          exportedAt: t0,
        ),
      );
  await db
      .into(db.vaultTargets)
      .insertOnConflictUpdate(
        VaultTargetsCompanion.insert(
          id: 'v1',
          platform: VaultPlatform.androidSaf,
          displayName: 'Vault',
          handle: 'content://tree/vault',
          createdAt: t0,
        ),
      );
  await db
      .into(db.exports)
      .insert(
        ExportsCompanion.insert(
          id: 'exp-$id',
          recordingId: id,
          targetId: 'v1',
          relPath: '$id.md',
          contentHash: 'h',
          status: exported ? ExportStatus.written : ExportStatus.pending,
          updatedAt: t0,
        ),
      );
  await db
      .into(db.askThreads)
      .insert(
        AskThreadsCompanion.insert(
          id: 'ask-$id',
          recordingId: Value(id),
          createdAt: t0,
          updatedAt: t0,
        ),
      );
  await db
      .into(db.askTurns)
      .insert(
        AskTurnsCompanion.insert(
          id: 'turn-$id',
          threadId: 'ask-$id',
          seq: 0,
          question: 'What was said? $secret',
          answer: secret,
          found: true,
          createdAt: t0,
        ),
      );
  await db
      .into(db.askCitations)
      .insert(
        AskCitationsCompanion.insert(
          turnId: 'turn-$id',
          recordingId: id,
          tMs: 1000,
        ),
      );
  File(paths.renderedFile(id))
    ..createSync(recursive: true)
    ..writeAsStringSync('# $secret');
  return jobId;
}

/// Creates the APP-02 FTS5 table as specified in `vv-local-database`.
Future<void> createSearchIndex(VaultVoiceDatabase db) => db.customStatement(
  'CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5( '
  'recording_id UNINDEXED, kind UNINDEXED, body, '
  "tokenize='unicode61 remove_diacritics 2')",
);

Future<void> indexRecording(VaultVoiceDatabase db, String id) =>
    db.customStatement(
      'INSERT INTO search_index (recording_id, kind, body) VALUES (?, ?, ?)',
      [id, 'transcript', secretFor(id)],
    );

/// Every table that has a `recording_id` column → rows referencing [id].
Future<Map<String, int>> rowsReferencing(
  VaultVoiceDatabase db,
  String id,
) async {
  final out = <String, int>{};
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'search_index_%'",
      )
      .get();
  for (final t in tables) {
    final name = t.read<String>('name');
    final cols = await db.customSelect('PRAGMA table_info("$name")').get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    final column = names.contains('recording_id')
        ? 'recording_id'
        : name == 'recordings'
        ? 'id'
        : null;
    if (column == null) continue;
    final n = await db
        .customSelect(
          'SELECT count(*) AS n FROM "$name" WHERE $column = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    out[name] = n.read<int>('n');
  }
  return out;
}

/// All files under [root] (relative paths).
List<String> filesUnder(String root) {
  final d = Directory(root);
  if (!d.existsSync()) return const [];
  return [
    for (final f in d.listSync(recursive: true).whereType<File>())
      p.relative(f.path, from: root),
  ]..sort();
}
