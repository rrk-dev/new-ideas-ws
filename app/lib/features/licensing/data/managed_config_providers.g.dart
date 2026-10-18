// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_config_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform MDM managed configuration (LIC-04). Tests override it.

@ProviderFor(managedConfigSource)
final managedConfigSourceProvider = ManagedConfigSourceProvider._();

/// The platform MDM managed configuration (LIC-04). Tests override it.

final class ManagedConfigSourceProvider
    extends
        $FunctionalProvider<
          ManagedConfigSource,
          ManagedConfigSource,
          ManagedConfigSource
        >
    with $Provider<ManagedConfigSource> {
  /// The platform MDM managed configuration (LIC-04). Tests override it.
  ManagedConfigSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managedConfigSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managedConfigSourceHash();

  @$internal
  @override
  $ProviderElement<ManagedConfigSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ManagedConfigSource create(Ref ref) {
    return managedConfigSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ManagedConfigSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ManagedConfigSource>(value),
    );
  }
}

String _$managedConfigSourceHash() =>
    r'516cf20d85fe7198684fd5fd9d9eb9f7dfbac060';

/// The current configuration and every change.

@ProviderFor(managedConfig)
final managedConfigProvider = ManagedConfigProvider._();

/// The current configuration and every change.

final class ManagedConfigProvider
    extends
        $FunctionalProvider<
          AsyncValue<ManagedConfig>,
          ManagedConfig,
          Stream<ManagedConfig>
        >
    with $FutureModifier<ManagedConfig>, $StreamProvider<ManagedConfig> {
  /// The current configuration and every change.
  ManagedConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managedConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managedConfigHash();

  @$internal
  @override
  $StreamProviderElement<ManagedConfig> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ManagedConfig> create(Ref ref) {
    return managedConfig(ref);
  }
}

String _$managedConfigHash() => r'c798920365e16445acc4452d052873d463046e03';
