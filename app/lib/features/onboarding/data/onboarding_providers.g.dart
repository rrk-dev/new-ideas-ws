// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The persisted `onboarding.completed` flag.

@ProviderFor(onboardingCompleted)
final onboardingCompletedProvider = OnboardingCompletedProvider._();

/// The persisted `onboarding.completed` flag.

final class OnboardingCompletedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// The persisted `onboarding.completed` flag.
  OnboardingCompletedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingCompletedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingCompletedHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return onboardingCompleted(ref);
  }
}

String _$onboardingCompletedHash() =>
    r'e2c3ac7b86f4a1ab78f1dada572b0692d2a121c4';

/// Whether the user explicitly chose to keep notes in the app.

@ProviderFor(onboardingNotesInApp)
final onboardingNotesInAppProvider = OnboardingNotesInAppProvider._();

/// Whether the user explicitly chose to keep notes in the app.

final class OnboardingNotesInAppProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether the user explicitly chose to keep notes in the app.
  OnboardingNotesInAppProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingNotesInAppProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingNotesInAppHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return onboardingNotesInApp(ref);
  }
}

String _$onboardingNotesInAppHash() =>
    r'96b282e87835b1e25ad378d38f3a742d14af8123';

/// Whether onboarding still has to run. Drives the router redirect to
/// `/onboarding`: not completed, or completed but the readiness check now
/// fails (model deleted, microphone revoked…) — so a stale
/// `onboarding.completed` from an older build is re-evaluated on every
/// launch. Unknown (loading) never redirects; a failing readiness probe
/// does not lock the user out either.

@ProviderFor(onboardingRequired)
final onboardingRequiredProvider = OnboardingRequiredProvider._();

/// Whether onboarding still has to run. Drives the router redirect to
/// `/onboarding`: not completed, or completed but the readiness check now
/// fails (model deleted, microphone revoked…) — so a stale
/// `onboarding.completed` from an older build is re-evaluated on every
/// launch. Unknown (loading) never redirects; a failing readiness probe
/// does not lock the user out either.

final class OnboardingRequiredProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether onboarding still has to run. Drives the router redirect to
  /// `/onboarding`: not completed, or completed but the readiness check now
  /// fails (model deleted, microphone revoked…) — so a stale
  /// `onboarding.completed` from an older build is re-evaluated on every
  /// launch. Unknown (loading) never redirects; a failing readiness probe
  /// does not lock the user out either.
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
    r'2c960e9b46ab7df1df28cd16eab5d099b96d00e6';

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
