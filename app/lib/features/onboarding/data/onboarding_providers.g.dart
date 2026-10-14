// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the first-launch flow still has to run. Drives the router
/// redirect to `/onboarding`; unknown (loading/error) never redirects.

@ProviderFor(onboardingRequired)
final onboardingRequiredProvider = OnboardingRequiredProvider._();

/// Whether the first-launch flow still has to run. Drives the router
/// redirect to `/onboarding`; unknown (loading/error) never redirects.

final class OnboardingRequiredProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether the first-launch flow still has to run. Drives the router
  /// redirect to `/onboarding`; unknown (loading/error) never redirects.
  OnboardingRequiredProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingRequiredProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingRequiredHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return onboardingRequired(ref);
  }
}

String _$onboardingRequiredHash() =>
    r'95653c2327c5520dd96c205dde523bb644d0ce9c';

/// Whether the first-run recording-consent explainer was acknowledged.

@ProviderFor(consentAcknowledged)
final consentAcknowledgedProvider = ConsentAcknowledgedProvider._();

/// Whether the first-run recording-consent explainer was acknowledged.

final class ConsentAcknowledgedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether the first-run recording-consent explainer was acknowledged.
  ConsentAcknowledgedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'consentAcknowledgedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$consentAcknowledgedHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return consentAcknowledged(ref);
  }
}

String _$consentAcknowledgedHash() =>
    r'97bd4b2bcab351e09718ef2fed8851437574d8b7';

/// Persists onboarding milestones.

@ProviderFor(onboardingStore)
final onboardingStoreProvider = OnboardingStoreProvider._();

/// Persists onboarding milestones.

final class OnboardingStoreProvider
    extends
        $FunctionalProvider<OnboardingStore, OnboardingStore, OnboardingStore>
    with $Provider<OnboardingStore> {
  /// Persists onboarding milestones.
  OnboardingStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingStoreHash();

  @$internal
  @override
  $ProviderElement<OnboardingStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OnboardingStore create(Ref ref) {
    return onboardingStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingStore>(value),
    );
  }
}

String _$onboardingStoreHash() => r'6007c1256e883ae2833a8a77c5b7f2af05b4e110';
