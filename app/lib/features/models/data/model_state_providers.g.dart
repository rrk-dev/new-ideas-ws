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
/// null when even the bundled catalog failed verification.

@ProviderFor(activeCatalog)
final activeCatalogProvider = ActiveCatalogProvider._();

/// The active signed catalog (bundled until a newer one was fetched), or
/// null when even the bundled catalog failed verification.

final class ActiveCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelCatalog?>,
          ModelCatalog?,
          FutureOr<ModelCatalog?>
        >
    with $FutureModifier<ModelCatalog?>, $FutureProvider<ModelCatalog?> {
  /// The active signed catalog (bundled until a newer one was fetched), or
  /// null when even the bundled catalog failed verification.
  ActiveCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeCatalogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeCatalogHash();

  @$internal
  @override
  $FutureProviderElement<ModelCatalog?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelCatalog?> create(Ref ref) {
    return activeCatalog(ref);
  }
}

String _$activeCatalogHash() => r'0776c6632ec8277ec8438dc07538aed365a0fe99';

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
    r'b98fefec8406fde1f09eba33d718faf18471ca6a';

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

String _$installedModelsHash() => r'c77a576a646b9b74d2064262d50d2bc8e5420fca';

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
