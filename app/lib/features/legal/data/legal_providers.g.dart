// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legal_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the user still has to accept the current [kLegalVersion]. Unknown
/// (settings still loading) never blocks. Existing users have no record, so
/// they are asked once.

@ProviderFor(legalAcceptanceRequired)
final legalAcceptanceRequiredProvider = LegalAcceptanceRequiredProvider._();

/// Whether the user still has to accept the current [kLegalVersion]. Unknown
/// (settings still loading) never blocks. Existing users have no record, so
/// they are asked once.

final class LegalAcceptanceRequiredProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether the user still has to accept the current [kLegalVersion]. Unknown
  /// (settings still loading) never blocks. Existing users have no record, so
  /// they are asked once.
  LegalAcceptanceRequiredProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'legalAcceptanceRequiredProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$legalAcceptanceRequiredHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return legalAcceptanceRequired(ref);
  }
}

String _$legalAcceptanceRequiredHash() =>
    r'209a50ef0f64a8fcc494a677b89181cefc953f11';

/// Persists the explicit acceptance (version, time, age confirmation).

@ProviderFor(legalStore)
final legalStoreProvider = LegalStoreProvider._();

/// Persists the explicit acceptance (version, time, age confirmation).

final class LegalStoreProvider
    extends $FunctionalProvider<LegalStore, LegalStore, LegalStore>
    with $Provider<LegalStore> {
  /// Persists the explicit acceptance (version, time, age confirmation).
  LegalStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'legalStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$legalStoreHash();

  @$internal
  @override
  $ProviderElement<LegalStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LegalStore create(Ref ref) {
    return legalStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LegalStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LegalStore>(value),
    );
  }
}

String _$legalStoreHash() => r'08f7ca882ad6b3c1dd93d0baf8793d6bc4908629';
