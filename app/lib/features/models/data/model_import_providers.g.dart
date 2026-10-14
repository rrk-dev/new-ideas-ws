// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_import_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(modelFilePicker)
final modelFilePickerProvider = ModelFilePickerProvider._();

final class ModelFilePickerProvider
    extends
        $FunctionalProvider<ModelFilePicker, ModelFilePicker, ModelFilePicker>
    with $Provider<ModelFilePicker> {
  ModelFilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelFilePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelFilePickerHash();

  @$internal
  @override
  $ProviderElement<ModelFilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelFilePicker create(Ref ref) {
    return modelFilePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelFilePicker>(value),
    );
  }
}

String _$modelFilePickerHash() => r'cebddab64a0fa620b9ded7f6859233f26cb692fa';

/// PLACEHOLDER until LIC-01: denies custom models. LIC-01 overrides this
/// with the real Pro entitlement check.

@ProviderFor(customModelEntitlement)
final customModelEntitlementProvider = CustomModelEntitlementProvider._();

/// PLACEHOLDER until LIC-01: denies custom models. LIC-01 overrides this
/// with the real Pro entitlement check.

final class CustomModelEntitlementProvider
    extends
        $FunctionalProvider<
          CustomModelEntitlement,
          CustomModelEntitlement,
          CustomModelEntitlement
        >
    with $Provider<CustomModelEntitlement> {
  /// PLACEHOLDER until LIC-01: denies custom models. LIC-01 overrides this
  /// with the real Pro entitlement check.
  CustomModelEntitlementProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customModelEntitlementProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customModelEntitlementHash();

  @$internal
  @override
  $ProviderElement<CustomModelEntitlement> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CustomModelEntitlement create(Ref ref) {
    return customModelEntitlement(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomModelEntitlement value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomModelEntitlement>(value),
    );
  }
}

String _$customModelEntitlementHash() =>
    r'0ab5f5a540e5a7c0a91f2b53ecb73cd0b91a8035';

/// `network_disabled` (offline mode / MDM): the UI hides downloads and
/// offers import only.

@ProviderFor(networkDisabled)
final networkDisabledProvider = NetworkDisabledProvider._();

/// `network_disabled` (offline mode / MDM): the UI hides downloads and
/// offers import only.

final class NetworkDisabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// `network_disabled` (offline mode / MDM): the UI hides downloads and
  /// offers import only.
  NetworkDisabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkDisabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkDisabledHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return networkDisabled(ref);
  }
}

String _$networkDisabledHash() => r'79f38f70eeac3a83678f14c2c0b970b76df78236';

@ProviderFor(modelImporter)
final modelImporterProvider = ModelImporterProvider._();

final class ModelImporterProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelImporter>,
          ModelImporter,
          FutureOr<ModelImporter>
        >
    with $FutureModifier<ModelImporter>, $FutureProvider<ModelImporter> {
  ModelImporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelImporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelImporterHash();

  @$internal
  @override
  $FutureProviderElement<ModelImporter> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelImporter> create(Ref ref) {
    return modelImporter(ref);
  }
}

String _$modelImporterHash() => r'c62a089fabe80cb7a573e1264fcc13bc72804baf';
