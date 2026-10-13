import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_guard.dart';
import 'package:vaultvoice/core/db/tables/settings_tables.dart';
import 'package:vaultvoice/core/errors/result.dart';

part 'settings_repository.g.dart';

/// Key/value settings. Values are any JSON-encodable object.
@DriftAccessor(tables: [Settings])
class SettingsRepository extends DatabaseAccessor<VaultVoiceDatabase>
    with _$SettingsRepositoryMixin {
  SettingsRepository(super.attachedDatabase);

  Future<Result<void>> set(String key, Object? value) => guardDb(
    () => into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: jsonEncode(value)),
    ),
  );

  /// The decoded value, or null when [key] is unset.
  Future<Result<Object?>> get(String key) =>
      guardDb(() async => _decode(await _byKey(key).getSingleOrNull()));

  Stream<Object?> watch(String key) =>
      _byKey(key).watchSingleOrNull().map(_decode);

  Stream<Map<String, Object?>> watchAll() =>
      select(settings)
          .watch()
          .map((rows) => {for (final r in rows) r.key: jsonDecode(r.value)});

  /// Removing an unset key is not an error.
  Future<Result<void>> remove(String key) =>
      guardDb(() => (delete(settings)..where((s) => s.key.equals(key))).go());

  SimpleSelectStatement<$SettingsTable, SettingRow> _byKey(String key) =>
      select(settings)..where((s) => s.key.equals(key));

  static Object? _decode(SettingRow? row) =>
      row == null ? null : jsonDecode(row.value);
}
