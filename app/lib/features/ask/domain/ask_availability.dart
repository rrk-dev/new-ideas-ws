import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Whether this device can run Ask right now (ADR-ASK-02, human decision
/// 2026-10-17): High-tier devices with the 3B model installed. The 1B is
/// never used for Ask.
enum AskAvailability {
  ready,

  /// High tier, 3B not installed: offer the download.
  needsModel,

  /// Mid/Low tier (or unknown hardware): "not available on this device".
  deviceTooLow,
}

AskAvailability askAvailability({
  required DeviceTier? tier,
  required bool modelInstalled,
}) {
  if (tier != DeviceTier.high) return AskAvailability.deviceTooLow;
  return modelInstalled ? AskAvailability.ready : AskAvailability.needsModel;
}
