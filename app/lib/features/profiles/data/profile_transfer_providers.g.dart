// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_transfer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Organization keys allowed to sign managed profile packs.
///
/// LIC-03 (enterprise license, not built yet) overrides this with the
/// license's `org_profile_pubkey`; until then no key is trusted and signed
/// packs are refused (`untrustedKey`). PRODUCT-DECISION: no built-in key.

@ProviderFor(OrgProfileKeys)
final orgProfileKeysProvider = OrgProfileKeysProvider._();

/// Organization keys allowed to sign managed profile packs.
///
/// LIC-03 (enterprise license, not built yet) overrides this with the
/// license's `org_profile_pubkey`; until then no key is trusted and signed
/// packs are refused (`untrustedKey`). PRODUCT-DECISION: no built-in key.
final class OrgProfileKeysProvider
    extends $NotifierProvider<OrgProfileKeys, List<OrgProfileKey>> {
  /// Organization keys allowed to sign managed profile packs.
  ///
  /// LIC-03 (enterprise license, not built yet) overrides this with the
  /// license's `org_profile_pubkey`; until then no key is trusted and signed
  /// packs are refused (`untrustedKey`). PRODUCT-DECISION: no built-in key.
  OrgProfileKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orgProfileKeysProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orgProfileKeysHash();

  @$internal
  @override
  OrgProfileKeys create() => OrgProfileKeys();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<OrgProfileKey> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<OrgProfileKey>>(value),
    );
  }
}

String _$orgProfileKeysHash() => r'b4ccb6bb7d34741f149fbae45fc9d068b8c50d60';

/// Organization keys allowed to sign managed profile packs.
///
/// LIC-03 (enterprise license, not built yet) overrides this with the
/// license's `org_profile_pubkey`; until then no key is trusted and signed
/// packs are refused (`untrustedKey`). PRODUCT-DECISION: no built-in key.

abstract class _$OrgProfileKeys extends $Notifier<List<OrgProfileKey>> {
  List<OrgProfileKey> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<OrgProfileKey>, List<OrgProfileKey>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<OrgProfileKey>, List<OrgProfileKey>>,
              List<OrgProfileKey>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(profileBundlePicker)
final profileBundlePickerProvider = ProfileBundlePickerProvider._();

final class ProfileBundlePickerProvider
    extends
        $FunctionalProvider<
          ProfileBundlePicker,
          ProfileBundlePicker,
          ProfileBundlePicker
        >
    with $Provider<ProfileBundlePicker> {
  ProfileBundlePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileBundlePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileBundlePickerHash();

  @$internal
  @override
  $ProviderElement<ProfileBundlePicker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileBundlePicker create(Ref ref) {
    return profileBundlePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileBundlePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileBundlePicker>(value),
    );
  }
}

String _$profileBundlePickerHash() =>
    r'34e9442e726200d0ffa546711f5203b4297fa568';

/// Where exported bundles are written before the share sheet (app cache).

@ProviderFor(profileExportDir)
final profileExportDirProvider = ProfileExportDirProvider._();

/// Where exported bundles are written before the share sheet (app cache).

final class ProfileExportDirProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  /// Where exported bundles are written before the share sheet (app cache).
  ProfileExportDirProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileExportDirProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileExportDirHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return profileExportDir(ref);
  }
}

String _$profileExportDirHash() => r'45800211e4728ff2601e8d59530f03970860214c';

@ProviderFor(profileTransferService)
final profileTransferServiceProvider = ProfileTransferServiceProvider._();

final class ProfileTransferServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileTransferService>,
          ProfileTransferService,
          FutureOr<ProfileTransferService>
        >
    with
        $FutureModifier<ProfileTransferService>,
        $FutureProvider<ProfileTransferService> {
  ProfileTransferServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileTransferServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileTransferServiceHash();

  @$internal
  @override
  $FutureProviderElement<ProfileTransferService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileTransferService> create(Ref ref) {
    return profileTransferService(ref);
  }
}

String _$profileTransferServiceHash() =>
    r'c54cf17cdf801cef88a114ec54950416bc751366';
