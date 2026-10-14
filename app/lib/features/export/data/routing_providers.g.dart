// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(routingRulesStore)
final routingRulesStoreProvider = RoutingRulesStoreProvider._();

final class RoutingRulesStoreProvider
    extends
        $FunctionalProvider<
          RoutingRulesStore,
          RoutingRulesStore,
          RoutingRulesStore
        >
    with $Provider<RoutingRulesStore> {
  RoutingRulesStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routingRulesStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routingRulesStoreHash();

  @$internal
  @override
  $ProviderElement<RoutingRulesStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RoutingRulesStore create(Ref ref) {
    return routingRulesStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoutingRulesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoutingRulesStore>(value),
    );
  }
}

String _$routingRulesStoreHash() => r'e23e041202cb64f475579de8f97ec7a8a4a3210e';

/// Routing rules in evaluation order (rule editor, EXP-05).

@ProviderFor(routingRuleList)
final routingRuleListProvider = RoutingRuleListProvider._();

/// Routing rules in evaluation order (rule editor, EXP-05).

final class RoutingRuleListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoutingRule>>,
          List<RoutingRule>,
          Stream<List<RoutingRule>>
        >
    with
        $FutureModifier<List<RoutingRule>>,
        $StreamProvider<List<RoutingRule>> {
  /// Routing rules in evaluation order (rule editor, EXP-05).
  RoutingRuleListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routingRuleListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routingRuleListHash();

  @$internal
  @override
  $StreamProviderElement<List<RoutingRule>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoutingRule>> create(Ref ref) {
    return routingRuleList(ref);
  }
}

String _$routingRuleListHash() => r'79f3f25d875f8b74e75eb9236fbd55645164ce2c';

/// Per-target export options (`export.target_options`).

@ProviderFor(vaultTargetOptions)
final vaultTargetOptionsProvider = VaultTargetOptionsProvider._();

/// Per-target export options (`export.target_options`).

final class VaultTargetOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, VaultTargetOptions>>,
          Map<String, VaultTargetOptions>,
          Stream<Map<String, VaultTargetOptions>>
        >
    with
        $FutureModifier<Map<String, VaultTargetOptions>>,
        $StreamProvider<Map<String, VaultTargetOptions>> {
  /// Per-target export options (`export.target_options`).
  VaultTargetOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultTargetOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultTargetOptionsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, VaultTargetOptions>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, VaultTargetOptions>> create(Ref ref) {
    return vaultTargetOptions(ref);
  }
}

String _$vaultTargetOptionsHash() =>
    r'3d6cf8369b5fa32d2da14018146423f7a241ef7e';

/// The routing entitlement for the UI.

@ProviderFor(routingPolicy)
final routingPolicyProvider = RoutingPolicyProvider._();

/// The routing entitlement for the UI.

final class RoutingPolicyProvider
    extends $FunctionalProvider<RoutingPolicy, RoutingPolicy, RoutingPolicy>
    with $Provider<RoutingPolicy> {
  /// The routing entitlement for the UI.
  RoutingPolicyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routingPolicyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routingPolicyHash();

  @$internal
  @override
  $ProviderElement<RoutingPolicy> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoutingPolicy create(Ref ref) {
    return routingPolicy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoutingPolicy value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoutingPolicy>(value),
    );
  }
}

String _$routingPolicyHash() => r'6ed2b4685d4e42ad3b72c47288c0c49965b4f4b8';

/// Mirrors [routingPolicy] into `export.routing_policy` for the pipeline
/// worker isolate (it has no `EntitlementService`). Read once at startup
/// (`ProcessingServicesHost`); stays subscribed for the app's lifetime.

@ProviderFor(routingPolicyMirror)
final routingPolicyMirrorProvider = RoutingPolicyMirrorProvider._();

/// Mirrors [routingPolicy] into `export.routing_policy` for the pipeline
/// worker isolate (it has no `EntitlementService`). Read once at startup
/// (`ProcessingServicesHost`); stays subscribed for the app's lifetime.

final class RoutingPolicyMirrorProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Mirrors [routingPolicy] into `export.routing_policy` for the pipeline
  /// worker isolate (it has no `EntitlementService`). Read once at startup
  /// (`ProcessingServicesHost`); stays subscribed for the app's lifetime.
  RoutingPolicyMirrorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routingPolicyMirrorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routingPolicyMirrorHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return routingPolicyMirror(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$routingPolicyMirrorHash() =>
    r'7d8c96c7b7d8cce19c7c56762c2575202aafd8ce';
