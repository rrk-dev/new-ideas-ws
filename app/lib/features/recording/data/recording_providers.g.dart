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

/// Standard OS microphone API (`record` package); tests use a fake.

@ProviderFor(pcmMicSource)
final pcmMicSourceProvider = PcmMicSourceProvider._();

/// Standard OS microphone API (`record` package); tests use a fake.

final class PcmMicSourceProvider
    extends $FunctionalProvider<PcmMicSource, PcmMicSource, PcmMicSource>
    with $Provider<PcmMicSource> {
  /// Standard OS microphone API (`record` package); tests use a fake.
  PcmMicSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pcmMicSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pcmMicSourceHash();

  @$internal
  @override
  $ProviderElement<PcmMicSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PcmMicSource create(Ref ref) {
    return pcmMicSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PcmMicSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PcmMicSource>(value),
    );
  }
}

String _$pcmMicSourceHash() => r'14b17b3d0b5196c19cd5ac003aa659a4c24d90a4';

/// Free-space probe for the recording storage policy.

@ProviderFor(diskSpaceProbe)
final diskSpaceProbeProvider = DiskSpaceProbeProvider._();

/// Free-space probe for the recording storage policy.

final class DiskSpaceProbeProvider
    extends $FunctionalProvider<DiskSpaceProbe, DiskSpaceProbe, DiskSpaceProbe>
    with $Provider<DiskSpaceProbe> {
  /// Free-space probe for the recording storage policy.
  DiskSpaceProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diskSpaceProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diskSpaceProbeHash();

  @$internal
  @override
  $ProviderElement<DiskSpaceProbe> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DiskSpaceProbe create(Ref ref) {
    return diskSpaceProbe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiskSpaceProbe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiskSpaceProbe>(value),
    );
  }
}

String _$diskSpaceProbeHash() => r'cdbd1cf159dc9b43d433dd4f0e67088ba3c5178f';

/// Chunk file codec. SEC-01 overrides it if its ADR picks `vvenc`.

@ProviderFor(audioChunkCodec)
final audioChunkCodecProvider = AudioChunkCodecProvider._();

/// Chunk file codec. SEC-01 overrides it if its ADR picks `vvenc`.

final class AudioChunkCodecProvider
    extends
        $FunctionalProvider<AudioChunkCodec, AudioChunkCodec, AudioChunkCodec>
    with $Provider<AudioChunkCodec> {
  /// Chunk file codec. SEC-01 overrides it if its ADR picks `vvenc`.
  AudioChunkCodecProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioChunkCodecProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioChunkCodecHash();

  @$internal
  @override
  $ProviderElement<AudioChunkCodec> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioChunkCodec create(Ref ref) {
    return audioChunkCodec(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioChunkCodec value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioChunkCodec>(value),
    );
  }
}

String _$audioChunkCodecHash() => r'da3872a8e77c3efae435710c9f3e6e74b8420fb3';

/// The real microphone capture (AUD-01).

@ProviderFor(recordCaptureBackend)
final recordCaptureBackendProvider = RecordCaptureBackendProvider._();

/// The real microphone capture (AUD-01).

final class RecordCaptureBackendProvider
    extends
        $FunctionalProvider<
          RecordCaptureBackend,
          RecordCaptureBackend,
          RecordCaptureBackend
        >
    with $Provider<RecordCaptureBackend> {
  /// The real microphone capture (AUD-01).
  RecordCaptureBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordCaptureBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordCaptureBackendHash();

  @$internal
  @override
  $ProviderElement<RecordCaptureBackend> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordCaptureBackend create(Ref ref) {
    return recordCaptureBackend(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordCaptureBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordCaptureBackend>(value),
    );
  }
}

String _$recordCaptureBackendHash() =>
    r'dc216464e9aa935c6157ecac70ce441de1d9dec9';

/// Microphone capture driven by [recordingController]; tests override it
/// with `FakeCaptureBackend`.

@ProviderFor(captureBackend)
final captureBackendProvider = CaptureBackendProvider._();

/// Microphone capture driven by [recordingController]; tests override it
/// with `FakeCaptureBackend`.

final class CaptureBackendProvider
    extends $FunctionalProvider<CaptureBackend, CaptureBackend, CaptureBackend>
    with $Provider<CaptureBackend> {
  /// Microphone capture driven by [recordingController]; tests override it
  /// with `FakeCaptureBackend`.
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

String _$captureBackendHash() => r'abb770d3a28157dfc7aff6d2061bf3e16b4c54a0';

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
