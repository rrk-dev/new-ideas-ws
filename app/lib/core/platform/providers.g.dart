// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sttEngine)
final sttEngineProvider = SttEngineProvider._();

final class SttEngineProvider
    extends $FunctionalProvider<SttEngine, SttEngine, SttEngine>
    with $Provider<SttEngine> {
  SttEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sttEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sttEngineHash();

  @$internal
  @override
  $ProviderElement<SttEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SttEngine create(Ref ref) {
    return sttEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SttEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SttEngine>(value),
    );
  }
}

String _$sttEngineHash() => r'ccd48352259850f83bfe32bdd9d7a1631bcf7396';

@ProviderFor(llmEngine)
final llmEngineProvider = LlmEngineProvider._();

final class LlmEngineProvider
    extends $FunctionalProvider<LlmEngine, LlmEngine, LlmEngine>
    with $Provider<LlmEngine> {
  LlmEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmEngineHash();

  @$internal
  @override
  $ProviderElement<LlmEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LlmEngine create(Ref ref) {
    return llmEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmEngine>(value),
    );
  }
}

String _$llmEngineHash() => r'045e113f358ddefde4c1d7fe1e1cb352c5d4e65c';

@ProviderFor(vaultWriter)
final vaultWriterProvider = VaultWriterProvider._();

final class VaultWriterProvider
    extends $FunctionalProvider<VaultWriter, VaultWriter, VaultWriter>
    with $Provider<VaultWriter> {
  VaultWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultWriterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultWriterHash();

  @$internal
  @override
  $ProviderElement<VaultWriter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VaultWriter create(Ref ref) {
    return vaultWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultWriter>(value),
    );
  }
}

String _$vaultWriterHash() => r'8e6c3811bca867dc621019f7b06d1b687957d292';

@ProviderFor(clock)
final clockProvider = ClockProvider._();

final class ClockProvider extends $FunctionalProvider<Clock, Clock, Clock>
    with $Provider<Clock> {
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<Clock> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Clock create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Clock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Clock>(value),
    );
  }
}

String _$clockHash() => r'55214d6539f7396a3ae1aa23b06eea79fdac0ebe';

/// `libvv_native` outside an app bundle (host tests and tools); null on
/// devices, where the library is bundled with the app.

@ProviderFor(nativeLibraryPath)
final nativeLibraryPathProvider = NativeLibraryPathProvider._();

/// `libvv_native` outside an app bundle (host tests and tools); null on
/// devices, where the library is bundled with the app.

final class NativeLibraryPathProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// `libvv_native` outside an app bundle (host tests and tools); null on
  /// devices, where the library is bundled with the app.
  NativeLibraryPathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nativeLibraryPathProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nativeLibraryPathHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return nativeLibraryPath(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$nativeLibraryPathHash() => r'1fbf8c594a50e3bab3c25ce2aefb56388f563af1';

/// Allowlist config: model catalog/CDN hosts only (MDL-01).

@ProviderFor(networkConfig)
final networkConfigProvider = NetworkConfigProvider._();

/// Allowlist config: model catalog/CDN hosts only (MDL-01).

final class NetworkConfigProvider
    extends $FunctionalProvider<NetworkConfig, NetworkConfig, NetworkConfig>
    with $Provider<NetworkConfig> {
  /// Allowlist config: model catalog/CDN hosts only (MDL-01).
  NetworkConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkConfigHash();

  @$internal
  @override
  $ProviderElement<NetworkConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NetworkConfig create(Ref ref) {
    return networkConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkConfig>(value),
    );
  }
}

String _$networkConfigHash() => r'1467334b9f04701cb710320ab4a80f1a53b51933';

/// In-app "Network activity" log (SEC-02). In memory by default;
/// `bootstrap` overrides it with the file-backed log `vv/network/`.

@ProviderFor(networkActivityLog)
final networkActivityLogProvider = NetworkActivityLogProvider._();

/// In-app "Network activity" log (SEC-02). In memory by default;
/// `bootstrap` overrides it with the file-backed log `vv/network/`.

final class NetworkActivityLogProvider
    extends
        $FunctionalProvider<
          NetworkActivityLog,
          NetworkActivityLog,
          NetworkActivityLog
        >
    with $Provider<NetworkActivityLog> {
  /// In-app "Network activity" log (SEC-02). In memory by default;
  /// `bootstrap` overrides it with the file-backed log `vv/network/`.
  NetworkActivityLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkActivityLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkActivityLogHash();

  @$internal
  @override
  $ProviderElement<NetworkActivityLog> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NetworkActivityLog create(Ref ref) {
    return networkActivityLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkActivityLog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkActivityLog>(value),
    );
  }
}

String _$networkActivityLogHash() =>
    r'8e0bd3fb441a36394a42bac11d5f0ad77edaf10e';

/// Organisation policy that switches the network off (MDM
/// `network_disabled`). The default is "not managed"; `bootstrap` overrides
/// it with the LIC-04 managed configuration.

@ProviderFor(managedNetworkDisabled)
final managedNetworkDisabledProvider = ManagedNetworkDisabledProvider._();

/// Organisation policy that switches the network off (MDM
/// `network_disabled`). The default is "not managed"; `bootstrap` overrides
/// it with the LIC-04 managed configuration.

final class ManagedNetworkDisabledProvider
    extends
        $FunctionalProvider<
          Future<bool> Function(),
          Future<bool> Function(),
          Future<bool> Function()
        >
    with $Provider<Future<bool> Function()> {
  /// Organisation policy that switches the network off (MDM
  /// `network_disabled`). The default is "not managed"; `bootstrap` overrides
  /// it with the LIC-04 managed configuration.
  ManagedNetworkDisabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managedNetworkDisabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managedNetworkDisabledHash();

  @$internal
  @override
  $ProviderElement<Future<bool> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<bool> Function() create(Ref ref) {
    return managedNetworkDisabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<bool> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<bool> Function()>(value),
    );
  }
}

String _$managedNetworkDisabledHash() =>
    r'9f189fc42fe1c5dcd09297f79cdffb4dc9e6dd8d';

@ProviderFor(networkGateway)
final networkGatewayProvider = NetworkGatewayProvider._();

final class NetworkGatewayProvider
    extends $FunctionalProvider<NetworkGateway, NetworkGateway, NetworkGateway>
    with $Provider<NetworkGateway> {
  NetworkGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkGatewayHash();

  @$internal
  @override
  $ProviderElement<NetworkGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NetworkGateway create(Ref ref) {
    return networkGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkGateway>(value),
    );
  }
}

String _$networkGatewayHash() => r'c25618c1a9cbe3e3c1db695022eef8fa784a7b80';
