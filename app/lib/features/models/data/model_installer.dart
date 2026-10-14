import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart' as db;
import 'package:vaultvoice/core/db/repositories/models_repository.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/models/domain/download_platform.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Final step shared by the downloader (MDL-02) and offline import
/// (MDL-04): moves an already **verified** file into `models/<id>/<file>`
/// and records it in `models_installed`.
class ModelInstaller {
  ModelInstaller({
    required this._paths,
    required this._models,
    required this._device,
    this._clock = const SystemClock(),
  });

  final StoragePaths _paths;
  final ModelsRepository _models;
  final DownloadDeviceInfo _device;
  final Clock _clock;

  /// `models/.partial/` — staging area on the same volume as `models/`.
  String get stagingDir => p.join(_paths.modelsDir, '.partial');

  /// Staging file for [modelId].
  File stagingFile(String modelId) =>
      File(p.join(stagingDir, segment(modelId)));

  /// Renames [verified] (inside [stagingDir]) to `models/<id>/<file>` —
  /// atomic on one volume, replacing an older install of the same name —
  /// then upserts the row. On a DB failure the file is removed again.
  Future<Result<InstalledModelRow>> install(
    CatalogModel model,
    File verified,
  ) async {
    final dir = Directory(p.join(_paths.modelsDir, segment(model.id)));
    await dir.create(recursive: true);
    await _device.excludeFromBackup(_paths.modelsDir);
    await _device.excludeFromBackup(dir.path);
    final target = File(p.join(dir.path, model.file));
    await verified.rename(target.path);
    final row = await _models.upsert(
      ModelsInstalledCompanion.insert(
        id: model.id,
        type: dbType(model.type),
        version: model.version,
        path: _paths.relativize(target.path),
        sha256: model.sha256,
        size: model.size,
        installedAt: _clock.now(),
      ),
    );
    if (!row.isOk) {
      await target.delete();
      return Err(row.failureOrNull!);
    }
    // Drop files of an older version with a different file name.
    await for (final e in dir.list()) {
      if (e.path != target.path) await e.delete(recursive: true);
    }
    return await _models.get(model.id);
  }

  /// [id] as one path segment (catalog ids are already restricted).
  static String segment(String id) {
    if (id.isEmpty || id.contains('/') || id.contains(r'\') || id == '..') {
      throw ArgumentError.value(id, 'id', 'not a single path segment');
    }
    return id;
  }

  /// Catalog type → `models_installed.type`.
  static db.ModelType dbType(ModelType t) => switch (t) {
    ModelType.stt || ModelType.coremlEncoder => db.ModelType.stt,
    ModelType.llm => db.ModelType.llm,
    ModelType.vad => db.ModelType.vad,
    ModelType.diarizationSeg ||
    ModelType.diarizationEmb => db.ModelType.diarization,
  };
}
