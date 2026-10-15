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

@ProviderFor(orgProfileKeys)
final orgProfileKeysProvider = OrgProfileKeysProvider._();

/// Organization keys allowed to sign managed profile packs.
///
/// LIC-03 (enterprise license, not built yet) overrides this with the
/// license's `org_profile_pubkey`; until then no key is trusted and signed
/// packs are refused (`untrustedKey`). PRODUCT-DECISION: no built-in key.

final class OrgProfileKeysProvider
    extends
        $FunctionalProvider<
          List<OrgProfileKey>,
          List<OrgProfileKey>,
          List<OrgProfileKey>
        >
    with $Provider<List<OrgProfileKey>> {
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
  $ProviderElement<List<OrgProfileKey>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<OrgProfileKey> create(Ref ref) {
    return orgProfileKeys(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<OrgProfileKey> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<OrgProfileKey>>(value),
    );
  }
}

String _$orgProfileKeysHash() => r'a77ce8a0101d43d28a10d4fa71d63e3608f8585c';

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

String _$profileExportDirHash() => r'37d7d294fe52f504684b3413b5a43f298f02b401';

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
    r'541c6809ab9df5584d8f928a7e03e8242b55d55f';
