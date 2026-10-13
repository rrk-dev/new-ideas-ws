// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(catalogVerifier)
final catalogVerifierProvider = CatalogVerifierProvider._();

final class CatalogVerifierProvider
    extends
        $FunctionalProvider<CatalogVerifier, CatalogVerifier, CatalogVerifier>
    with $Provider<CatalogVerifier> {
  CatalogVerifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogVerifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogVerifierHash();

  @$internal
  @override
  $ProviderElement<CatalogVerifier> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CatalogVerifier create(Ref ref) {
    return catalogVerifier(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogVerifier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogVerifier>(value),
    );
  }
}

String _$catalogVerifierHash() => r'82bb25157e8209253214be6a282f751b3a914aef';

/// In-memory until FND-04 lands a persistent store (follow-up MDL-05).

@ProviderFor(catalogStateStore)
final catalogStateStoreProvider = CatalogStateStoreProvider._();

/// In-memory until FND-04 lands a persistent store (follow-up MDL-05).

final class CatalogStateStoreProvider
    extends
        $FunctionalProvider<
          CatalogStateStore,
          CatalogStateStore,
          CatalogStateStore
        >
    with $Provider<CatalogStateStore> {
  /// In-memory until FND-04 lands a persistent store (follow-up MDL-05).
  CatalogStateStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogStateStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogStateStoreHash();

  @$internal
  @override
  $ProviderElement<CatalogStateStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogStateStore create(Ref ref) {
    return catalogStateStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogStateStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogStateStore>(value),
    );
  }
}

String _$catalogStateStoreHash() => r'2a92af688cd824e906ec52bf1f0f822a75733e04';

@ProviderFor(catalogRepository)
final catalogRepositoryProvider = CatalogRepositoryProvider._();

final class CatalogRepositoryProvider
    extends
        $FunctionalProvider<
          CatalogRepository,
          CatalogRepository,
          CatalogRepository
        >
    with $Provider<CatalogRepository> {
  CatalogRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogRepositoryHash();

  @$internal
  @override
  $ProviderElement<CatalogRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogRepository create(Ref ref) {
    return catalogRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogRepository>(value),
    );
  }
}

String _$catalogRepositoryHash() => r'7743f826d895245f7dfef3d88383dcb77e0f2f40';
