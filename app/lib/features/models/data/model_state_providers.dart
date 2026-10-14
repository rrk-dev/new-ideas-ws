import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/extraction/data/device_profile_probe.dart';
import 'package:vaultvoice/features/extraction/data/native_device_capabilities.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/models/data/catalog_providers.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/models/domain/download_state.dart';
import 'package:vaultvoice/features/models/domain/installed_model.dart';
import 'package:vaultvoice/features/models/domain/model_bundle.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vv_native/vv_native.dart';

part 'model_state_providers.g.dart';

/// Hardware facts for tiering (LLM-07 probe over the native bridge), or
/// null when the bridge cannot be loaded. Probed once per launch.
@Riverpod(keepAlive: true)
Future<DeviceProfile?> deviceProfile(Ref ref) async {
  try {
    final native = VvNative.open();
    return NativeDeviceProfileProbe(
      native,
      NativeDeviceCapabilities(native),
    ).probe();
  } on Object {
    return null;
  }
}

/// The active signed catalog (bundled until a newer one was fetched), or
/// null when even the bundled catalog failed verification. [refresh]
/// fetches a newer signed catalog through the gateway (MDL-03 "Check for
/// updates"); a rejected or unreachable catalog keeps the current one.
@Riverpod(keepAlive: true)
class ActiveCatalog extends _$ActiveCatalog {
  @override
  Future<ModelCatalog?> build() async {
    final repo = ref.watch(catalogRepositoryProvider);
    return repo.current ?? (await repo.loadBundled()).valueOrNull;
  }

  Future<Result<ModelCatalog>> refresh() async {
    final result = await ref.read(catalogRepositoryProvider).refresh();
    if (result case Ok(:final value)) state = AsyncData(value);
    return result;
  }
}

/// Recommended STT + LLM for this device and the current plan.
@riverpod
Future<ModelBundle?> recommendedModelBundle(Ref ref) async {
  // Recompute when the plan changes (e.g. Pro unlocks the large LLM).
  ref.watch(featureAccessStateProvider);
  final catalog = await ref.watch(activeCatalogProvider.future);
  if (catalog == null) return null;
  final device = await ref.watch(deviceProfileProvider.future);
  return recommendBundle(
    device,
    catalog,
    LlmPlanGate.entitlements(ref.read(entitlementServiceProvider)),
  );
}

/// Every installed model file (`models_installed`).
@riverpod
Stream<List<InstalledModel>> installedModels(Ref ref) => ref
    .watch(modelsRepositoryProvider)
    .watchAll()
    .map(
      (rows) => [
        for (final r in rows)
          InstalledModel(
            id: r.id,
            version: r.version,
            size: r.size,
            relativePath: r.path,
            installedAt: r.installedAt,
          ),
      ],
    );

/// Latest progress of every download started in this process, by model id.
@Riverpod(keepAlive: true)
Stream<Map<String, DownloadProgress>> modelDownloadProgress(Ref ref) async* {
  final downloader = await ref.watch(modelDownloaderProvider.future);
  var latest = const <String, DownloadProgress>{};
  yield latest;
  await for (final p in downloader.progress) {
    latest = {...latest, p.modelId: p};
    yield latest;
  }
}
