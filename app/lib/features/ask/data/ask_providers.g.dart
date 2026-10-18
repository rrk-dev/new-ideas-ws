// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ask_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `ask.enabled` (default off): the whole Ask entry is hidden while false.
/// PRODUCT-DECISION (ASK-04): the ASK-03 quality gates are not met.

@ProviderFor(askEnabled)
final askEnabledProvider = AskEnabledProvider._();

/// `ask.enabled` (default off): the whole Ask entry is hidden while false.
/// PRODUCT-DECISION (ASK-04): the ASK-03 quality gates are not met.

final class AskEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// `ask.enabled` (default off): the whole Ask entry is hidden while false.
  /// PRODUCT-DECISION (ASK-04): the ASK-03 quality gates are not met.
  AskEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'askEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$askEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return askEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$askEnabledHash() => r'39c67fba3e4ec3c6c4b1c9cc7741d02eb64a2d08';

/// `ask.save_history` (default on, PRODUCT-DECISION human 2026-10-17).

@ProviderFor(askSaveHistoryEnabled)
final askSaveHistoryEnabledProvider = AskSaveHistoryEnabledProvider._();

/// `ask.save_history` (default on, PRODUCT-DECISION human 2026-10-17).

final class AskSaveHistoryEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// `ask.save_history` (default on, PRODUCT-DECISION human 2026-10-17).
  AskSaveHistoryEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'askSaveHistoryEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$askSaveHistoryEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return askSaveHistoryEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$askSaveHistoryEnabledHash() =>
    r'b7c99babca1c60c2467dfdb63806ecfdda3e7303';

/// Device tier × installed 3B (ADR-ASK-02).

@ProviderFor(askAvailabilityState)
final askAvailabilityStateProvider = AskAvailabilityStateProvider._();

/// Device tier × installed 3B (ADR-ASK-02).

final class AskAvailabilityStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<AskAvailability>,
          AskAvailability,
          FutureOr<AskAvailability>
        >
    with $FutureModifier<AskAvailability>, $FutureProvider<AskAvailability> {
  /// Device tier × installed 3B (ADR-ASK-02).
  AskAvailabilityStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'askAvailabilityStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$askAvailabilityStateHash();

  @$internal
  @override
  $FutureProviderElement<AskAvailability> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AskAvailability> create(Ref ref) {
    return askAvailabilityState(ref);
  }
}

String _$askAvailabilityStateHash() =>
    r'7c1d32b210f8a8f1a6f627ca43a49c51fe68662b';

/// The catalog entry of the Ask model (size for the download prompt), or
/// null when the active catalog does not list it.

@ProviderFor(askModelEntry)
final askModelEntryProvider = AskModelEntryProvider._();

/// The catalog entry of the Ask model (size for the download prompt), or
/// null when the active catalog does not list it.

final class AskModelEntryProvider
    extends
        $FunctionalProvider<
          AsyncValue<CatalogModel?>,
          CatalogModel?,
          FutureOr<CatalogModel?>
        >
    with $FutureModifier<CatalogModel?>, $FutureProvider<CatalogModel?> {
  /// The catalog entry of the Ask model (size for the download prompt), or
  /// null when the active catalog does not list it.
  AskModelEntryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'askModelEntryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$askModelEntryHash();

  @$internal
  @override
  $FutureProviderElement<CatalogModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CatalogModel?> create(Ref ref) {
    return askModelEntry(ref);
  }
}

String _$askModelEntryHash() => r'd5bf96a162b87f9a6b20630ef8e6f357009bd909';

@ProviderFor(askHistoryStore)
final askHistoryStoreProvider = AskHistoryStoreProvider._();

final class AskHistoryStoreProvider
    extends
        $FunctionalProvider<AskHistoryStore, AskHistoryStore, AskHistoryStore>
    with $Provider<AskHistoryStore> {
  AskHistoryStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'askHistoryStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$askHistoryStoreHash();

  @$internal
  @override
  $ProviderElement<AskHistoryStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AskHistoryStore create(Ref ref) {
    return askHistoryStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AskHistoryStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AskHistoryStore>(value),
    );
  }
}

String _$askHistoryStoreHash() => r'68a8d8956d4a5a2a4ef320818aa8c871f399e58b';

/// Saved chats, newest first.

@ProviderFor(askThreads)
final askThreadsProvider = AskThreadsProvider._();

/// Saved chats, newest first.

final class AskThreadsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AskThread>>,
          List<AskThread>,
          FutureOr<List<AskThread>>
        >
    with $FutureModifier<List<AskThread>>, $FutureProvider<List<AskThread>> {
  /// Saved chats, newest first.
  AskThreadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'askThreadsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$askThreadsHash();

  @$internal
  @override
  $FutureProviderElement<List<AskThread>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AskThread>> create(Ref ref) {
    return askThreads(ref);
  }
}

String _$askThreadsHash() => r'03ba401aa8a177aeb67fca1a83c07f9dacda2de9';

/// The Ask engine: retrieval over the encrypted DB, the 3B on this device,
/// no network. Rebuilt when the tier or the installed model changes.

@ProviderFor(askEngine)
final askEngineProvider = AskEngineProvider._();

/// The Ask engine: retrieval over the encrypted DB, the 3B on this device,
/// no network. Rebuilt when the tier or the installed model changes.

final class AskEngineProvider
    extends
        $FunctionalProvider<
          AsyncValue<AskEngine>,
          AskEngine,
          FutureOr<AskEngine>
        >
    with $FutureModifier<AskEngine>, $FutureProvider<AskEngine> {
  /// The Ask engine: retrieval over the encrypted DB, the 3B on this device,
  /// no network. Rebuilt when the tier or the installed model changes.
  AskEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'askEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$askEngineHash();

  @$internal
  @override
  $FutureProviderElement<AskEngine> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AskEngine> create(Ref ref) {
    return askEngine(ref);
  }
}

String _$askEngineHash() => r'ab2567a34aff3952618df2550361afb11d9b4bc9';
