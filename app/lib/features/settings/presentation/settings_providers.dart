import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/settings/data/drift_settings_store.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

part 'settings_providers.g.dart';

/// Organisation-managed settings; LIC-04 overrides the source.
@Riverpod(keepAlive: true)
ManagedSettingsSource managedSettingsSource(Ref ref) =>
    const NoManagedSettings();

@Riverpod(keepAlive: true)
Stream<ManagedSettings> managedSettings(Ref ref) =>
    ref.watch(managedSettingsSourceProvider).watch();

/// Licence summary + actions; LIC-01/02/03 override the port.
@Riverpod(keepAlive: true)
LicenseSettingsPort licenseSettingsPort(Ref ref) =>
    const UnavailableLicensePort();

@riverpod
Stream<LicenseSummary> licenseSummary(Ref ref) =>
    ref.watch(licenseSettingsPortProvider).watch();

/// "Delete all data"; SEC-04 overrides it with the secure wipe.
@Riverpod(keepAlive: true)
DataWiper dataWiper(Ref ref) => const UnavailableDataWiper();

/// The effective value of a setting and whether the user may change it.
class SettingState {
  const SettingState({required this.value, required this.managed});

  final Object value;

  /// Enforced or locked by the organisation: shown read-only.
  final bool managed;
}

/// Where user settings live: the FND-04 `settings` table.
@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) =>
    DriftSettingsStore(ref.watch(settingsRepositoryProvider));

/// The user's stored value of [key] (raw JSON, null when unset).
@riverpod
Stream<Object?> storedSetting(Ref ref, String key) =>
    ref.watch(settingsStoreProvider).watch(key);

/// Effective value: managed value › user value › default.
@riverpod
Future<SettingState> settingState(Ref ref, String key) async {
  final def = AppSettings.byKey(key);
  if (def == null) throw ArgumentError.value(key, 'key', 'unknown setting');
  final managed = await ref.watch(managedSettingsProvider.future);
  final stored = await ref.watch(storedSettingProvider(key).future);
  final forced = managed.values.containsKey(key) ? managed.values[key] : stored;
  return SettingState(
    value: def.decode(forced),
    managed: managed.isManaged(key),
  );
}

/// Writes settings; refuses managed keys and invalid values.
@Riverpod(keepAlive: true)
SettingsWriter settingsWriter(Ref ref) => SettingsWriter(ref);

class SettingsWriter {
  SettingsWriter(this._ref);

  final Ref _ref;

  Future<Result<void>> set(SettingDef<Object> def, Object value) async {
    // The source directly: an unlistened provider is paused (Riverpod 3).
    final source = _ref.read(managedSettingsSourceProvider);
    final managed = await source.watch().first;
    if (managed.isManaged(def.key)) {
      return const Err(PermissionFailure('managed setting'));
    }
    if (!def.accepts(value)) {
      return const Err(UnexpectedFailure('invalid setting value'));
    }
    return await _ref.read(settingsStoreProvider).set(def.key, value);
  }
}

/// A vault target as Settings shows it. [name] and [handle] are user
/// content / locations: displayed, never logged.
class VaultTargetInfo {
  const VaultTargetInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.handle,
  });

  final String id;
  final String name;
  final VaultPlatform platform;
  final String handle;
}

/// A routing rule as Settings lists it.
class RoutingRuleInfo {
  const RoutingRuleInfo({
    required this.id,
    required this.targetId,
    required this.subPath,
  });

  final String id;
  final String targetId;
  final String subPath;
}

/// Vault targets, oldest first (Settings → Export → Vault folders).
@riverpod
Stream<List<VaultTargetInfo>> vaultTargets(Ref ref) => ref
    .watch(vaultRepositoryProvider)
    .watchTargets()
    .map(
      (rows) => [
        for (final r in rows)
          VaultTargetInfo(
            id: r.id,
            name: r.displayName,
            platform: r.platform,
            handle: r.handle,
          ),
      ],
    );

/// Routing rules in evaluation order.
@riverpod
Stream<List<RoutingRuleInfo>> routingRules(Ref ref) => ref
    .watch(vaultRepositoryProvider)
    .watchRules()
    .map(
      (rows) => [
        for (final r in rows)
          RoutingRuleInfo(id: r.id, targetId: r.targetId, subPath: r.subPath),
      ],
    );
