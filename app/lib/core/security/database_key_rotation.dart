import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/security/key_vault.dart';

/// Vault slot of the key a rotation moves the database to.
const kDatabaseNextKeyName = 'db.next';

/// Marker file (no secret inside) saying a rotation started: the next
/// launch passes the `db.next` key as fallback (`Sqlite3mcCipher`).
String rotationMarkerPath(String storageRoot) =>
    p.join(storageRoot, 'db', '.rekey-pending');

/// Crypto-shreds the database key ("Delete all data", SEC-04).
///
/// Crash-safe order:
/// 1. write the marker, create a fresh `db.next` key;
/// 2. `PRAGMA hexrekey` the open database to `db.next` (sqlite3mc rewrites
///    every page; works in WAL mode with sqlite3mc 2.5.0);
/// 3. delete the old `db.v1` key — the previous key no longer exists.
///
/// On the next launch `db.v1` is created anew, does not open the file, the
/// `db.next` fallback does, and the cipher rekeys the file to the new
/// `db.v1`; [finishPendingRotation] then deletes `db.next` and the marker.
class DatabaseKeyRotation {
  DatabaseKeyRotation({required this.vault, required this.storageRoot});

  final KeyVault vault;
  final String storageRoot;

  Future<Result<void>> rotate(GeneratedDatabase db) async {
    final marker = File(rotationMarkerPath(storageRoot));
    try {
      marker.parent.createSync(recursive: true);
      marker.writeAsStringSync('1', flush: true);
    } on FileSystemException {
      return const Err(StorageFailure('rotation marker not writable'));
    }
    final stale = await vault.deleteKey(kDatabaseNextKeyName);
    if (stale case Err(:final failure)) return Err(failure);
    final next = await vault.getOrCreateKey(kDatabaseNextKeyName);
    switch (next) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final key):
        try {
          await db.customStatement("PRAGMA hexrekey = '${_hex(key.bytes)}'");
        } on Object catch (e) {
          return Err(UnexpectedFailure(e.runtimeType.toString()));
        }
    }
    return await vault.deleteKey(kDatabaseKeyName);
  }

  /// After the database opened (with the rekeyed primary key), drops the
  /// rotation's `db.next` key and the marker. No-op without a marker.
  Future<Result<void>> finishPendingRotation() async {
    final marker = File(rotationMarkerPath(storageRoot));
    if (!marker.existsSync()) return const Ok(null);
    final deleted = await vault.deleteKey(kDatabaseNextKeyName);
    if (deleted case Err()) return deleted;
    try {
      marker.deleteSync();
    } on FileSystemException {
      return const Err(StorageFailure('rotation marker not removable'));
    }
    return const Ok(null);
  }

  static String _hex(Uint8List key) =>
      key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
