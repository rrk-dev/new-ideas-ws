import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/security/database_key_rotation.dart';
import 'package:vaultvoice/core/security/key_vault.dart';
import 'package:vaultvoice/core/security/security_providers.dart';
import 'package:vaultvoice/core/security/sqlite3mc_cipher.dart';
import 'package:vaultvoice/core/security/storage_protection.dart';
import 'package:vaultvoice/features/retention/data/secure_data_wiper.dart';

import '../../db/db_test_utils.dart';
import '../../helpers/test_container.dart';
import 'retention_fixtures.dart';

class _Protection implements StorageProtection {
  @override
  Future<Result<StorageProtectionInfo>> protectDirectory(String d) async =>
      const Ok(
        StorageProtectionInfo(
          protectionClass: 'test',
          excludedFromBackup: true,
        ),
      );
}

void main() {
  late Directory tmp;
  late StoragePaths paths;
  late MemoryKeyVault vault;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tmp = Directory.systemTemp.createTempSync('vv_wipe_');
    paths = StoragePaths(p.join(tmp.path, 'vv'));
    vault = MemoryKeyVault();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// One app launch: SEC-01 startup + the DB provider.
  Future<VaultVoiceDatabase> launch() async {
    final overrides = await prepareEncryptionAtRest(
      vault: vault,
      protection: _Protection(),
      storageRoot: paths.root,
    );
    final c = createContainer(
      overrides: [
        ...overrides,
        storagePathsProvider.overrideWith((ref) async => paths),
      ],
    );
    final db = c.read(vaultVoiceDatabaseProvider);
    return db;
  }

  test(
    '[SEC-04] Delete all data wipes rows, files, grants and the database '
    'key; the app keeps working and later launches recover the rotation',
    () async {
      final db = await launch();
      await createSearchIndex(db);
      await seedFullRecording(db, paths, 'r1');
      await indexRecording(db, 'r1');
      expectOk(await db.settingsRepository.set('audio.agc', false));
      await db
          .into(db.modelsInstalled)
          .insert(
            ModelsInstalledCompanion.insert(
              id: 'whisper-base',
              type: ModelType.stt,
              version: '1',
              path: 'models/whisper-base/model.bin',
              sha256: 'x',
              size: 1,
              installedAt: t0,
            ),
          );
      final model = File(p.join(paths.modelsDir, 'whisper-base', 'model.bin'))
        ..createSync(recursive: true)
        ..writeAsStringSync('weights');
      final log = File(p.join(paths.logsDir, 'vv.log'))
        ..createSync(recursive: true)
        ..writeAsStringSync('log');
      final nativeCrash = File(
        p.join(paths.root, 'crash', 'native-current.vvcrash'),
      )..createSync(recursive: true);
      final shareTmp = Directory(p.join(tmp.path, 'tmp-vv'))..createSync();
      File(p.join(shareTmp.path, 'diag.zip')).writeAsStringSync('zip');
      final oldKey = vault.keys[kDatabaseKeyName]!;

      final released = <String>[];
      final wiper = SecureDataWiper(
        db: db,
        paths: paths,
        releaseGrant: (t) async => released.add(t.id),
        rotateKey: () => DatabaseKeyRotation(
          vault: vault,
          storageRoot: paths.root,
        ).rotate(db),
        extraDirectories: [shareTmp.path],
      );
      expectOk(await wiper.deleteAllData());

      // Rows: everything except installed models.
      for (final table in db.allTables) {
        final n = await db
            .customSelect(
              'SELECT count(*) AS n FROM "${table.actualTableName}"',
            )
            .getSingle();
        expect(
          n.read<int>('n'),
          table.actualTableName == 'models_installed' ? 1 : 0,
          reason: table.actualTableName,
        );
      }
      final fts = await db
          .customSelect('SELECT count(*) AS n FROM search_index')
          .getSingle();
      expect(fts.read<int>('n'), 0);
      expect(released, ['v1']);

      // Files: only the DB (+ rotation marker), models and the pre-opened
      // native crash file survive; temp copies are gone.
      final files = filesUnder(paths.root);
      expect(
        files.where(
          (f) =>
              !f.startsWith('db${p.separator}') &&
              !f.startsWith('models${p.separator}') &&
              f != p.join('crash', 'native-current.vvcrash'),
        ),
        isEmpty,
        reason: files.join('\n'),
      );
      expect(model.existsSync(), isTrue);
      expect(log.existsSync(), isFalse);
      expect(nativeCrash.existsSync(), isTrue);
      expect(filesUnder(shareTmp.path), isEmpty);

      // Crypto-shredding: the old key is destroyed; the open DB was rekeyed
      // and keeps working.
      expect(vault.keys.containsKey(kDatabaseKeyName), isFalse);
      expect(vault.keys[kDatabaseNextKeyName], isNot(oldKey));
      await seedRecording(db, 'after');
      await db.close();

      // The old key no longer opens the file.
      final stale = VaultVoiceDatabase(
        openDatabaseFile(File(paths.dbFile), cipher: Sqlite3mcCipher(oldKey)),
      );
      expect((await stale.recordingsRepository.get('after')).isOk, isFalse);
      await stale.close();

      // Next launch: new db.v1 + fallback db.next → opens and rekeys to v1.
      final second = await launch();
      expect(
        expectOk(await second.recordingsRepository.get('after')).id,
        'after',
      );
      expectOk(
        await DatabaseKeyRotation(
          vault: vault,
          storageRoot: paths.root,
        ).finishPendingRotation(),
      );
      expect(vault.keys.keys, [kDatabaseKeyName]);
      expect(File(rotationMarkerPath(paths.root)).existsSync(), isFalse);
      await second.close();

      // Third launch: plain primary key, no marker.
      final third = await launch();
      expect(
        expectOk(await third.recordingsRepository.get('after')).id,
        'after',
      );
      await third.close();
    },
  );

  test('without encryption the wipe still clears rows and files', () async {
    final db = VaultVoiceDatabase(openDatabaseFile(File(paths.dbFile)));
    addTearDown(db.close);
    await seedFullRecording(db, paths, 'r1');
    final wiper = SecureDataWiper(
      db: db,
      paths: paths,
      releaseGrant: (_) async => throw StateError('grant already gone'),
      rotateKey: null,
    );
    expectOk(await wiper.deleteAllData());
    expect(
      (await rowsReferencing(db, 'r1')).values.every((n) => n == 0),
      isTrue,
    );
    expect(filesUnder(paths.root).where((f) => !f.startsWith('db')), isEmpty);
  });
}
