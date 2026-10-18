import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/security/sqlite3mc_cipher.dart';
import 'package:vaultvoice/features/retention/data/recording_purger.dart';

import '../../db/db_test_utils.dart';
import 'retention_fixtures.dart';

bool _contains(List<int> haystack, String needle) {
  final n = utf8.encode(needle);
  outer:
  for (var i = 0; i + n.length <= haystack.length; i++) {
    for (var j = 0; j < n.length; j++) {
      if (haystack[i + j] != n[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  late Directory tmp;
  late StoragePaths paths;
  late VaultVoiceDatabase db;
  late RecordingPurger purger;

  VaultVoiceDatabase open(DatabaseCipher cipher) =>
      VaultVoiceDatabase(openDatabaseFile(File(paths.dbFile), cipher: cipher));

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tmp = Directory.systemTemp.createTempSync('vv_sec04_');
    paths = StoragePaths(p.join(tmp.path, 'vv'));
    db = open(Sqlite3mcCipher(Uint8List(32)));
    purger = RecordingPurger(db, paths);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('connections run with PRAGMA secure_delete = ON', () async {
    final row = await db.customSelect('PRAGMA secure_delete').getSingle();
    expect(row.data.values.single, 1);
  });

  test('[SEC-04/AC1] deleting a recording leaves no residual files, rows or '
      'FTS entries for it in the app container', () async {
    await createSearchIndex(db);
    final job = await seedFullRecording(db, paths, 'r1');
    await indexRecording(db, 'r1');
    final otherJob = await seedFullRecording(db, paths, 'r2');
    await indexRecording(db, 'r2');
    final before = await rowsReferencing(db, 'r1');
    expect(before.values.every((n) => n > 0), isTrue, reason: '$before');
    expect(
      before.keys,
      containsAll(<String>[
        'recordings',
        'audio_chunks',
        'speech_segments',
        'markers',
        'speakers',
        'transcripts',
        'jobs',
        'extractions',
        'action_items',
        'mind_maps',
        'exports',
        'search_index',
      ]),
    );

    expectOk(await purger.purge('r1'));

    // Rows: nothing in any table references r1 (incl. FTS); segments of its
    // transcript are gone too.
    final after = await rowsReferencing(db, 'r1');
    expect(after.values.every((n) => n == 0), isTrue, reason: '$after');
    final segs = await db
        .customSelect(
          'SELECT count(*) AS n FROM transcript_segments '
          "WHERE transcript_id = 'tr-r1'",
        )
        .getSingle();
    expect(segs.read<int>('n'), 0);

    // Files: no path for r1 or its job is left; r2 is untouched.
    final files = filesUnder(paths.root);
    expect(
      files.where((f) => f.contains('r1') || f.contains(job)),
      isEmpty,
      reason: files.join('\n'),
    );
    expect(Directory(paths.audioDir('r1')).existsSync(), isFalse);
    expect(Directory(paths.workDir(job)).existsSync(), isFalse);
    expect(File(paths.renderedFile('r1')).existsSync(), isFalse);
    expect(Directory(paths.audioDir('r2')).listSync(), hasLength(2));
    expect(Directory(paths.workDir(otherJob)).existsSync(), isTrue);
    expect(File(paths.renderedFile('r2')).existsSync(), isTrue);
    // Integration W3: APP-02's triggers index title, segments and the
    // extraction, so r2 has several rows — all still there.
    expect((await rowsReferencing(db, 'r2'))['search_index'], greaterThan(0));

    // No file in the container holds r1's content (DB + WAL encrypted,
    // files gone).
    for (final f in files) {
      final bytes = File(p.join(paths.root, f)).readAsBytesSync();
      expect(_contains(bytes, secretFor('r1')), isFalse, reason: f);
    }
  });

  test('[SEC-04/AC1] secure_delete + WAL truncation leave no plaintext '
      'remnant even in an unencrypted database', () async {
    await db.close();
    if (File(paths.dbFile).existsSync()) File(paths.dbFile).deleteSync();
    db = open(const PlaintextCipher());
    purger = RecordingPurger(db, paths);
    await seedFullRecording(db, paths, 'r1');
    await seedFullRecording(db, paths, 'r2');
    expectOk(await purger.purge('r1'));
    final dbDir = Directory(p.dirname(paths.dbFile));
    final bytes = [
      for (final f in dbDir.listSync().whereType<File>())
        ...f.readAsBytesSync(),
    ];
    expect(_contains(bytes, secretFor('r2')), isTrue); // sanity: plaintext
    expect(_contains(bytes, secretFor('r1')), isFalse);
  });

  test('audio scope keeps transcript and note; transcript scope keeps '
      'audio', () async {
    await createSearchIndex(db);
    await seedFullRecording(db, paths, 'r1');
    await indexRecording(db, 'r1');
    expectOk(await purger.purge('r1', scope: PurgeScope.audio));
    var rows = await rowsReferencing(db, 'r1');
    expect(rows['audio_chunks'], 0);
    expect(rows['speech_segments'], 0);
    expect(rows['transcripts'], 1);
    expect(rows['search_index'], greaterThan(0));
    expect(Directory(paths.audioDir('r1')).existsSync(), isFalse);
    expect(File(paths.renderedFile('r1')).existsSync(), isTrue);

    await seedFullRecording(db, paths, 'r2');
    await indexRecording(db, 'r2');
    expectOk(await purger.purge('r2', scope: PurgeScope.transcripts));
    rows = await rowsReferencing(db, 'r2');
    expect(rows['recordings'], 1);
    expect(rows['audio_chunks'], 2);
    expect(rows['transcripts'], 0);
    expect(rows['speakers'], 0);
    expect(rows['extractions'], 0);
    expect(rows['action_items'], 0);
    expect(rows['mind_maps'], 0);
    // Only the title row (title + tags) of the kept recording is left.
    final kinds = await db
        .customSelect("SELECT kind FROM search_index WHERE recording_id = 'r2'")
        .get();
    expect(kinds.map((r) => r.read<String>('kind')).toSet(), {'title'});
    expect(File(paths.renderedFile('r2')).existsSync(), isFalse);
    expect(Directory(paths.audioDir('r2')).listSync(), hasLength(2));
  });

  test('refuses while a pipeline step is running', () async {
    await seedFullRecording(db, paths, 'r1', jobStatus: 'transcribing');
    final r = await purger.purge('r1');
    expect(r.failureOrNull, isA<StorageFailure>());
    expect((await rowsReferencing(db, 'r1'))['recordings'], 1);
    expect(Directory(paths.audioDir('r1')).existsSync(), isTrue);
  });

  test(
    'never deletes outside the storage root via a crafted chunk path',
    () async {
      await seedRecording(db, 'r1');
      final outside = File(p.join(tmp.path, 'outside.txt'))
        ..writeAsStringSync('x');
      await db
          .into(db.audioChunks)
          .insert(
            AudioChunksCompanion.insert(
              recordingId: 'r1',
              seq: 0,
              path: '../outside.txt',
              sampleRate: 16000,
              startMs: 0,
              endMs: 1,
              bytes: 1,
            ),
          );
      expectOk(await purger.purge('r1'));
      expect(outside.existsSync(), isTrue);
    },
  );

  test('sweepOrphans removes files no row references', () async {
    await seedFullRecording(db, paths, 'r1');
    for (final f in [
      p.join(paths.audioDir('ghost'), 'chunk_0.wav'),
      p.join(paths.workDir('ghost-job'), 'x'),
      paths.renderedFile('ghost'),
    ]) {
      File(f)
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
    }
    expect(expectOk(await purger.sweepOrphans()), 3);
    final files = filesUnder(paths.root);
    expect(files.where((f) => f.contains('ghost')), isEmpty);
    expect(files.where((f) => f.contains('r1')), isNotEmpty);
    expect(expectOk(await purger.sweepOrphans()), 0);
  });

  test(
    'sweepOrphans finishes a partial deletion of a surviving recording',
    () async {
      await seedFullRecording(db, paths, 'r1');
      expectOk(await purger.purge('r1', scope: PurgeScope.audio));
      expectOk(await purger.purge('r1', scope: PurgeScope.transcripts));
      // A crash left the files behind although their rows are gone.
      for (final f in [
        p.join(paths.audioDir('r1'), 'chunk_0.wav'),
        paths.renderedFile('r1'),
      ]) {
        File(f)
          ..createSync(recursive: true)
          ..writeAsStringSync('x');
      }
      expect(expectOk(await purger.sweepOrphans()), 2);
      expect(
        filesUnder(paths.root)
            .where((f) => f.startsWith('audio') || f.startsWith('rendered')),
        isEmpty,
      );
    },
  );

  test('a deleted recording with in-progress status is still removable '
      'when no step runs', () async {
    await seedFullRecording(
      db,
      paths,
      'r1',
      status: RecordingStatus.failed,
      jobStatus: 'failed',
    );
    expectOk(await purger.purge('r1'));
    expect((await rowsReferencing(db, 'r1'))['recordings'], 0);
  });
}
