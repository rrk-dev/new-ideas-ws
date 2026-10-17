import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

import '../fakes/fake_settings_store.dart';
import '../helpers/golden.dart';

class _Managed implements ManagedSettingsSource {
  const _Managed();

  @override
  Stream<ManagedSettings> watch() => Stream.value(
    const ManagedSettings(values: {'audio.retention': 'days_30'}),
  );
}

void main() {
  goldenTest(
    '[APP-03] Settings screen (one managed setting) [APP-08/AC4]',
    fileName: 'settings_screen',
    overrides: [
      settingsStoreProvider.overrideWith(
        (ref) => FakeSettingsStore({'audio.agc': false}),
      ),
      managedSettingsSourceProvider.overrideWithValue(const _Managed()),
      vaultTargetsProvider.overrideWith((ref) => Stream.value(const [])),
      routingRulesProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    builder: (_) => const SettingsScreen(),
  );
}
