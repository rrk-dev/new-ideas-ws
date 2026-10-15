// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'engine_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Hardware facts for model selection (LLM-07); null when the bridge
/// cannot be loaded (selection then ignores the device tier).

@ProviderFor(deviceProfile)
final deviceProfileProvider = DeviceProfileProvider._();

/// Hardware facts for model selection (LLM-07); null when the bridge
/// cannot be loaded (selection then ignores the device tier).

final class DeviceProfileProvider
    extends $FunctionalProvider<DeviceProfile?, DeviceProfile?, DeviceProfile?>
    with $Provider<DeviceProfile?> {
  /// Hardware facts for model selection (LLM-07); null when the bridge
  /// cannot be loaded (selection then ignores the device tier).
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
  $ProviderElement<DeviceProfile?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceProfile? create(Ref ref) {
    return deviceProfile(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceProfile? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceProfile?>(value),
    );
  }
}

String _$deviceProfileHash() => r'93e4a4b28449a3dbaa1c831ba63c55c9dd53551d';

/// The app's own vault folder (default/fallback target): Android
/// `filesDir/vault`, iOS `Documents/` (EXP-03/EXP-04 host APIs); elsewhere
/// `<storage root>/vault`.

@ProviderFor(appLocalVaultRoot)
final appLocalVaultRootProvider = AppLocalVaultRootProvider._();

/// The app's own vault folder (default/fallback target): Android
/// `filesDir/vault`, iOS `Documents/` (EXP-03/EXP-04 host APIs); elsewhere
/// `<storage root>/vault`.

final class AppLocalVaultRootProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The app's own vault folder (default/fallback target): Android
  /// `filesDir/vault`, iOS `Documents/` (EXP-03/EXP-04 host APIs); elsewhere
  /// `<storage root>/vault`.
  AppLocalVaultRootProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocalVaultRootProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocalVaultRootHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appLocalVaultRoot(ref);
  }
}

String _$appLocalVaultRootHash() => r'298ef44eaf0e4bb8ad0f19c263e6bcbb5263ac6b';

/// Everything the production worker factory needs, read on the UI isolate
/// before the worker starts (FND-11): built-in profile/template asset text,
/// the app-local vault root, the metrics file and the lifecycle state.

@ProviderFor(productionEngineSpec)
final productionEngineSpecProvider = ProductionEngineSpecProvider._();

/// Everything the production worker factory needs, read on the UI isolate
/// before the worker starts (FND-11): built-in profile/template asset text,
/// the app-local vault root, the metrics file and the lifecycle state.

final class ProductionEngineSpecProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProductionEngineSpec>,
          ProductionEngineSpec,
          FutureOr<ProductionEngineSpec>
        >
    with
        $FutureModifier<ProductionEngineSpec>,
        $FutureProvider<ProductionEngineSpec> {
  /// Everything the production worker factory needs, read on the UI isolate
  /// before the worker starts (FND-11): built-in profile/template asset text,
  /// the app-local vault root, the metrics file and the lifecycle state.
  ProductionEngineSpecProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productionEngineSpecProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productionEngineSpecHash();

  @$internal
  @override
  $FutureProviderElement<ProductionEngineSpec> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProductionEngineSpec> create(Ref ref) {
    return productionEngineSpec(ref);
  }
}

String _$productionEngineSpecHash() =>
    r'b55c00df2a35f7a75848a7656f25639d1de17b5d';

/// Publishes the active STT/LLM selection for the worker (FND-11).

@ProviderFor(activeModelsPublisher)
final activeModelsPublisherProvider = ActiveModelsPublisherProvider._();

/// Publishes the active STT/LLM selection for the worker (FND-11).

final class ActiveModelsPublisherProvider
    extends
        $FunctionalProvider<
          ActiveModelsPublisher,
          ActiveModelsPublisher,
          ActiveModelsPublisher
        >
    with $Provider<ActiveModelsPublisher> {
  /// Publishes the active STT/LLM selection for the worker (FND-11).
  ActiveModelsPublisherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeModelsPublisherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeModelsPublisherHash();

  @$internal
  @override
  $ProviderElement<ActiveModelsPublisher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActiveModelsPublisher create(Ref ref) {
    return activeModelsPublisher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveModelsPublisher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveModelsPublisher>(value),
    );
  }
}

String _$activeModelsPublisherHash() =>
    r'a3f2d8e351e7026bd6d6537f3b846c0b84b758fd';
