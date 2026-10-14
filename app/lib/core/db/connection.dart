import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

/// Hook that runs first on every raw SQLite connection, before drift issues
/// any statement.
///
/// SEC-01 switches encryption on by providing an implementation that issues
/// `PRAGMA key` and asserts the cipher build (`PRAGMA cipher` for sqlite3mc),
/// together with `hooks: user_defines: sqlite3: source: sqlite3mc` in
/// `pubspec.yaml`. Nothing else in the DB layer changes.
///
/// Implementations run on the database's background isolate, so they must be
/// sendable (no open ports or native handles captured).
abstract interface class DatabaseCipher {
  void apply(Database raw);
}

/// No encryption: the FND-04 default until SEC-01 lands.
class PlaintextCipher implements DatabaseCipher {
  const PlaintextCipher();

  @override
  void apply(Database raw) {}
}

/// Pragmas applied to every connection after the cipher.
///
/// `secure_delete` (SEC-04): deleted content is overwritten with zeros
/// instead of lingering in free pages / the WAL.
void configureConnection(Database raw) {
  raw
    ..execute('PRAGMA journal_mode = WAL')
    ..execute('PRAGMA busy_timeout = 5000')
    ..execute('PRAGMA secure_delete = ON');
}

/// Opens [file] on a drift background isolate so queries never block the UI
/// isolate. Create one executor per process and share the database instance
/// (other isolates use `serializableConnection()`); never open a second
/// independent connection to the same (encrypted) file.
QueryExecutor openDatabaseFile(
  File file, {
  DatabaseCipher cipher = const PlaintextCipher(),
}) {
  file.parent.createSync(recursive: true);
  return NativeDatabase.createInBackground(
    file,
    setup: (raw) {
      cipher.apply(raw);
      configureConnection(raw);
    },
  );
}
