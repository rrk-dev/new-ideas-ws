// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_support_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether this device meets the minimum CPU (see `isDeviceSupported`).
/// `bootstrap` overrides it with the launch probe over `vv_native`; the
/// default (tests, host tools) is supported.

@ProviderFor(deviceSupported)
final deviceSupportedProvider = DeviceSupportedProvider._();

/// Whether this device meets the minimum CPU (see `isDeviceSupported`).
/// `bootstrap` overrides it with the launch probe over `vv_native`; the
/// default (tests, host tools) is supported.

final class DeviceSupportedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this device meets the minimum CPU (see `isDeviceSupported`).
  /// `bootstrap` overrides it with the launch probe over `vv_native`; the
  /// default (tests, host tools) is supported.
  DeviceSupportedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceSupportedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceSupportedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return deviceSupported(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$deviceSupportedHash() => r'eefc336bf947212b8876ac79c629f70299f6306c';
