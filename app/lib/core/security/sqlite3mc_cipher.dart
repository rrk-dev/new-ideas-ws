import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:vaultvoice/core/db/connection.dart';
import 'package:vaultvoice/core/security/key_vault.dart';

/// Encrypts the drift database with SQLite3 Multiple Ciphers (ADR-SEC-01).
///
/// Requires the `hooks: user_defines: sqlite3: source: sqlite3mc` build
/// (`app/pubspec.yaml`); the sqlite3mc default cipher is ChaCha20-Poly1305
/// with a PBKDF2-SHA256-derived page key (sqlite3mc 2.x, bundled by
/// `sqlite3` 3.7.0). Runs first on the drift background isolate, so it only
/// holds sendable state (the hex key string).
class Sqlite3mcCipher implements DatabaseCipher {
  Sqlite3mcCipher(Uint8List key, {this.hardwareBacked = false})
    : _hexKey = _hex(key) {
    if (key.length != kVaultKeyBytes) {
      throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
    }
  }

  final String _hexKey;

  /// The key's wrapping key is hardware-backed (for the Settings status).
  final bool hardwareBacked;

  @override
  void apply(Database raw) {
    // A plain SQLite build ignores unknown pragmas: refuse to run unencrypted.
    final cipher = raw.select('PRAGMA cipher');
    if (cipher.isEmpty || (cipher.first.values.first as String?) == null) {
      throw StateError('SQLite build without encryption support');
    }
    final file = _mainFile(raw);
    if (file != null && isPlaintextSqliteFile(file)) {
      // A database created before SEC-01 (FND-04 builds): encrypt it in
      // place. sqlite3mc cannot rekey in WAL mode, so leave WAL first (this
      // checkpoints and removes the plaintext -wal file); the caller turns
      // WAL back on afterwards.
      raw
        ..execute('PRAGMA journal_mode = DELETE')
        ..execute("PRAGMA hexrekey = '$_hexKey'");
    } else {
      raw.execute("PRAGMA hexkey = '$_hexKey'");
    }
    // Fails with SQLITE_NOTADB on a wrong key, so a bad key never
    // surfaces later as random query errors.
    raw.select('SELECT count(*) FROM sqlite_master');
  }

  static String? _mainFile(Database raw) {
    for (final row in raw.select('PRAGMA database_list')) {
      if (row['name'] == 'main') {
        final f = row['file'] as String?;
        return f == null || f.isEmpty ? null : f;
      }
    }
    return null;
  }

  static String _hex(Uint8List key) =>
      key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  @override
  String toString() => 'Sqlite3mcCipher(<redacted>)';
}

/// The database key could not be obtained: fail closed, never fall back to
/// a plaintext database.
class UnavailableCipher implements DatabaseCipher {
  const UnavailableCipher();

  @override
  void apply(Database raw) =>
      throw StateError('database key unavailable (SEC-01)');
}

/// The 16-byte SQLite header magic of an unencrypted database file.
const _sqliteMagic = 'SQLite format 3\u0000';

/// Whether [path] is an existing, unencrypted SQLite database.
bool isPlaintextSqliteFile(String path) {
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() < 16) return false;
  final raf = file.openSync();
  try {
    return String.fromCharCodes(raf.readSync(16)) == _sqliteMagic;
  } finally {
    raf.closeSync();
  }
}
