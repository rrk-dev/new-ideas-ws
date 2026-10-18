import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/ask/domain/ask_availability.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';

void main() {
  test('[ASK-04/AC1] ask.enabled is off by default and history is on', () {
    expect(AppSettings.askEnabled.key, 'ask.enabled');
    expect(AppSettings.askEnabled.defaultValue, false);
    expect(AppSettings.askSaveHistory.key, 'ask.save_history');
    expect(AppSettings.askSaveHistory.defaultValue, true);
  });

  test('[ASK-04/AC1] only the High tier can ask, and only with the 3B', () {
    expect(
      askAvailability(tier: DeviceTier.high, modelInstalled: true),
      AskAvailability.ready,
    );
    expect(
      askAvailability(tier: DeviceTier.high, modelInstalled: false),
      AskAvailability.needsModel,
    );
    for (final tier in [DeviceTier.mid, DeviceTier.low, null]) {
      expect(
        askAvailability(tier: tier, modelInstalled: true),
        AskAvailability.deviceTooLow,
      );
    }
  });
}
