import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// RAM assumed when the capability probe is unavailable: a 4 GB phone, the
/// smallest supported class, so the recommendation never overshoots.
const int kAssumedRamBytes = 4 * 1024 * 1024 * 1024;

/// The models recommended for this device and plan (LLM-07 tier defaults
/// over the signed MDL-01 catalog), shown with their sizes before anything
/// is downloaded (onboarding, model management).
@immutable
final class ModelBundle {
  const ModelBundle({
    required this.tier,
    required this.deviceKnown,
    required this.totalRamBytes,
    required this.models,
  });

  final DeviceTier tier;

  /// False when the probe failed and [kAssumedRamBytes] was used.
  final bool deviceKnown;
  final int totalRamBytes;

  /// Speech-to-text first, then the LLM (whichever the catalog offers).
  final List<CatalogModel> models;

  int get totalBytes => models.fold(0, (sum, m) => sum + m.size);

  /// Bytes still to download when [installedIds] are already on disk.
  int remainingBytes(Set<String> installedIds) => models
      .where((m) => !installedIds.contains(m.id))
      .fold(0, (sum, m) => sum + m.size);

  bool isComplete(Set<String> installedIds) =>
      models.every((m) => installedIds.contains(m.id));
}

/// Picks the recommended STT + LLM for [device] (null = unknown device,
/// treated as a 4 GB phone) under [plan].
ModelBundle recommendBundle(
  DeviceProfile? device,
  ModelCatalog catalog,
  LlmPlanGate plan,
) {
  final profile =
      device ??
      const DeviceProfile(
        platform: 'unknown',
        osVersion: '',
        totalRamBytes: kAssumedRamBytes,
        availableRamBytes: kAssumedRamBytes,
      );
  final defaults = defaultsFor(profile, catalog, plan);
  return ModelBundle(
    tier: defaults.tier,
    deviceKnown: device != null,
    totalRamBytes: profile.totalRamBytes,
    models: [?defaults.stt, ?defaults.llm],
  );
}
