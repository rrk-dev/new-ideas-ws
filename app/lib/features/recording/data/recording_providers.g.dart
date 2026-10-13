// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Platform call guard (SEC-09); tests override it with `FakeCallGuard`.

@ProviderFor(callGuard)
final callGuardProvider = CallGuardProvider._();

/// Platform call guard (SEC-09); tests override it with `FakeCallGuard`.

final class CallGuardProvider
    extends $FunctionalProvider<CallGuard, CallGuard, CallGuard>
    with $Provider<CallGuard> {
  /// Platform call guard (SEC-09); tests override it with `FakeCallGuard`.
  CallGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'callGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$callGuardHash();

  @$internal
  @override
  $ProviderElement<CallGuard> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CallGuard create(Ref ref) {
    return callGuard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CallGuard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CallGuard>(value),
    );
  }
}

String _$callGuardHash() => r'a6c1e88ffb8313dec8f094c025b6c092f4f3ad78';

/// Microphone capture; AUD-01 supplies the real implementation.

@ProviderFor(captureBackend)
final captureBackendProvider = CaptureBackendProvider._();

/// Microphone capture; AUD-01 supplies the real implementation.

final class CaptureBackendProvider
    extends $FunctionalProvider<CaptureBackend, CaptureBackend, CaptureBackend>
    with $Provider<CaptureBackend> {
  /// Microphone capture; AUD-01 supplies the real implementation.
  CaptureBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'captureBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$captureBackendHash();

  @$internal
  @override
  $ProviderElement<CaptureBackend> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CaptureBackend create(Ref ref) {
    return captureBackend(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CaptureBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CaptureBackend>(value),
    );
  }
}

String _$captureBackendHash() => r'0088e32b6c32a62c2248d9f2cbba6f507976bb5f';

/// The single recording entry point (SEC-09).

@ProviderFor(recordingController)
final recordingControllerProvider = RecordingControllerProvider._();

/// The single recording entry point (SEC-09).

final class RecordingControllerProvider
    extends
        $FunctionalProvider<
          RecordingController,
          RecordingController,
          RecordingController
        >
    with $Provider<RecordingController> {
  /// The single recording entry point (SEC-09).
  RecordingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingControllerHash();

  @$internal
  @override
  $ProviderElement<RecordingController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordingController create(Ref ref) {
    return recordingController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordingController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordingController>(value),
    );
  }
}

String _$recordingControllerHash() =>
    r'2f11ff8c2f89e2d1427f2f05e30d7b2c97751363';
