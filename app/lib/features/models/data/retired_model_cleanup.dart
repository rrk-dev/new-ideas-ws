import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/repositories/models_repository.dart';
import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';

/// Models that older builds shipped and the catalog no longer offers
/// (ADR-LLM-08 replaced the Qwen default). Only ids listed here are purged:
/// a model from a newer signed catalog or a user-sideloaded `custom-…` model
/// must never be removed just because the bundled catalog does not know it.
const Set<String> kRetiredModelIds = {'qwen2.5-0.5b-instruct-q4_k_m'};

/// One-time, idempotent cleanup of [kRetiredModelIds]: removes the
/// `models_installed` row, the files under `models/<id>/` and the
/// `models.active_*` setting that pointed at it. Returns the ids removed.
Future<List<String>> purgeRetiredModels({
  required ModelsRepository models,
  required SettingsRepository settings,
  required StoragePaths paths,
  Set<String> retired = kRetiredModelIds,
}) async {
  final removed = <String>[];
  for (final id in retired) {
    if (id.isEmpty || id.contains('/') || id.contains(r'\') || id == '..') {
      continue;
    }
    final row = await models.get(id);
    final dir = Directory(p.join(paths.modelsDir, id));
    final rowExists = row.isOk;
    if (!rowExists && !dir.existsSync()) continue;
    if (rowExists) await models.deleteById(id);
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Left for the next launch; the row is already gone.
    }
    for (final key in [ActiveModelKeys.llm, ActiveModelKeys.stt]) {
      final active = await settings.get(key);
      if (active.valueOrNull == id) await settings.remove(key);
    }
    removed.add(id);
  }
  return removed;
}
