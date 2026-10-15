// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stt_model_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The STT plan gate backed by LIC-01's single entitlement authority
/// (`EntitlementService`). Model pickers and the engine factory resolve the
/// model with [resolveSttModel] / [sttModelAccess] through this gate, so a
/// plan change or expiry applies immediately.

@ProviderFor(sttPlanGate)
final sttPlanGateProvider = SttPlanGateProvider._();

/// The STT plan gate backed by LIC-01's single entitlement authority
/// (`EntitlementService`). Model pickers and the engine factory resolve the
/// model with [resolveSttModel] / [sttModelAccess] through this gate, so a
/// plan change or expiry applies immediately.

final class SttPlanGateProvider
    extends $FunctionalProvider<SttPlanGate, SttPlanGate, SttPlanGate>
    with $Provider<SttPlanGate> {
  /// The STT plan gate backed by LIC-01's single entitlement authority
  /// (`EntitlementService`). Model pickers and the engine factory resolve the
  /// model with [resolveSttModel] / [sttModelAccess] through this gate, so a
  /// plan change or expiry applies immediately.
  SttPlanGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sttPlanGateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sttPlanGateHash();

  @$internal
  @override
  $ProviderElement<SttPlanGate> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SttPlanGate create(Ref ref) {
    return sttPlanGate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SttPlanGate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SttPlanGate>(value),
    );
  }
}

String _$sttPlanGateHash() => r'9b5e70a92fd110c5e7e1c371d6dc55c69d26d173';
