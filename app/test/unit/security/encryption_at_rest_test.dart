import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/security/key_vault.dart';
import 'package:vaultvoice/core/security/security_providers.dart';
import 'package:vaultvoice/core/security/sqlite3mc_cipher.dart';
import 'package:vaultvoice/core/security/storage_protection.dart';
import 'package:vaultvoice/features/library/data/search_repository.dart';

import '../../db/db_test_utils.dart';
import '../../helpers/test_container.dart';

const _secret = 'Quarterly merger with Initech is confidential';

Uint8List _key(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => (i * 7 + seed) & 0xff));

Future<void> _writeTranscript(VaultVoiceDatabase db) async {
  await seedRecording(db, 'r1');
  await db
      .into(db.transcripts)
      .insert(
        TranscriptsCompanion.insert(
          id: 't1',
          recordingId: 'r1',
          modelId: 'whisper-base',
          language: 'en',
          createdAt: t0,
        ),
      );
  expectOk(
    await db.transcriptsRepository.upsertSegments([
      TranscriptSegmentsCompanion.insert(
        transcriptId: 't1',
        seq: 0,
        startMs: 0,
        endMs: 1000,
        body: _secret,
      ),
    ]),
  );
}

/// Every byte of every file under [dir] (the "pulled container").
List<int> _allBytes(Directory dir) => [
  for (final f in dir.listSync(recursive: true).whereType<File>())
    ...f.readAsBytesSync(),
];

bool _containsAscii(List<int> haystack, String needle) {
  final n = ascii.encode(needle);
  outer:
  for (var i = 0; i + n.length <= haystack.length; i++) {
    for (var j = 0; j < n.length; j++) {
      if (haystack[i + j] != n[j]) continue outer;
    }
    return true;
  }
  return false;
}

class _FailingVault implements KeyVault {
  @override
  Future<Result<VaultKey>> getOrCreateKey(String name) async =>
      const Err(StorageFailure('key vault: keychain'));

  @override
  Future<Result<void>> deleteKey(String name) async => const Ok(null);

  @override
  Future<Result<void>> deleteAllKeys() async => const Ok(null);
}

class _RecordingProtection implements StorageProtection {
  final dirs = <String>[];

  @override
  Future<Result<StorageProtectionInfo>> protectDirectory(String d) async {
    dirs.add(d);
    return const Ok(
      StorageProtectionInfo(
        protectionClass: 'completeUntilFirstUserAuthentication',
        excludedFromBackup: true,
      ),
    );
  }
}

void main() {
  late Directory tmp;
  late File dbFile;
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tmp = Directory.systemTemp.createTempSync('vv_sec01_');
    dbFile = File(p.join(tmp.path, 'vv', 'db', 'vaultvoice.sqlite'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('the bundled SQLite is SQLite3 Multiple Ciphers with FTS5', () {
    final raw = sqlite3.openInMemory();
    addTearDown(raw.close);
    expect(raw.select('PRAGMA cipher').first.values.first, isNotEmpty);
    expect(
      raw
          .select("SELECT sqlite_compileoption_used('ENABLE_FTS5') AS f")
          .first['f'],
      1,
    );
  });

  test('[SEC-01/AC1] the database file holds no plaintext transcript, only '
      'opens with its key and is not a readable SQLite file', () async {
    final db = VaultVoiceDatabase(
      openDatabaseFile(dbFile, cipher: Sqlite3mcCipher(_key(1))),
    );
    await _writeTranscript(db);
    await db.close();

    final bytes = _allBytes(tmp);
    expect(bytes, isNotEmpty);
    expect(_containsAscii(bytes, _secret), isFalse);
    expect(_containsAscii(bytes, 'Initech'), isFalse);
    expect(isPlaintextSqliteFile(dbFile.path), isFalse);
    expect(_containsAscii(bytes, 'SQLite format 3'), isFalse);

    // Wrong key / no key: refused before any query runs.
    for (final cipher in [Sqlite3mcCipher(_key(2)), const PlaintextCipher()]) {
      final wrong = VaultVoiceDatabase(
        openDatabaseFile(dbFile, cipher: cipher),
      );
      final r = await wrong.recordingsRepository.get('r1');
      expect(r.isOk, isFalse);
      await wrong.close();
    }

    final right = VaultVoiceDatabase(
      openDatabaseFile(dbFile, cipher: Sqlite3mcCipher(_key(1))),
    );
    addTearDown(right.close);
    final segs = expectOk(await right.transcriptsRepository.segments('t1'));
    expect(segs.single.body, _secret);
  });

  test('[SEC-01/AC1] a plaintext database from a pre-SEC-01 build is '
      'encrypted in place on first open, data preserved', () async {
    final plain = VaultVoiceDatabase(openDatabaseFile(dbFile));
    await _writeTranscript(plain);
    await plain.close();
    expect(isPlaintextSqliteFile(dbFile.path), isTrue);

    final enc = VaultVoiceDatabase(
      openDatabaseFile(dbFile, cipher: Sqlite3mcCipher(_key(3))),
    );
    final segs = expectOk(await enc.transcriptsRepository.segments('t1'));
    expect(segs.single.body, _secret);
    final mode = await enc.customSelect('PRAGMA journal_mode').getSingle();
    expect(mode.read<String>('journal_mode'), 'wal');
    await enc.close();

    expect(isPlaintextSqliteFile(dbFile.path), isFalse);
    expect(_containsAscii(_allBytes(tmp), _secret), isFalse);
  });

  test('integration W3 (SEC-01 ↔ APP-02): the FTS5 search index works on '
      'the encrypted database and stays encrypted on disk', () async {
    final db = VaultVoiceDatabase(
      openDatabaseFile(dbFile, cipher: Sqlite3mcCipher(_key(4))),
    );
    await _writeTranscript(db);
    final hits = expectOk(await SearchRepository(db).search('Initech'));
    expect(hits.map((h) => h.recordingId), ['r1']);
    expect(
      (await db
              .customSelect('SELECT count(*) AS n FROM search_index')
              .getSingle())
          .read<int>('n'),
      greaterThan(0),
    );
    await db.close();
    expect(_containsAscii(_allBytes(tmp), 'Initech'), isFalse);
    expect(isPlaintextSqliteFile(dbFile.path), isFalse);
  });

  test('keys must be 32 bytes and never print', () {
    expect(() => Sqlite3mcCipher(Uint8List(16)), throwsArgumentError);
    expect(
      () => VaultKey(Uint8List(31), hardwareBacked: true),
      throwsA(isA<ArgumentError>()),
    );
    expect(Sqlite3mcCipher(_key(1)).toString(), isNot(contains('07')));
    expect(
      VaultKey(_key(1), hardwareBacked: true).toString(),
      contains('redacted'),
    );
  });

  test('isPlaintextSqliteFile handles missing and short files', () {
    expect(isPlaintextSqliteFile(p.join(tmp.path, 'none')), isFalse);
    final short = File(p.join(tmp.path, 'short'))..writeAsStringSync('SQL');
    expect(isPlaintextSqliteFile(short.path), isFalse);
  });

  group('prepareEncryptionAtRest', () {
    test('protects the storage root and installs the sqlite3mc cipher; '
        'the key is stable across launches', () async {
      final vault = MemoryKeyVault();
      final protection = _RecordingProtection();
      final paths = StoragePaths(p.join(tmp.path, 'vv'));
      Future<VaultVoiceDatabase> launch() async {
        final overrides = await prepareEncryptionAtRest(
          vault: vault,
          protection: protection,
          storageRoot: paths.root,
        );
        final c = createContainer(
          overrides: [
            ...overrides,
            storagePathsProvider.overrideWith((ref) async => paths),
          ],
        );
        expect(c.read(databaseCipherProvider), isA<Sqlite3mcCipher>());
        expect(
          c.read(encryptionStatusProvider).state,
          EncryptionState.encrypted,
        );
        expect(c.read(keyVaultProvider), same(vault));
        final db = c.read(vaultVoiceDatabaseProvider);
        // Opening succeeds with the stored key.
        expectOk(await db.settingsRepository.set('launches', 1));
        return db;
      }

      final first = await launch();
      await _writeTranscript(first);
      await first.close();
      final second = await launch();
      expect(
        expectOk(await second.transcriptsRepository.segments('t1')).single.body,
        _secret,
      );
      expect(protection.dirs, [paths.root, paths.root]);
      expect(vault.keys.keys, [kDatabaseKeyName]);
      expect(isPlaintextSqliteFile(paths.dbFile), isFalse);
    });

    test('fails closed when the key is unavailable: no plaintext DB is '
        'created', () async {
      final paths = StoragePaths(p.join(tmp.path, 'vv'));
      final overrides = await prepareEncryptionAtRest(
        vault: _FailingVault(),
        protection: _RecordingProtection(),
        storageRoot: paths.root,
      );
      final c = createContainer(
        overrides: [
          ...overrides,
          storagePathsProvider.overrideWith((ref) async => paths),
        ],
      );
      expect(c.read(databaseCipherProvider), isA<UnavailableCipher>());
      expect(
        c.read(encryptionStatusProvider).state,
        EncryptionState.unavailable,
      );
      final r = await c
          .read(vaultVoiceDatabaseProvider)
          .recordingsRepository
          .get('r1');
      expect(r.isOk, isFalse);
      expect(isPlaintextSqliteFile(paths.dbFile), isFalse);
    });

    test('default status without encryption is "off"', () {
      final c = createContainer();
      expect(c.read(encryptionStatusProvider).state, EncryptionState.off);
    });
  });

  group('MethodChannelKeyVault / StorageProtection', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(secureStorageChannel);
    final calls = <MethodCall>[];

    void handle(Future<Object?>? Function(MethodCall) h) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) {
              calls.add(call);
              return h(call);
            });

    tearDown(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('getOrCreateKey returns the platform key', () async {
      handle((call) async => {'key': _key(9), 'hardwareBacked': true});
      final key = expectOk(
        await const MethodChannelKeyVault().getOrCreateKey('db.v1'),
      );
      expect(key.bytes, _key(9));
      expect(key.hardwareBacked, isTrue);
      expect(calls.single.arguments, {'name': 'db.v1'});
    });

    test('rejects malformed keys and maps platform errors', () async {
      handle((call) async => {'key': Uint8List(8)});
      expect(
        (await const MethodChannelKeyVault().getOrCreateKey('k')).failureOrNull,
        isA<StorageFailure>(),
      );
      handle((call) async => throw PlatformException(code: 'keystore'));
      final r = await const MethodChannelKeyVault().getOrCreateKey('k');
      expect(r.failureOrNull?.message, 'key vault: keystore');
      expect(
        (await const MethodChannelKeyVault().deleteKey('k')).failureOrNull,
        isA<StorageFailure>(),
      );
      handle((call) async => null);
      expectOk(await const MethodChannelKeyVault().deleteKey('k'));
      expectOk(await const MethodChannelKeyVault().deleteAllKeys());
      expect(calls.last.method, 'deleteAllKeys');
    });

    test('protectDirectory reports the protection class', () async {
      handle(
        (call) async => {
          'protectionClass': 'completeUntilFirstUserAuthentication',
          'excludedFromBackup': true,
        },
      );
      final info = expectOk(
        await const MethodChannelStorageProtection().protectDirectory('/vv'),
      );
      expect(info.protectionClass, 'completeUntilFirstUserAuthentication');
      expect(info.excludedFromBackup, isTrue);
      handle((call) async => throw PlatformException(code: 'protection'));
      expect(
        (await const MethodChannelStorageProtection().protectDirectory('/vv'))
            .failureOrNull,
        isA<StorageFailure>(),
      );
    });
  });

  test('MemoryKeyVault creates, keeps and destroys keys', () async {
    final vault = MemoryKeyVault();
    final a = expectOk(await vault.getOrCreateKey('a'));
    expect(expectOk(await vault.getOrCreateKey('a')).bytes, a.bytes);
    expectOk(await vault.deleteKey('a'));
    expect(vault.keys, isEmpty);
    await vault.getOrCreateKey('b');
    expectOk(await vault.deleteAllKeys());
    expect(vault.keys, isEmpty);
  });

  group('[SEC-01/AC2] protection class keeps background recording working', () {
    test('iOS uses completeUntilFirstUserAuthentication and an '
        'after-first-unlock keychain item, never .complete', () {
      final swift = File('ios/Runner/SecureStoragePlugin.swift')
          .readAsStringSync();
      expect(
        swift,
        contains('FileProtectionType.completeUntilFirstUserAuthentication'),
      );
      expect(
        swift,
        contains('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'),
      );
      expect(swift, contains('isExcludedFromBackup = true'));
      expect(swift, isNot(contains('FileProtectionType.complete]')));
      expect(swift, isNot(contains('kSecAttrAccessibleWhenUnlocked')));
    });

    test('Android keystore key does not require user authentication', () {
      final kt = File(
        'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/security/'
        'SecureStoragePlugin.kt',
      ).readAsStringSync();
      expect(kt, contains('setUserAuthenticationRequired(false)'));
      expect(kt, contains('noBackupFilesDir'));
      expect(kt, isNot(contains('setUnlockedDeviceRequired(true)')));
    });

    test('both platforms register the plugin', () {
      expect(
        File('ios/Runner/AppDelegate.swift').readAsStringSync(),
        contains('SecureStoragePlugin.register'),
      );
      expect(
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
        contains('SecureStoragePlugin.swift in Sources'),
      );
      expect(
        File(
          'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/'
          'MainActivity.kt',
        ).readAsStringSync(),
        contains('SecureStoragePlugin()'),
      );
    });
  });
}
