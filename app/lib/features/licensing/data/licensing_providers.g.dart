// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'licensing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Personal vs commercial build (`--dart-define=VV_COMMERCIAL=true`).
/// PRODUCT-DECISION: defaults to [DistributionMode.personal]; tests override.

@ProviderFor(distributionMode)
final distributionModeProvider = DistributionModeProvider._();

/// Personal vs commercial build (`--dart-define=VV_COMMERCIAL=true`).
/// PRODUCT-DECISION: defaults to [DistributionMode.personal]; tests override.

final class DistributionModeProvider
    extends
        $FunctionalProvider<
          DistributionMode,
          DistributionMode,
          DistributionMode
        >
    with $Provider<DistributionMode> {
  /// Personal vs commercial build (`--dart-define=VV_COMMERCIAL=true`).
  /// PRODUCT-DECISION: defaults to [DistributionMode.personal]; tests override.
  DistributionModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'distributionModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$distributionModeHash();

  @$internal
  @override
  $ProviderElement<DistributionMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DistributionMode create(Ref ref) {
    return distributionMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DistributionMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DistributionMode>(value),
    );
  }
}

String _$distributionModeHash() => r'b159dfe0dc3fcc3a7d88679504865d5772ee8750';

/// The one entitlement authority. LIC-02/LIC-03 sources call
/// `EntitlementService.update` after each verification.

@ProviderFor(entitlementService)
final entitlementServiceProvider = EntitlementServiceProvider._();

/// The one entitlement authority. LIC-02/LIC-03 sources call
/// `EntitlementService.update` after each verification.

final class EntitlementServiceProvider
    extends
        $FunctionalProvider<
          EntitlementService,
          EntitlementService,
          EntitlementService
        >
    with $Provider<EntitlementService> {
  /// The one entitlement authority. LIC-02/LIC-03 sources call
  /// `EntitlementService.update` after each verification.
  EntitlementServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementServiceHash();

  @$internal
  @override
  $ProviderElement<EntitlementService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntitlementService create(Ref ref) {
    return entitlementService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntitlementService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntitlementService>(value),
    );
  }
}

String _$entitlementServiceHash() =>
    r'3162e2e0321140ebf4ecb6e9a44dfdd4e25e1691';

/// Current [FeatureAccess], updated on every entitlement change/expiry.

@ProviderFor(FeatureAccessState)
final featureAccessStateProvider = FeatureAccessStateProvider._();

/// Current [FeatureAccess], updated on every entitlement change/expiry.
final class FeatureAccessStateProvider
    extends $NotifierProvider<FeatureAccessState, FeatureAccess> {
  /// Current [FeatureAccess], updated on every entitlement change/expiry.
  FeatureAccessStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureAccessStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureAccessStateHash();

  @$internal
  @override
  FeatureAccessState create() => FeatureAccessState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureAccess value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureAccess>(value),
    );
  }
}

String _$featureAccessStateHash() =>
    r'f25a01ffc0c4354786b4ac389538d3187de22546';

/// Current [FeatureAccess], updated on every entitlement change/expiry.

abstract class _$FeatureAccessState extends $Notifier<FeatureAccess> {
  FeatureAccess build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FeatureAccess, FeatureAccess>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FeatureAccess, FeatureAccess>,
              FeatureAccess,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// `ref.watch(featureProvider(Feature.x))` — the only feature check UI and
/// features should use.

@ProviderFor(feature)
final featureProvider = FeatureFamily._();

/// `ref.watch(featureProvider(Feature.x))` — the only feature check UI and
/// features should use.

final class FeatureProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// `ref.watch(featureProvider(Feature.x))` — the only feature check UI and
  /// features should use.
  FeatureProvider._({
    required FeatureFamily super.from,
    required Feature super.argument,
  }) : super(
         retry: null,
         name: r'featureProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$featureHash();

  @override
  String toString() {
    return r'featureProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as Feature;
    return feature(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeatureProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$featureHash() => r'7b5ef8803c6a207223c0f9307a263411055b2461';

/// `ref.watch(featureProvider(Feature.x))` — the only feature check UI and
/// features should use.

final class FeatureFamily extends $Family
    with $FunctionalFamilyOverride<bool, Feature> {
  FeatureFamily._()
    : super(
        retry: null,
        name: r'featureProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `ref.watch(featureProvider(Feature.x))` — the only feature check UI and
  /// features should use.

  FeatureProvider call(Feature feature) =>
      FeatureProvider._(argument: feature, from: this);

  @override
  String toString() => r'featureProvider';
}

/// Access to an installed / downloadable catalog model of [tier].

@ProviderFor(modelAccess)
final modelAccessProvider = ModelAccessFamily._();

/// Access to an installed / downloadable catalog model of [tier].

final class ModelAccessProvider
    extends $FunctionalProvider<AccessLevel, AccessLevel, AccessLevel>
    with $Provider<AccessLevel> {
  /// Access to an installed / downloadable catalog model of [tier].
  ModelAccessProvider._({
    required ModelAccessFamily super.from,
    required (ModelTier, {bool installed}) super.argument,
  }) : super(
         retry: null,
         name: r'modelAccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$modelAccessHash();

  @override
  String toString() {
    return r'modelAccessProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<AccessLevel> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccessLevel create(Ref ref) {
    final argument = this.argument as (ModelTier, {bool installed});
    return modelAccess(ref, argument.$1, installed: argument.installed);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccessLevel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccessLevel>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ModelAccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$modelAccessHash() => r'5921b736182a077711cf0166ed33ee202dc74aeb';

/// Access to an installed / downloadable catalog model of [tier].

final class ModelAccessFamily extends $Family
    with $FunctionalFamilyOverride<AccessLevel, (ModelTier, {bool installed})> {
  ModelAccessFamily._()
    : super(
        retry: null,
        name: r'modelAccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Access to an installed / downloadable catalog model of [tier].

  ModelAccessProvider call(ModelTier tier, {required bool installed}) =>
      ModelAccessProvider._(argument: (tier, installed: installed), from: this);

  @override
  String toString() => r'modelAccessProvider';
}

@ProviderFor(entitlementSummary)
final entitlementSummaryProvider = EntitlementSummaryProvider._();

final class EntitlementSummaryProvider
    extends
        $FunctionalProvider<
          EntitlementSummary,
          EntitlementSummary,
          EntitlementSummary
        >
    with $Provider<EntitlementSummary> {
  EntitlementSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementSummaryHash();

  @$internal
  @override
  $ProviderElement<EntitlementSummary> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntitlementSummary create(Ref ref) {
    return entitlementSummary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntitlementSummary value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntitlementSummary>(value),
    );
  }
}

String _$entitlementSummaryHash() =>
    r'e2318e6523ebe1ad27330500f942cb1ea9a39a3f';

/// Paywall entry point; LIC-02 overrides it with the store-backed screen.

@ProviderFor(paywallPresenter)
final paywallPresenterProvider = PaywallPresenterProvider._();

/// Paywall entry point; LIC-02 overrides it with the store-backed screen.

final class PaywallPresenterProvider
    extends
        $FunctionalProvider<
          PaywallPresenter,
          PaywallPresenter,
          PaywallPresenter
        >
    with $Provider<PaywallPresenter> {
  /// Paywall entry point; LIC-02 overrides it with the store-backed screen.
  PaywallPresenterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paywallPresenterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paywallPresenterHash();

  @$internal
  @override
  $ProviderElement<PaywallPresenter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PaywallPresenter create(Ref ref) {
    return paywallPresenter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaywallPresenter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaywallPresenter>(value),
    );
  }
}

String _$paywallPresenterHash() => r'698a07d2bbf51d3a5ba5f3aed437c02ba99df438';
