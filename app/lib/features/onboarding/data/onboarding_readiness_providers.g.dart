// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_readiness_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Composes the existing providers into an [OnboardingReadiness]: installed
/// models, vault targets / "keep in app" choice, microphone permission
/// (queried without prompting — SEC-09) and free space vs the recommended
/// models still to download. Invalidate after a Fix action or when the app
/// returns from the OS Settings.

@ProviderFor(onboardingReadiness)
final onboardingReadinessProvider = OnboardingReadinessProvider._();

/// Composes the existing providers into an [OnboardingReadiness]: installed
/// models, vault targets / "keep in app" choice, microphone permission
/// (queried without prompting — SEC-09) and free space vs the recommended
/// models still to download. Invalidate after a Fix action or when the app
/// returns from the OS Settings.

final class OnboardingReadinessProvider
    extends
        $FunctionalProvider<
          AsyncValue<OnboardingReadiness>,
          OnboardingReadiness,
          FutureOr<OnboardingReadiness>
        >
    with
        $FutureModifier<OnboardingReadiness>,
        $FutureProvider<OnboardingReadiness> {
  /// Composes the existing providers into an [OnboardingReadiness]: installed
  /// models, vault targets / "keep in app" choice, microphone permission
  /// (queried without prompting — SEC-09) and free space vs the recommended
  /// models still to download. Invalidate after a Fix action or when the app
  /// returns from the OS Settings.
  OnboardingReadinessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingReadinessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingReadinessHash();

  @$internal
  @override
  $FutureProviderElement<OnboardingReadiness> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OnboardingReadiness> create(Ref ref) {
    return onboardingReadiness(ref);
  }
}

String _$onboardingReadinessHash() =>
    r'a12d8a057ba9457718f8c97a18e244a4fd80c5bb';
