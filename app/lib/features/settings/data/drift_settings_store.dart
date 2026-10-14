import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

/// [SettingsStore] on the FND-04 `settings` table.
class DriftSettingsStore implements SettingsStore {
  const DriftSettingsStore(this.repository);

  final SettingsRepository repository;

  @override
  Stream<Object?> watch(String key) => repository.watch(key);

  @override
  Future<Result<void>> set(String key, Object? value) =>
      repository.set(key, value);
}
