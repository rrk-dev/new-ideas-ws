// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_management_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every catalog model with install state, plan access, device fit,
/// recommendation and which one the pipeline uses (MDL-03).

@ProviderFor(modelEntries)
final modelEntriesProvider = ModelEntriesProvider._();

/// Every catalog model with install state, plan access, device fit,
/// recommendation and which one the pipeline uses (MDL-03).

final class ModelEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ModelEntry>>,
          List<ModelEntry>,
          FutureOr<List<ModelEntry>>
        >
    with $FutureModifier<List<ModelEntry>>, $FutureProvider<List<ModelEntry>> {
  /// Every catalog model with install state, plan access, device fit,
  /// recommendation and which one the pipeline uses (MDL-03).
  ModelEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelEntriesHash();

  @$internal
  @override
  $FutureProviderElement<List<ModelEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ModelEntry>> create(Ref ref) {
    return modelEntries(ref);
  }
}

String _$modelEntriesHash() => r'e43793cdad2f7a43bf55b99f13c4bbdff8b7d68b';

/// The model id the pipeline should load per type (null = none usable yet;
/// the job waits for a model). The pipeline wiring reads this.

@ProviderFor(activeModelIds)
final activeModelIdsProvider = ActiveModelIdsProvider._();

/// The model id the pipeline should load per type (null = none usable yet;
/// the job waits for a model). The pipeline wiring reads this.

final class ActiveModelIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<ModelType, String?>>,
          Map<ModelType, String?>,
          FutureOr<Map<ModelType, String?>>
        >
    with
        $FutureModifier<Map<ModelType, String?>>,
        $FutureProvider<Map<ModelType, String?>> {
  /// The model id the pipeline should load per type (null = none usable yet;
  /// the job waits for a model). The pipeline wiring reads this.
  ActiveModelIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeModelIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeModelIdsHash();

  @$internal
  @override
  $FutureProviderElement<Map<ModelType, String?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<ModelType, String?>> create(Ref ref) {
    return activeModelIds(ref);
  }
}

String _$activeModelIdsHash() => r'4bc75c0f2299b42d6eb9114785ecb3a7defcf472';

/// Storage used by models, audio and transcripts, updated live.

@ProviderFor(storageUsage)
final storageUsageProvider = StorageUsageProvider._();

/// Storage used by models, audio and transcripts, updated live.

final class StorageUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<StorageUsage>,
          StorageUsage,
          Stream<StorageUsage>
        >
    with $FutureModifier<StorageUsage>, $StreamProvider<StorageUsage> {
  /// Storage used by models, audio and transcripts, updated live.
  StorageUsageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageUsageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageUsageHash();

  @$internal
  @override
  $StreamProviderElement<StorageUsage> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StorageUsage> create(Ref ref) {
    return storageUsage(ref);
  }
}

String _$storageUsageHash() => r'880d97976b1d040d306f5dc532fa6fb29ba86556';

/// Model actions of the management screen.

@ProviderFor(modelManager)
final modelManagerProvider = ModelManagerProvider._();

/// Model actions of the management screen.

final class ModelManagerProvider
    extends $FunctionalProvider<ModelManager, ModelManager, ModelManager>
    with $Provider<ModelManager> {
  /// Model actions of the management screen.
  ModelManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelManagerHash();

  @$internal
  @override
  $ProviderElement<ModelManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelManager create(Ref ref) {
    return modelManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelManager>(value),
    );
  }
}

String _$modelManagerHash() => r'd4d57b2178e0b85abfc6c8ac433babbfa4808a3a';

/// The installer used for uninstalling (shares paths with the downloader).

@ProviderFor(modelInstaller)
final modelInstallerProvider = ModelInstallerProvider._();

/// The installer used for uninstalling (shares paths with the downloader).

final class ModelInstallerProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelInstaller>,
          ModelInstaller,
          FutureOr<ModelInstaller>
        >
    with $FutureModifier<ModelInstaller>, $FutureProvider<ModelInstaller> {
  /// The installer used for uninstalling (shares paths with the downloader).
  ModelInstallerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelInstallerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelInstallerHash();

  @$internal
  @override
  $FutureProviderElement<ModelInstaller> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelInstaller> create(Ref ref) {
    return modelInstaller(ref);
  }
}

String _$modelInstallerHash() => r'af30560d732448524748868e9a66169a766a0d1d';
