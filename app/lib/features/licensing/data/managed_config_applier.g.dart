// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_config_applier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Installs the managed licence and profile packs whenever the managed
/// configuration changes (and once at start). Started by
/// `ManagedConfigHost`; the other keys are enforced where they are used.

@ProviderFor(ManagedConfigApplier)
final managedConfigApplierProvider = ManagedConfigApplierProvider._();

/// Installs the managed licence and profile packs whenever the managed
/// configuration changes (and once at start). Started by
/// `ManagedConfigHost`; the other keys are enforced where they are used.
final class ManagedConfigApplierProvider
    extends $NotifierProvider<ManagedConfigApplier, ManagedApplyStatus> {
  /// Installs the managed licence and profile packs whenever the managed
  /// configuration changes (and once at start). Started by
  /// `ManagedConfigHost`; the other keys are enforced where they are used.
  ManagedConfigApplierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managedConfigApplierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managedConfigApplierHash();

  @$internal
  @override
  ManagedConfigApplier create() => ManagedConfigApplier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ManagedApplyStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ManagedApplyStatus>(value),
    );
  }
}

String _$managedConfigApplierHash() =>
    r'6a8c43a1bd2f3f5d3c2d1d93b82549ba82509544';

/// Installs the managed licence and profile packs whenever the managed
/// configuration changes (and once at start). Started by
/// `ManagedConfigHost`; the other keys are enforced where they are used.

abstract class _$ManagedConfigApplier extends $Notifier<ManagedApplyStatus> {
  ManagedApplyStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ManagedApplyStatus, ManagedApplyStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ManagedApplyStatus, ManagedApplyStatus>,
              ManagedApplyStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
