import 'dart:io';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/repositories/extractions_repository.dart';
import 'package:vaultvoice/core/db/repositories/jobs_repository.dart';
import 'package:vaultvoice/core/db/repositories/models_repository.dart';
import 'package:vaultvoice/core/db/repositories/profiles_repository.dart';
import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/core/db/repositories/transcripts_repository.dart';
import 'package:vaultvoice/core/db/repositories/vault_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';

part 'db_providers.g.dart';

/// `<appSupport>/vv` layout. Tests override with a temp directory.
@Riverpod(keepAlive: true)
Future<StoragePaths> storagePaths(Ref ref) => StoragePaths.fromPlatform();

/// Cipher hook for the DB connection. SEC-01 overrides this with the
/// Keychain/Keystore-keyed sqlite3mc cipher.
@Riverpod(keepAlive: true)
DatabaseCipher databaseCipher(Ref ref) => const PlaintextCipher();

/// The single database instance of this process. Opening is lazy (the path
/// is resolved asynchronously) and runs on a drift background isolate.
/// Tests override with `VaultVoiceDatabase(NativeDatabase.memory())`.
@Riverpod(keepAlive: true)
VaultVoiceDatabase vaultVoiceDatabase(Ref ref) {
  final cipher = ref.watch(databaseCipherProvider);
  final paths = ref.watch(storagePathsProvider.future);
  final db = VaultVoiceDatabase(
    LazyDatabase(
      () async => openDatabaseFile(File((await paths).dbFile), cipher: cipher),
    ),
  );
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
RecordingsRepository recordingsRepository(Ref ref) =>
    ref.watch(vaultVoiceDatabaseProvider).recordingsRepository;

@Riverpod(keepAlive: true)
TranscriptsRepository transcriptsRepository(Ref ref) =>
    ref.watch(vaultVoiceDatabaseProvider).transcriptsRepository;

@Riverpod(keepAlive: true)
JobsRepository jobsRepository(Ref ref) =>
    ref.watch(vaultVoiceDatabaseProvider).jobsRepository;

@Riverpod(keepAlive: true)
ProfilesRepository profilesRepository(Ref ref) =>
    ref.watch(vaultVoiceDatabaseProvider).profilesRepository;

@Riverpod(keepAlive: true)
ExtractionsRepository extractionsRepository(Ref ref) =>
    ref.watch(vaultVoiceDatabaseProvider).extractionsRepository;

@Riverpod(keepAlive: true)
VaultRepository vaultRepository(Ref ref) =>
    ref.watch(vaultVoiceDatabaseProvider).vaultRepository;

@Riverpod(keepAlive: true)
ModelsRepository modelsRepository(Ref ref) =>
    ref.watch(vaultVoiceDatabaseProvider).modelsRepository;

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    ref.watch(vaultVoiceDatabaseProvider).settingsRepository;
