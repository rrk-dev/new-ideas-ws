// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// OS background-execution bridge (FND-08); a no-op off iOS/Android.

@ProviderFor(backgroundProcessingPlatform)
final backgroundProcessingPlatformProvider =
    BackgroundProcessingPlatformProvider._();

/// OS background-execution bridge (FND-08); a no-op off iOS/Android.

final class BackgroundProcessingPlatformProvider
    extends
        $FunctionalProvider<
          BackgroundProcessingPlatform,
          BackgroundProcessingPlatform,
          BackgroundProcessingPlatform
        >
    with $Provider<BackgroundProcessingPlatform> {
  /// OS background-execution bridge (FND-08); a no-op off iOS/Android.
  BackgroundProcessingPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundProcessingPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundProcessingPlatformHash();

  @$internal
  @override
  $ProviderElement<BackgroundProcessingPlatform> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackgroundProcessingPlatform create(Ref ref) {
    return backgroundProcessingPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundProcessingPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundProcessingPlatform>(value),
    );
  }
}

String _$backgroundProcessingPlatformHash() =>
    r'efff8867aa796bd39c06b8ec02bbdd2ce6e7c862';

/// The background guardrails; `ProcessingServicesHost` starts it.

@ProviderFor(backgroundProcessingGuard)
final backgroundProcessingGuardProvider = BackgroundProcessingGuardProvider._();

/// The background guardrails; `ProcessingServicesHost` starts it.

final class BackgroundProcessingGuardProvider
    extends
        $FunctionalProvider<
          BackgroundProcessingGuard,
          BackgroundProcessingGuard,
          BackgroundProcessingGuard
        >
    with $Provider<BackgroundProcessingGuard> {
  /// The background guardrails; `ProcessingServicesHost` starts it.
  BackgroundProcessingGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundProcessingGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundProcessingGuardHash();

  @$internal
  @override
  $ProviderElement<BackgroundProcessingGuard> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackgroundProcessingGuard create(Ref ref) {
    return backgroundProcessingGuard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundProcessingGuard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundProcessingGuard>(value),
    );
  }
}

String _$backgroundProcessingGuardHash() =>
    r'de94fdbc9d5a886e119cd26c450fb62dbd49603f';
