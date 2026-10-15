import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/security/database_key_rotation.dart';
import 'package:vaultvoice/core/security/key_vault.dart';
import 'package:vaultvoice/core/security/sqlite3mc_cipher.dart';
import 'package:vaultvoice/core/security/storage_protection.dart';

part 'security_providers.g.dart';

/// OS key store. Tests and host runs use the in-memory vault; `bootstrap`
/// installs the Keychain/Keystore one on iOS and Android.
@Riverpod(keepAlive: true)
KeyVault keyVault(Ref ref) => MemoryKeyVault();

/// What the Settings "Encryption" tile reports (truthfully).
enum EncryptionState {
  /// sqlite3mc database with a key from the OS key store.
  encrypted,

  /// Encryption is configured but the key could not be read: the database
  /// stays closed (fail closed).
  unavailable,

  /// Plain database (tests / host builds only).
  off,
}

class EncryptionStatus {
  const EncryptionStatus(this.state, {this.hardwareBacked = false});

  final EncryptionState state;
  final bool hardwareBacked;
}

@Riverpod(keepAlive: true)
EncryptionStatus encryptionStatus(Ref ref) => switch (ref.watch(
  databaseCipherProvider,
)) {
  final Sqlite3mcCipher c => EncryptionStatus(
    EncryptionState.encrypted,
    hardwareBacked: c.hardwareBacked,
  ),
  UnavailableCipher() => const EncryptionStatus(EncryptionState.unavailable),
  _ => const EncryptionStatus(EncryptionState.off),
};

/// Startup step (ADR-SEC-01): protects the `vv/` root (iOS Data Protection
/// class + backup exclusion), loads the database key and returns the
/// provider overrides that switch the database to sqlite3mc. A missing key
/// yields [UnavailableCipher] — the app never silently opens a plaintext DB.
Future<List<Override>> prepareEncryptionAtRest({
  required KeyVault vault,
  required StorageProtection protection,
  required String storageRoot,
  Logger? logger,
}) async {
  final protected = await protection.protectDirectory(storageRoot);
  if (protected case Err(:final failure)) {
    logger?.failure('security', failure, level: LogLevel.warning);
  }
  // A "Delete all data" key rotation (SEC-04) is pending: the file may be
  // encrypted with the `db.next` key.
  final fallback = File(rotationMarkerPath(storageRoot)).existsSync()
      ? (await vault.getOrCreateKey(kDatabaseNextKeyName)).valueOrNull
      : null;
  final DatabaseCipher cipher;
  switch (await vault.getOrCreateKey(kDatabaseKeyName)) {
    case Ok(value: final key):
      cipher = Sqlite3mcCipher(
        key.bytes,
        fallbackKey: fallback?.bytes,
        hardwareBacked: key.hardwareBacked,
      );
    case Err(:final failure):
      logger?.failure('security', failure);
      cipher = const UnavailableCipher();
  }
  return [
    keyVaultProvider.overrideWithValue(vault),
    databaseCipherProvider.overrideWithValue(cipher),
  ];
}

/// Crypto-shredding of the database key (SEC-04 "Delete all data").
@Riverpod(keepAlive: true)
Future<DatabaseKeyRotation> databaseKeyRotation(Ref ref) async =>
    DatabaseKeyRotation(
      vault: ref.watch(keyVaultProvider),
      storageRoot: (await ref.watch(storagePathsProvider.future)).root,
    );
