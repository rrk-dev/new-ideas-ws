// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_state_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Hardware facts for tiering (LLM-07 probe over the native bridge), or
/// null when the bridge cannot be loaded. Probed once per launch.

@ProviderFor(deviceProfile)
final deviceProfileProvider = DeviceProfileProvider._();

/// Hardware facts for tiering (LLM-07 probe over the native bridge), or
/// null when the bridge cannot be loaded. Probed once per launch.

final class DeviceProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceProfile?>,
          DeviceProfile?,
          FutureOr<DeviceProfile?>
        >
    with $FutureModifier<DeviceProfile?>, $FutureProvider<DeviceProfile?> {
  /// Hardware facts for tiering (LLM-07 probe over the native bridge), or
  /// null when the bridge cannot be loaded. Probed once per launch.
  DeviceProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceProfileHash();

  @$internal
  @override
  $FutureProviderElement<DeviceProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeviceProfile?> create(Ref ref) {
    return deviceProfile(ref);
  }
}

String _$deviceProfileHash() => r'0c0d71138dcd46fda64e5596f30604de96079c31';

/// The active signed catalog (bundled until a newer one was fetched), or
/// null when even the bundled catalog failed verification. [refresh]
/// fetches a newer signed catalog through the gateway (MDL-03 "Check for
/// updates"); a rejected or unreachable catalog keeps the current one.

@ProviderFor(ActiveCatalog)
final activeCatalogProvider = ActiveCatalogProvider._();

/// The active signed catalog (bundled until a newer one was fetched), or
/// null when even the bundled catalog failed verification. [refresh]
/// fetches a newer signed catalog through the gateway (MDL-03 "Check for
/// updates"); a rejected or unreachable catalog keeps the current one.
final class ActiveCatalogProvider
    extends $AsyncNotifierProvider<ActiveCatalog, ModelCatalog?> {
  /// The active signed catalog (bundled until a newer one was fetched), or
  /// null when even the bundled catalog failed verification. [refresh]
  /// fetches a newer signed catalog through the gateway (MDL-03 "Check for
  /// updates"); a rejected or unreachable catalog keeps the current one.
  ActiveCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeCatalogHash();

  @$internal
  @override
  ActiveCatalog create() => ActiveCatalog();
}

String _$activeCatalogHash() => r'51285766948eb9c24175929c357a5c8c00607664';

/// The active signed catalog (bundled until a newer one was fetched), or
/// null when even the bundled catalog failed verification. [refresh]
/// fetches a newer signed catalog through the gateway (MDL-03 "Check for
/// updates"); a rejected or unreachable catalog keeps the current one.

abstract class _$ActiveCatalog extends $AsyncNotifier<ModelCatalog?> {
  FutureOr<ModelCatalog?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ModelCatalog?>, ModelCatalog?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ModelCatalog?>, ModelCatalog?>,
              AsyncValue<ModelCatalog?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Recommended STT + LLM for this device and the current plan.

@ProviderFor(recommendedModelBundle)
final recommendedModelBundleProvider = RecommendedModelBundleProvider._();

/// Recommended STT + LLM for this device and the current plan.

final class RecommendedModelBundleProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelBundle?>,
          ModelBundle?,
          FutureOr<ModelBundle?>
        >
    with $FutureModifier<ModelBundle?>, $FutureProvider<ModelBundle?> {
  /// Recommended STT + LLM for this device and the current plan.
  RecommendedModelBundleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recommendedModelBundleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recommendedModelBundleHash();

  @$internal
  @override
  $FutureProviderElement<ModelBundle?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelBundle?> create(Ref ref) {
    return recommendedModelBundle(ref);
  }
}

String _$recommendedModelBundleHash() =>
    r'ed7a9c6be4753f06ee49844e65c1a5f4dcb9f81d';

/// Every installed model file (`models_installed`).

@ProviderFor(installedModels)
final installedModelsProvider = InstalledModelsProvider._();

/// Every installed model file (`models_installed`).

final class InstalledModelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InstalledModel>>,
          List<InstalledModel>,
          Stream<List<InstalledModel>>
        >
    with
        $FutureModifier<List<InstalledModel>>,
        $StreamProvider<List<InstalledModel>> {
  /// Every installed model file (`models_installed`).
  InstalledModelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedModelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedModelsHash();

  @$internal
  @override
  $StreamProviderElement<List<InstalledModel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<InstalledModel>> create(Ref ref) {
    return installedModels(ref);
  }
}

String _$installedModelsHash() => r'a5b3d45a68abe4f03a32c45b047e0328a8e7900f';

/// Latest progress of every download started in this process, by model id.

@ProviderFor(modelDownloadProgress)
final modelDownloadProgressProvider = ModelDownloadProgressProvider._();

/// Latest progress of every download started in this process, by model id.

final class ModelDownloadProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, DownloadProgress>>,
          Map<String, DownloadProgress>,
          Stream<Map<String, DownloadProgress>>
        >
    with
        $FutureModifier<Map<String, DownloadProgress>>,
        $StreamProvider<Map<String, DownloadProgress>> {
  /// Latest progress of every download started in this process, by model id.
  ModelDownloadProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelDownloadProgressProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelDownloadProgressHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, DownloadProgress>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, DownloadProgress>> create(Ref ref) {
    return modelDownloadProgress(ref);
  }
}

String _$modelDownloadProgressHash() =>
    r'762214bd769ac690636b30d63991768c927eb3f6';
