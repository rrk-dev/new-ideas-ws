import 'dart:ui' show PlatformDispatcher;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/data/model_installer.dart';
import 'package:vaultvoice/features/models/data/model_state_providers.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_management.dart';
import 'package:vaultvoice/features/pipeline/domain/active_models.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';
import 'package:vaultvoice/features/transcription/domain/stt_model_policy.dart';

part 'model_management_providers.g.dart';

/// Every catalog model with install state, plan access, device fit,
/// recommendation and which one the pipeline uses (MDL-03).
@riverpod
Future<List<ModelEntry>> modelEntries(Ref ref) async {
  final catalog = await ref.watch(activeCatalogProvider.future);
  if (catalog == null) return const [];
  final installed = await ref.watch(installedModelsProvider.future);
  final device = await ref.watch(deviceProfileProvider.future);
  final bundle = await ref.watch(recommendedModelBundleProvider.future);
  final access = ref.watch(featureAccessStateProvider);
  final chosen = <ModelType, String?>{
    for (final type in kPipelineModelTypes)
      type: switch (await ref.watch(
        storedSettingProvider(ActiveModelKeys.forType(type)!).future,
      )) {
        final String id => id,
        _ => null,
      },
  };
  final deviceRamMb = device == null ? null : device.totalRamBytes ~/ (1 << 20);
  // The pipeline's own selector decides which models are active.
  final selection = selectActiveModels(
    installed: [
      for (final i in installed)
        if (catalog.byId(i.id)?.type ?? i.type case final type?
            when type == ModelType.stt || type == ModelType.llm)
          InstalledModelInfo(
            id: i.id,
            kind: type == ModelType.stt
                ? EngineModelKind.stt
                : EngineModelKind.llm,
            sizeBytes: i.size,
          ),
    ],
    access: ref.watch(featureAccessStateProvider),
    catalog: catalog,
    device: device,
    preferredStt: chosen[ModelType.stt],
    preferredLlm: chosen[ModelType.llm],
    sttLanguage: defaultSttLanguage(
      PlatformDispatcher.instance.locale.languageCode,
    ),
  );
  return buildModelEntries(
    activeIds: {?selection.stt, ?selection.llm},
    catalog: catalog,
    installed: installed,
    access: access.model,
    deviceRamMb: deviceRamMb,
    recommendedIds: {
      for (final m in bundle?.models ?? const <CatalogModel>[]) m.id,
    },
    chosen: chosen,
  );
}

/// The model id the pipeline should load per type (null = none usable yet;
/// the job waits for a model). The pipeline wiring reads this.
@riverpod
Future<Map<ModelType, String?>> activeModelIds(Ref ref) async {
  final entries = await ref.watch(modelEntriesProvider.future);
  return {
    for (final type in kPipelineModelTypes)
      type: entries
          .where((e) => e.model.type == type && e.active)
          .map((e) => e.model.id)
          .firstOrNull,
  };
}

/// Storage used by models, audio and transcripts, updated live.
@riverpod
Stream<StorageUsage> storageUsage(Ref ref) =>
    watchStorageUsage(ref.watch(vaultVoiceDatabaseProvider));

/// Sums from the DB: model sizes as installed, audio chunk bytes, and the
/// UTF-8 length of transcript text. Content-free (sizes only).
Stream<StorageUsage> watchStorageUsage(VaultVoiceDatabase db) => db
    .customSelect(
      'SELECT '
      '(SELECT COALESCE(SUM(size), 0) FROM models_installed) AS models, '
      '(SELECT COALESCE(SUM(bytes), 0) FROM audio_chunks) AS audio, '
      '(SELECT COALESCE(SUM(LENGTH(CAST(body AS BLOB))), 0) '
      'FROM transcript_segments) AS transcripts',
      readsFrom: {db.modelsInstalled, db.audioChunks, db.transcriptSegments},
    )
    .watchSingle()
    .map(
      (row) => StorageUsage(
        modelBytes: row.read<int>('models'),
        audioBytes: row.read<int>('audio'),
        transcriptBytes: row.read<int>('transcripts'),
      ),
    );

/// Model actions of the management screen.
@Riverpod(keepAlive: true)
ModelManager modelManager(Ref ref) => ModelManager(ref);

class ModelManager {
  ModelManager(this._ref);

  final Ref _ref;

  /// Makes [modelId] the model the pipeline uses for [type].
  Future<Result<void>> setActive(ModelType type, String modelId) {
    final key = ActiveModelKeys.forType(type);
    if (key == null) return Future.value(const Ok(null));
    return _ref.read(settingsStoreProvider).set(key, modelId);
  }

  /// Deletes [entry]'s files. When it is the active model, [replacement]
  /// (one of [DeleteWithReplacement.replacements]) becomes active first so
  /// the pipeline always has a usable model; an active model without a
  /// replacement is refused.
  Future<Result<void>> delete(
    ModelEntry entry,
    List<ModelEntry> entries, {
    ModelEntry? replacement,
  }) async {
    switch (planDeletion(entry, entries)) {
      case DeleteBlocked():
        return const Err(_lastModel);
      case DeleteWithReplacement(:final replacements):
        if (replacement == null ||
            !replacements.any((r) => r.model.id == replacement.model.id)) {
          return const Err(_lastModel);
        }
        final switched = await setActive(
          entry.model.type,
          replacement.model.id,
        );
        if (!switched.isOk) return switched;
      case DeleteFreely():
        break;
    }
    final downloader = await _ref.read(modelDownloaderProvider.future);
    await downloader.cancel(entry.model.id);
    final installer = await _ref.read(modelInstallerProvider.future);
    return await installer.uninstall(entry.model.id);
  }

  /// Refused: deleting would leave the pipeline without a model.
  static const StorageFailure _lastModel = kModelInUse;
}

/// Deleting would leave the pipeline without a usable model.
const kModelInUse = StorageFailure('model in use');

/// The installer used for uninstalling (shares paths with the downloader).
@Riverpod(keepAlive: true)
Future<ModelInstaller> modelInstaller(Ref ref) async => ModelInstaller(
  paths: await ref.watch(storagePathsProvider.future),
  models: ref.watch(modelsRepositoryProvider),
  device: ref.watch(modelDownloadPlatformProvider),
  clock: ref.watch(clockProvider),
);
