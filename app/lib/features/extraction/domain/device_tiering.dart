import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/platform/device_capabilities.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement_service.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/transcription/domain/stt_model_policy.dart';

/// Thermal state reported by the OS (iOS `ProcessInfo.thermalState`,
/// Android `PowerManager.getCurrentThermalStatus`). [unknown] until the
/// platform source is wired (LLM-07 follow-up).
enum ThermalState { nominal, fair, serious, critical, unknown }

/// What the capability probe found (hardware facts only, no content).
@immutable
final class DeviceProfile {
  const DeviceProfile({
    required this.platform,
    required this.osVersion,
    required this.totalRamBytes,
    required this.availableRamBytes,
    this.gpus = const [],
    this.perfCores = 4,
    this.cpuSupported = true,
    this.thermal = ThermalState.unknown,
  });

  final String platform; // 'ios' | 'android' | 'host'
  final String osVersion;
  final int totalRamBytes;
  final int availableRamBytes;
  final List<GpuDevice> gpus;
  final int perfCores;
  final bool cpuSupported;
  final ThermalState thermal;

  bool get isAndroid => platform == 'android';
  bool get isIos => platform == 'ios';
}

const int _gib = 1024 * 1024 * 1024;

/// Tier from the RAM the OS reports (vv-llm-inference → Memory math &
/// tiers): Low < 5 GiB (iPhone 11 / 4 GB phones report ≈ 3.7), Mid 5–7 GiB
/// (6 GB devices report ≈ 5.6), High ≥ 7 GiB (8 GB devices report ≈ 7.3).
DeviceTier tierForRam(int totalRamBytes) {
  if (totalRamBytes < 5 * _gib) return DeviceTier.low;
  if (totalRamBytes < 7 * _gib) return DeviceTier.mid;
  return DeviceTier.high;
}

/// Context size per tier for the tier's default LLM.
int defaultContextFor(DeviceTier tier) => switch (tier) {
  DeviceTier.low => 4096,
  DeviceTier.mid => 6144,
  DeviceTier.high => 8192,
};

/// Plan gate for the LLM size class, backed by LIC-01's
/// `EntitlementService.has(Feature.largeLlm)` ([LlmPlanGate.entitlements],
/// integration wave 2).
@immutable
final class LlmPlanGate {
  const LlmPlanGate({required this.largeLlm});

  /// The real gate: evaluated on every call, so plan changes / expiry apply.
  factory LlmPlanGate.entitlements(EntitlementService entitlements) =>
      LlmPlanGate(largeLlm: () => entitlements.has(Feature.largeLlm));

  /// Free plan (tests; commercial Free resolves to the same via LIC-01).
  factory LlmPlanGate.free() => LlmPlanGate(largeLlm: () => false);

  /// Free plan → false: capped at the 1B-class model on every tier.
  final bool Function() largeLlm;
}

/// Default models + context for one device and plan.
@immutable
final class TierDefaults {
  const TierDefaults({
    required this.tier,
    required this.contextSize,
    this.llm,
    this.stt,
  });

  final DeviceTier tier;
  final CatalogModel? llm;
  final CatalogModel? stt;
  final int contextSize;
}

/// "1B class" = LLM files up to 1.2 GB (Llama-3.2-1B Q4_K_M ≈ 0.8 GB,
/// Qwen2.5-0.5B ≈ 0.5 GB); 3B Q4 ≈ 1.9–2.0 GB is "large".
const int kSmallLlmMaxBytes = 1200 * 1000 * 1000;

bool isLargeLlm(CatalogModel m) =>
    m.type == ModelType.llm &&
    (m.size > kSmallLlmMaxBytes || m.tier != ModelTier.free);

/// Picks the tier × plan defaults from the signed catalog: the largest model
/// of each type that is recommended for the tier, allowed by the plan
/// (Free ⇒ no large LLM, no Pro/Enterprise models), and whose `min_ram_mb`
/// fits the device. LLM-08 decides *which* models the catalog lists.
///
/// With [stt] (integration W3) the STT default is STT-07's
/// [recommendedSttModel] for [sttLanguage] (benchmarked preference lists,
/// size-class entitlements); it falls back to the largest recommended Free
/// STT model when the catalog has none of those variants.
TierDefaults defaultsFor(
  DeviceProfile device,
  ModelCatalog catalog,
  LlmPlanGate plan, {
  SttPlanGate? stt,
  String sttLanguage = 'en',
}) {
  final tier = tierForRam(device.totalRamBytes);
  final ramMb = device.totalRamBytes ~/ (1024 * 1024);
  final large = plan.largeLlm();
  CatalogModel? pick(ModelType type) {
    final ok = catalog.models.where(
      (m) =>
          m.type == type &&
          m.recommendedDeviceTiers.contains(tier) &&
          m.minRamMb <= ramMb &&
          (large || (m.tier == ModelTier.free && !isLargeLlm(m))),
    );
    if (ok.isEmpty) return null;
    return ok.reduce((a, b) => a.size >= b.size ? a : b);
  }

  final llm = pick(ModelType.llm);
  return TierDefaults(
    tier: tier,
    llm: llm,
    stt:
        (stt == null
            ? null
            : recommendedSttModel(
                tier: tier,
                totalRamMb: ramMb,
                language: sttLanguage,
                catalog: catalog,
                gate: stt,
              )) ??
        pick(ModelType.stt),
    contextSize: defaultContextFor(tier),
  );
}
