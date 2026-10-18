import 'package:vaultvoice/features/licensing/data/managed_config_source.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

/// Settings' view of the MDM configuration: forced values (`force_app_lock`,
/// `network_disabled`, `audio_retention_days`) and locked keys
/// (`lock_settings`).
class ManagedConfigSettingsSource implements ManagedSettingsSource {
  const ManagedConfigSettingsSource(this._config);

  final ManagedConfigSource _config;

  @override
  Stream<ManagedSettings> watch() =>
      _config.watch().map((c) => c.toManagedSettings());
}
