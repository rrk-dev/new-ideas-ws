import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Settings key the UI isolate publishes the resolved selection under; the
/// pipeline worker reads it at every heavy step (FND-11).
const String kActiveModelsKey = 'pipeline.active_models';

/// User's explicit choice of STT / LLM model (MDL-03 "set active" writes
/// these; a JSON string model id).
const String kPreferredSttModelKey = 'models.active_stt';
const String kPreferredLlmModelKey = 'models.active_llm';

/// Context size when the device tier is unknown (Low-tier value).
const int kFallbackLlmContext = 4096;

/// Kind of installed model the pipeline can run.
enum EngineModelKind { stt, llm }

/// An installed model as far as selection is concerned (`models_installed`
/// row; no paths — the worker resolves the file itself).
@immutable
final class InstalledModelInfo {
  const InstalledModelInfo({
    required this.id,
    required this.kind,
    required this.sizeBytes,
  });

  final String id;
  final EngineModelKind kind;
  final int sizeBytes;
}

/// The models the pipeline uses now (null = none usable ⇒ the step waits
/// with `model_missing`) and the LLM context for this device tier.
@immutable
final class ActiveModelSelection {
  const ActiveModelSelection({
    this.stt,
    this.llm,
    this.llmContext = kFallbackLlmContext,
  });

  /// Reads the published settings value; anything malformed is "none".
  factory ActiveModelSelection.fromJson(Object? json) {
    if (json is! Map) return const ActiveModelSelection();
    final stt = json['stt'];
    final llm = json['llm'];
    final ctx = json['llm_context'];
    return ActiveModelSelection(
      stt: stt is String && stt.isNotEmpty ? stt : null,
      llm: llm is String && llm.isNotEmpty ? llm : null,
      llmContext: ctx is int && ctx >= 512 ? ctx : kFallbackLlmContext,
    );
  }

  final String? stt;
  final String? llm;
  final int llmContext;

  String? idOf(EngineModelKind kind) => switch (kind) {
    EngineModelKind.stt => stt,
    EngineModelKind.llm => llm,
  };

  Map<String, Object?> toJson() => {
    'stt': stt,
    'llm': llm,
    'llm_context': llmContext,
  };

  @override
  bool operator ==(Object other) =>
      other is ActiveModelSelection &&
      other.stt == stt &&
      other.llm == llm &&
      other.llmContext == llmContext;

  @override
  int get hashCode => Object.hash(stt, llm, llmContext);

  @override
  String toString() => 'ActiveModelSelection($stt, $llm, $llmContext)';
}

/// Picks the active STT and LLM model from what is installed (FND-11).
///
/// A model is *usable* when the plan allows it (LIC-01
/// `FeatureAccess.model(tier, installed: true) == full`; large LLMs also
/// need `Feature.largeLlm`, LLM-07) and, when the catalog knows it, its
/// `min_ram_mb` fits the device. Per kind:
/// 1. the user's preferred model, if usable;
/// 2. else the LLM-07 tier × plan default ([defaultsFor]), if installed;
/// 3. else (PRODUCT-DECISION, conservative) the largest usable model
///    recommended for this device tier, else the smallest usable one.
///
/// Models unknown to the catalog (offline sideload, MDL-04) count as Free
/// tier; an LLM file above the 1B class size is "large".
ActiveModelSelection selectActiveModels({
  required List<InstalledModelInfo> installed,
  required FeatureAccess access,
  ModelCatalog? catalog,
  DeviceProfile? device,
  String? preferredStt,
  String? preferredLlm,
}) {
  final tier = device == null ? null : tierForRam(device.totalRamBytes);
  final ramMb = device == null ? null : device.totalRamBytes ~/ (1024 * 1024);
  final defaults = device == null || catalog == null
      ? null
      : defaultsFor(
          device,
          catalog,
          LlmPlanGate(largeLlm: () => access.has(Feature.largeLlm)),
        );

  bool usable(InstalledModelInfo m) {
    final c = catalog?.byId(m.id);
    if (access.model(c?.tier ?? ModelTier.free, installed: true) !=
        AccessLevel.full) {
      return false;
    }
    if (m.kind == EngineModelKind.llm && !access.has(Feature.largeLlm)) {
      final large = c != null ? isLargeLlm(c) : m.sizeBytes > kSmallLlmMaxBytes;
      if (large) return false;
    }
    if (c != null && ramMb != null && c.minRamMb > ramMb) return false;
    return true;
  }

  bool recommended(InstalledModelInfo m) {
    final c = catalog?.byId(m.id);
    return tier != null && c != null && c.recommendedDeviceTiers.contains(tier);
  }

  String? pick(EngineModelKind kind, String? preferred, String? tierDefault) {
    final candidates = [
      for (final m in installed)
        if (m.kind == kind && usable(m)) m,
    ];
    if (candidates.isEmpty) return null;
    for (final id in [preferred, tierDefault]) {
      if (id == null) continue;
      for (final m in candidates) {
        if (m.id == id) return m.id;
      }
    }
    int bySize(InstalledModelInfo a, InstalledModelInfo b) {
      final c = a.sizeBytes.compareTo(b.sizeBytes);
      return c != 0 ? c : a.id.compareTo(b.id);
    }

    final rec = candidates.where(recommended).toList()..sort(bySize);
    if (rec.isNotEmpty) return rec.last.id;
    return (candidates..sort(bySize)).first.id;
  }

  return ActiveModelSelection(
    stt: pick(EngineModelKind.stt, preferredStt, defaults?.stt?.id),
    llm: pick(EngineModelKind.llm, preferredLlm, defaults?.llm?.id),
    llmContext: tier == null ? kFallbackLlmContext : defaultContextFor(tier),
  );
}
