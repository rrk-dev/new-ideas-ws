// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(purchaseStore)
final purchaseStoreProvider = PurchaseStoreProvider._();

final class PurchaseStoreProvider
    extends $FunctionalProvider<PurchaseStore, PurchaseStore, PurchaseStore>
    with $Provider<PurchaseStore> {
  PurchaseStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchaseStoreHash();

  @$internal
  @override
  $ProviderElement<PurchaseStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PurchaseStore create(Ref ref) {
    return purchaseStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PurchaseStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PurchaseStore>(value),
    );
  }
}

String _$purchaseStoreHash() => r'6edfbfa97f8cdb77df1f9a8666021642aeb06048';

@ProviderFor(purchaseService)
final purchaseServiceProvider = PurchaseServiceProvider._();

final class PurchaseServiceProvider
    extends
        $FunctionalProvider<PurchaseService, PurchaseService, PurchaseService>
    with $Provider<PurchaseService> {
  PurchaseServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchaseServiceHash();

  @$internal
  @override
  $ProviderElement<PurchaseService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PurchaseService create(Ref ref) {
    return purchaseService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PurchaseService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PurchaseService>(value),
    );
  }
}

String _$purchaseServiceHash() => r'381a5ed32b3ddc40c95e3d2c376253f991d39ac2';

@ProviderFor(storeProducts)
final storeProductsProvider = StoreProductsProvider._();

final class StoreProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StoreProduct>>,
          List<StoreProduct>,
          FutureOr<List<StoreProduct>>
        >
    with
        $FutureModifier<List<StoreProduct>>,
        $FutureProvider<List<StoreProduct>> {
  StoreProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<StoreProduct>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StoreProduct>> create(Ref ref) {
    return storeProducts(ref);
  }
}

String _$storeProductsHash() => r'4ef2824e5d65e5f5f377571130280f828c7f40b0';
