import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/retention/data/recording_purger.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

/// "Delete all data" (SEC-04): wipes every recording, transcript, note,
/// profile, template, vault target and setting.
///
/// 1. Releases the OS folder grants of every vault target (Android SAF
///    persisted permission; iOS bookmarks die with their row).
/// 2. Deletes every row (and FTS entry) in one transaction on a
///    `secure_delete` connection, then truncates the WAL and `VACUUM`s so no
///    deleted page survives in the file.
/// 3. Crypto-shreds: rekeys the database to a fresh key and destroys the
///    old one ([rotateKey], ADR-SEC-01 / `DatabaseKeyRotation`).
/// 4. Deletes every file under `vv/` except the open database and the
///    downloaded models, plus the app's temp directory.
///
/// PRODUCT-DECISION: downloaded models (`models/` + `models_installed`) are
/// kept — they hold no user data and are large to re-download. Exported
/// vault notes are the user's files and are never touched.
class SecureDataWiper implements DataWiper {
  SecureDataWiper({
    required this.db,
    required this.paths,
    required this.releaseGrant,
    required this.rotateKey,
    this.extraDirectories = const [],
  });

  final VaultVoiceDatabase db;
  final StoragePaths paths;

  /// Releases the OS grant of one vault target (best effort).
  final Future<void> Function(VaultTargetRow target) releaseGrant;

  /// Rekeys the database and destroys the old key; `null` = the database is
  /// not encrypted (tests / host).
  final Future<Result<void>> Function()? rotateKey;

  /// Other app-private directories wiped completely (temp/share copies).
  final List<String> extraDirectories;

  /// Paths under `vv/` that survive the wipe (relative to the root).
  static const keep = {'db', 'models', 'crash/native-current.vvcrash'};

  @override
  Future<Result<void>> deleteAllData() async {
    final targets = await guardDb(() => db.select(db.vaultTargets).get());
    for (final t in targets.valueOrNull ?? const <VaultTargetRow>[]) {
      try {
        await releaseGrant(t);
      } on Object {
        // A grant that is already gone needs no release.
      }
    }

    final rows = await guardDb(() async {
      final fts = await db
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable.withString(kSearchIndexTable)],
          )
          .get();
      await db.transaction(() async {
        if (fts.isNotEmpty) {
          await db.customStatement('DELETE FROM $kSearchIndexTable');
        }
        // Children before parents is not required (FK cascades), but
        // explicit deletes keep this independent of the FK setting.
        for (final table in db.allTables.toList().reversed) {
          if (table.actualTableName == db.modelsInstalled.actualTableName) {
            continue;
          }
          await db.delete(table).go();
        }
      });
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.customStatement('VACUUM');
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    });
    if (rows case Err(:final failure)) return Err(failure);

    final rotate = rotateKey;
    if (rotate != null) {
      final rotated = await rotate();
      if (rotated case Err(:final failure)) return Err(failure);
    }

    try {
      _wipeDirectory(paths.root, keepRelative: keep);
      extraDirectories.forEach(_wipeDirectory);
    } on FileSystemException {
      return const Err(StorageFailure('could not delete all files'));
    }
    return const Ok(null);
  }

  static void _wipeDirectory(
    String root, {
    Set<String> keepRelative = const {},
  }) {
    final dir = Directory(root);
    if (!dir.existsSync()) return;
    // Deepest first, so emptied directories can be removed.
    final entries = dir.listSync(recursive: true, followLinks: false)
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final e in entries) {
      final rel = p.relative(e.path, from: root).replaceAll(r'\', '/');
      final kept = keepRelative.any(
        (k) => rel == k || rel.startsWith('$k/') || k.startsWith('$rel/'),
      );
      if (kept) continue;
      if (e is Directory) {
        if (e.listSync().isEmpty) e.deleteSync();
      } else {
        e.deleteSync();
      }
    }
  }
}
