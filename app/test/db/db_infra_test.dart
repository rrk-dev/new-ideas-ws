import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/converters.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';

import '../helpers/test_container.dart';
import 'db_test_utils.dart';

/// Marks the connection so the test can see the hook ran on the DB isolate.
class _MarkerCipher implements DatabaseCipher {
  const _MarkerCipher();

  @override
  void apply(Database raw) => raw.execute('PRAGMA application_id = 4242');
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('vv_db_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('StoragePaths', () {
    test('lays out vv/ under app support and keeps paths relative', () async {
      final paths = await StoragePaths.fromPlatform(
        appSupport: () async => tmp,
      );
      final root = p.join(tmp.path, 'vv');
      expect(paths.root, root);
      expect(paths.dbFile, p.join(root, 'db', 'vaultvoice.sqlite'));
      expect(paths.audioDir('r1'), p.join(root, 'audio', 'r1'));
      expect(paths.workDir('j1'), p.join(root, 'work', 'j1'));
      expect(paths.renderedFile('r1'), p.join(root, 'rendered', 'r1.md'));
      expect(paths.modelsDir, p.join(root, 'models'));
      expect(paths.logsDir, p.join(root, 'logs'));

      final chunk = p.join(paths.audioDir('r1'), 'chunk_0.wav');
      expect(paths.relativize(chunk), p.join('audio', 'r1', 'chunk_0.wav'));
      expect(paths.resolve(paths.relativize(chunk)), chunk);
    });

    test('rejects paths that escape the storage root', () {
      final paths = StoragePaths(p.join(tmp.path, 'vv'));
      expect(() => paths.resolve('../secret'), throwsArgumentError);
      expect(() => paths.resolve('/etc/passwd'), throwsArgumentError);
      expect(() => paths.relativize('/elsewhere/x'), throwsArgumentError);
      expect(() => paths.audioDir('../x'), throwsArgumentError);
      expect(() => paths.workDir(''), throwsArgumentError);
      expect(() => paths.renderedFile('..'), throwsArgumentError);
    });
  });

  group('openDatabaseFile', () {
    test('opens on a background isolate, applies the cipher hook first and '
        'persists across reopen', () async {
      final file = File(p.join(tmp.path, 'vv', 'db', 'vaultvoice.sqlite'));
      final db = VaultVoiceDatabase(
        openDatabaseFile(file, cipher: const _MarkerCipher()),
      );
      await seedRecording(db, 'r1');
      final appId = await db.customSelect('PRAGMA application_id').getSingle();
      expect(appId.read<int>('application_id'), 4242);
      final mode = await db.customSelect('PRAGMA journal_mode').getSingle();
      expect(mode.read<String>('journal_mode'), 'wal');
      final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fk.read<int>('foreign_keys'), 1);

      // Errors cross the isolate boundary as content-free StorageFailures.
      final dup = await db.recordingsRepository.create(
        RecordingsCompanion.insert(
          id: 'r1',
          createdAt: t0,
          status: RecordingStatus.recorded,
          source: RecordingSource.mic,
        ),
      );
      expect(dup.failureOrNull, isA<StorageFailure>());
      expect(dup.failureOrNull!.message, startsWith('sqlite error'));
      await db.close();
      expect(file.existsSync(), isTrue);

      final reopened = VaultVoiceDatabase(openDatabaseFile(file));
      addTearDown(reopened.close);
      expect(expectOk(await reopened.recordingsRepository.get('r1')).id, 'r1');
    });

    test('PlaintextCipher is a no-op', () {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      const PlaintextCipher().apply(raw);
      configureConnection(raw);
      expect(raw.select('PRAGMA busy_timeout').first.values.first, 5000);
    });
  });

  group('dbFailure', () {
    test('maps errors to content-free failures', () async {
      final db = memoryDb();
      final invalid = await guardDb(
        () => db.into(db.recordings).insert(const RecordingsCompanion()),
      );
      expect(invalid.failureOrNull?.message, 'invalid row data');
      expect(
        dbFailure(StateError('secret transcript text')),
        isA<UnexpectedFailure>().having(
          (f) => f.message,
          'message',
          isNot(contains('secret')),
        ),
      );
    });
  });

  group('converters', () {
    test('round-trip and tolerate malformed JSON shapes', () {
      const ms = EpochMsConverter();
      final local = DateTime(2026, 10, 12, 11);
      expect(ms.fromSql(ms.toSql(local)), local.toUtc());
      const map = JsonMapConverter();
      expect(map.fromSql(map.toSql({'a': 1})), {'a': 1});
      expect(map.fromSql('[1,2]'), isEmpty);
      const list = StringListConverter();
      expect(list.fromSql(list.toSql(['a', 'b'])), ['a', 'b']);
      expect(list.fromSql('[1,null,"x"]'), ['1', 'x']);
      expect(list.fromSql('{}'), isEmpty);
    });
  });

  group('backup exclusion (Android)', () {
    test('app data is never auto-backed-up or device-transferred', () {
      const res = 'android/app/src/main';
      final manifest = File('$res/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      final rules = File('$res/res/xml/data_extraction_rules.xml')
          .readAsStringSync();
      final legacy = File('$res/res/xml/backup_rules.xml').readAsStringSync();
      for (final domain in ['root', 'file', 'database', 'sharedpref']) {
        final exclude = '<exclude domain="$domain" path="." />';
        expect(exclude.allMatches(rules), hasLength(2), reason: domain);
        expect(legacy, contains(exclude));
      }
      expect(rules, isNot(contains('<include')));
      expect(legacy, isNot(contains('<include')));
    });
  });

  group('providers', () {
    test(
      'open the DB file under storagePaths and expose repositories',
      () async {
        final paths = StoragePaths(p.join(tmp.path, 'vv'));
        final container = createContainer(
          overrides: [storagePathsProvider.overrideWith((ref) async => paths)],
        );
        final db = container.read(vaultVoiceDatabaseProvider);
        expect(container.read(databaseCipherProvider), isA<PlaintextCipher>());
        expect(
          container.read(recordingsRepositoryProvider),
          same(db.recordingsRepository),
        );
        expect(container.read(transcriptsRepositoryProvider), isNotNull);
        expect(container.read(jobsRepositoryProvider), isNotNull);
        expect(container.read(profilesRepositoryProvider), isNotNull);
        expect(container.read(extractionsRepositoryProvider), isNotNull);
        expect(container.read(vaultRepositoryProvider), isNotNull);
        expect(container.read(modelsRepositoryProvider), isNotNull);
        expectOk(await container.read(settingsRepositoryProvider).set('k', 1));
        expect(File(paths.dbFile).existsSync(), isTrue);
      },
    );
  });
}
