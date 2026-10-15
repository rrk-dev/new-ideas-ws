import 'package:flutter/foundation.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// `settings` keys holding the model the pipeline uses per type (MDL-03).
/// FND-11's production engine factory reads exactly these names (value =
/// a `models_installed` id) and falls back to the LLM-07 tier default.
abstract final class ActiveModelKeys {
  static const stt = 'models.active_stt';
  static const llm = 'models.active_llm';

  /// Key for [type], or null for types without a user choice (VAD,
  /// diarization and accelerators follow their pipeline model).
  static String? forType(ModelType type) => switch (type) {
    ModelType.stt => stt,
    ModelType.llm => llm,
    _ => null,
  };
}

/// Types the pipeline cannot run without (transcribe, extract).
const List<ModelType> kPipelineModelTypes = [ModelType.stt, ModelType.llm];

/// One row of the model management list.
@immutable
final class ModelEntry {
  const ModelEntry({
    required this.model,
    required this.installed,
    required this.access,
    required this.compatible,
    required this.recommended,
    required this.active,
  });

  /// Catalog entry (latest version the catalog offers).
  final CatalogModel model;

  /// On-disk install, if any (its version may be older than [model]).
  final InstalledModel? installed;

  /// Plan access (LIC-01): full, readOnly (installed but not selectable
  /// after a downgrade) or disabled (cannot be downloaded).
  final AccessLevel access;

  /// `min_ram_mb` fits this device.
  final bool compatible;

  /// Part of the tier recommendation (LLM-07).
  final bool recommended;

  /// The model the pipeline uses for its type.
  final bool active;

  bool get isInstalled => installed != null;

  /// Usable by the pipeline: installed, allowed by the plan, fits the device.
  bool get usable => isInstalled && access == AccessLevel.full && compatible;

  /// The catalog lists a newer version than the installed one.
  bool get updateAvailable =>
      installed != null && isNewerVersion(model.version, installed!.version);
}

/// Whether catalog [candidate] is newer than [installed]: numeric when both
/// are integers / dotted integers, otherwise any difference counts.
bool isNewerVersion(String candidate, String installed) {
  if (candidate == installed) return false;
  List<int>? parts(String v) {
    final out = <int>[];
    for (final p in v.split('.')) {
      final n = int.tryParse(p);
      if (n == null) return null;
      out.add(n);
    }
    return out;
  }

  final a = parts(candidate);
  final b = parts(installed);
  if (a == null || b == null) return true;
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// The model the pipeline uses for [type]: the user's choice when it is
/// still usable, else the installed recommended model, else the first
/// usable installed model in catalog order; null when nothing usable is
/// installed (the pipeline then waits for a model).
String? resolveActiveModel({
  required ModelType type,
  required String? chosen,
  required List<ModelEntry> entries,
}) {
  final usable = [
    for (final e in entries)
      if (e.model.type == type && e.usable) e,
  ];
  if (usable.isEmpty) return null;
  for (final e in usable) {
    if (e.model.id == chosen) return e.model.id;
  }
  for (final e in usable) {
    if (e.recommended) return e.model.id;
  }
  return usable.first.model.id;
}

/// Builds the management list: every catalog model in catalog order.
/// Installed models the catalog no longer lists are not shown (they cannot
/// be verified or updated).
List<ModelEntry> buildModelEntries({
  required ModelCatalog catalog,
  required List<InstalledModel> installed,
  required AccessLevel Function(ModelTier tier, {required bool installed})
  access,
  required int? deviceRamMb,
  required Set<String> recommendedIds,
  required Map<ModelType, String?> chosen,
}) {
  final byId = {for (final i in installed) i.id: i};
  final base = [
    for (final m in catalog.models)
      // Core ML encoders install with their STT model (iOS companions).
      if (m.type != ModelType.coremlEncoder)
        ModelEntry(
          model: m,
          installed: byId[m.id],
          access: access(m.tier, installed: byId.containsKey(m.id)),
          compatible: deviceRamMb == null || m.minRamMb <= deviceRamMb,
          recommended: recommendedIds.contains(m.id),
          active: false,
        ),
  ];
  final active = {
    for (final type in kPipelineModelTypes)
      ?resolveActiveModel(type: type, chosen: chosen[type], entries: base),
  };
  return [
    for (final e in base)
      ModelEntry(
        model: e.model,
        installed: e.installed,
        access: e.access,
        compatible: e.compatible,
        recommended: e.recommended,
        active: active.contains(e.model.id),
      ),
  ];
}

/// What deleting a model requires so the pipeline never loses its model.
sealed class DeletionPlan {
  const DeletionPlan();
}

/// Not the active model (or not a pipeline type): delete directly.
final class DeleteFreely extends DeletionPlan {
  const DeleteFreely();
}

/// The active model: the user must pick one of [replacements] first.
final class DeleteWithReplacement extends DeletionPlan {
  const DeleteWithReplacement(this.replacements);

  final List<ModelEntry> replacements;
}

/// The only usable model of its type: deleting it would leave the pipeline
/// without a model, so it is refused until another one is installed.
final class DeleteBlocked extends DeletionPlan {
  const DeleteBlocked();
}

DeletionPlan planDeletion(ModelEntry target, List<ModelEntry> entries) {
  if (!target.active || !kPipelineModelTypes.contains(target.model.type)) {
    return const DeleteFreely();
  }
  final replacements = [
    for (final e in entries)
      if (e.model.type == target.model.type &&
          e.model.id != target.model.id &&
          e.usable)
        e,
  ];
  return replacements.isEmpty
      ? const DeleteBlocked()
      : DeleteWithReplacement(replacements);
}

/// Bytes on disk per content kind (Settings › Models storage summary).
@immutable
final class StorageUsage {
  const StorageUsage({
    required this.modelBytes,
    required this.audioBytes,
    required this.transcriptBytes,
  });

  final int modelBytes;
  final int audioBytes;

  /// UTF-8 size of the transcript text (DB rows, not counting indexes).
  final int transcriptBytes;
}
