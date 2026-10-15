// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Organisation-managed settings; LIC-04 overrides the source.

@ProviderFor(managedSettingsSource)
final managedSettingsSourceProvider = ManagedSettingsSourceProvider._();

/// Organisation-managed settings; LIC-04 overrides the source.

final class ManagedSettingsSourceProvider
    extends
        $FunctionalProvider<
          ManagedSettingsSource,
          ManagedSettingsSource,
          ManagedSettingsSource
        >
    with $Provider<ManagedSettingsSource> {
  /// Organisation-managed settings; LIC-04 overrides the source.
  ManagedSettingsSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managedSettingsSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managedSettingsSourceHash();

  @$internal
  @override
  $ProviderElement<ManagedSettingsSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ManagedSettingsSource create(Ref ref) {
    return managedSettingsSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ManagedSettingsSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ManagedSettingsSource>(value),
    );
  }
}

String _$managedSettingsSourceHash() =>
    r'4b9d99dec11ff419ffa9fc9ff0bd0b9f128b661d';

@ProviderFor(managedSettings)
final managedSettingsProvider = ManagedSettingsProvider._();

final class ManagedSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ManagedSettings>,
          ManagedSettings,
          Stream<ManagedSettings>
        >
    with $FutureModifier<ManagedSettings>, $StreamProvider<ManagedSettings> {
  ManagedSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'managedSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$managedSettingsHash();

  @$internal
  @override
  $StreamProviderElement<ManagedSettings> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ManagedSettings> create(Ref ref) {
    return managedSettings(ref);
  }
}

String _$managedSettingsHash() => r'f10e70a1d25806f2fc4786b94e41cd939715d4e3';

/// Licence summary + actions: LIC-01's entitlement service (integration
/// wave 2); LIC-02/03 add restore / enterprise install behind the same port.

@ProviderFor(licenseSettingsPort)
final licenseSettingsPortProvider = LicenseSettingsPortProvider._();

/// Licence summary + actions: LIC-01's entitlement service (integration
/// wave 2); LIC-02/03 add restore / enterprise install behind the same port.

final class LicenseSettingsPortProvider
    extends
        $FunctionalProvider<
          LicenseSettingsPort,
          LicenseSettingsPort,
          LicenseSettingsPort
        >
    with $Provider<LicenseSettingsPort> {
  /// Licence summary + actions: LIC-01's entitlement service (integration
  /// wave 2); LIC-02/03 add restore / enterprise install behind the same port.
  LicenseSettingsPortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'licenseSettingsPortProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$licenseSettingsPortHash();

  @$internal
  @override
  $ProviderElement<LicenseSettingsPort> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LicenseSettingsPort create(Ref ref) {
    return licenseSettingsPort(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LicenseSettingsPort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LicenseSettingsPort>(value),
    );
  }
}

String _$licenseSettingsPortHash() =>
    r'96e15c1171909dd35255048086659008f354bc56';

@ProviderFor(licenseSummary)
final licenseSummaryProvider = LicenseSummaryProvider._();

final class LicenseSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<LicenseSummary>,
          LicenseSummary,
          Stream<LicenseSummary>
        >
    with $FutureModifier<LicenseSummary>, $StreamProvider<LicenseSummary> {
  LicenseSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'licenseSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$licenseSummaryHash();

  @$internal
  @override
  $StreamProviderElement<LicenseSummary> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<LicenseSummary> create(Ref ref) {
    return licenseSummary(ref);
  }
}

String _$licenseSummaryHash() => r'3aa0a98526375b29dc30ef217ddc8e826bf3ccd0';

/// "Delete all data": SEC-04's secure wipe (DB rows, files, key, grants).

@ProviderFor(dataWiper)
final dataWiperProvider = DataWiperProvider._();

/// "Delete all data": SEC-04's secure wipe (DB rows, files, key, grants).

final class DataWiperProvider
    extends $FunctionalProvider<DataWiper, DataWiper, DataWiper>
    with $Provider<DataWiper> {
  /// "Delete all data": SEC-04's secure wipe (DB rows, files, key, grants).
  DataWiperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataWiperProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataWiperHash();

  @$internal
  @override
  $ProviderElement<DataWiper> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DataWiper create(Ref ref) {
    return dataWiper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataWiper value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataWiper>(value),
    );
  }
}

String _$dataWiperHash() => r'2838b99fdac5f3990a7e4a30b55a1eb4f5bb1f1e';

/// Where user settings live: the FND-04 `settings` table.

@ProviderFor(settingsStore)
final settingsStoreProvider = SettingsStoreProvider._();

/// Where user settings live: the FND-04 `settings` table.

final class SettingsStoreProvider
    extends $FunctionalProvider<SettingsStore, SettingsStore, SettingsStore>
    with $Provider<SettingsStore> {
  /// Where user settings live: the FND-04 `settings` table.
  SettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsStoreHash();

  @$internal
  @override
  $ProviderElement<SettingsStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsStore create(Ref ref) {
    return settingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsStore>(value),
    );
  }
}

String _$settingsStoreHash() => r'4fd21da621690efd5964d9c7beb33cc8b0e86cc6';

/// The user's stored value of [key] (raw JSON, null when unset).

@ProviderFor(storedSetting)
final storedSettingProvider = StoredSettingFamily._();

/// The user's stored value of [key] (raw JSON, null when unset).

final class StoredSettingProvider
    extends $FunctionalProvider<AsyncValue<Object?>, Object?, Stream<Object?>>
    with $FutureModifier<Object?>, $StreamProvider<Object?> {
  /// The user's stored value of [key] (raw JSON, null when unset).
  StoredSettingProvider._({
    required StoredSettingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'storedSettingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$storedSettingHash();

  @override
  String toString() {
    return r'storedSettingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Object?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Object?> create(Ref ref) {
    final argument = this.argument as String;
    return storedSetting(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StoredSettingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$storedSettingHash() => r'aa4fe620a9fce8d642dabacd8c4de11e20b29c62';

/// The user's stored value of [key] (raw JSON, null when unset).

final class StoredSettingFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Object?>, String> {
  StoredSettingFamily._()
    : super(
        retry: null,
        name: r'storedSettingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The user's stored value of [key] (raw JSON, null when unset).

  StoredSettingProvider call(String key) =>
      StoredSettingProvider._(argument: key, from: this);

  @override
  String toString() => r'storedSettingProvider';
}

/// Effective value: managed value › user value › default.

@ProviderFor(settingState)
final settingStateProvider = SettingStateFamily._();

/// Effective value: managed value › user value › default.

final class SettingStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<SettingState>,
          SettingState,
          FutureOr<SettingState>
        >
    with $FutureModifier<SettingState>, $FutureProvider<SettingState> {
  /// Effective value: managed value › user value › default.
  SettingStateProvider._({
    required SettingStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'settingStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$settingStateHash();

  @override
  String toString() {
    return r'settingStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SettingState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SettingState> create(Ref ref) {
    final argument = this.argument as String;
    return settingState(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SettingStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$settingStateHash() => r'f5a48542e9adf9c85ddc18bacde94c54e4d4ddd3';

/// Effective value: managed value › user value › default.

final class SettingStateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SettingState>, String> {
  SettingStateFamily._()
    : super(
        retry: null,
        name: r'settingStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Effective value: managed value › user value › default.

  SettingStateProvider call(String key) =>
      SettingStateProvider._(argument: key, from: this);

  @override
  String toString() => r'settingStateProvider';
}

/// Writes settings; refuses managed keys and invalid values.

@ProviderFor(settingsWriter)
final settingsWriterProvider = SettingsWriterProvider._();

/// Writes settings; refuses managed keys and invalid values.

final class SettingsWriterProvider
    extends $FunctionalProvider<SettingsWriter, SettingsWriter, SettingsWriter>
    with $Provider<SettingsWriter> {
  /// Writes settings; refuses managed keys and invalid values.
  SettingsWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsWriterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsWriterHash();

  @$internal
  @override
  $ProviderElement<SettingsWriter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsWriter create(Ref ref) {
    return settingsWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsWriter>(value),
    );
  }
}

String _$settingsWriterHash() => r'925ba596068c4ff96926ec4d0b505d726469c134';

/// Vault targets, oldest first (Settings → Export → Vault folders).

@ProviderFor(vaultTargets)
final vaultTargetsProvider = VaultTargetsProvider._();

/// Vault targets, oldest first (Settings → Export → Vault folders).

final class VaultTargetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VaultTargetInfo>>,
          List<VaultTargetInfo>,
          Stream<List<VaultTargetInfo>>
        >
    with
        $FutureModifier<List<VaultTargetInfo>>,
        $StreamProvider<List<VaultTargetInfo>> {
  /// Vault targets, oldest first (Settings → Export → Vault folders).
  VaultTargetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultTargetsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultTargetsHash();

  @$internal
  @override
  $StreamProviderElement<List<VaultTargetInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<VaultTargetInfo>> create(Ref ref) {
    return vaultTargets(ref);
  }
}

String _$vaultTargetsHash() => r'dedde34e7f797268903a1c20aa604722ff441ea2';

/// Routing rules in evaluation order.

@ProviderFor(routingRules)
final routingRulesProvider = RoutingRulesProvider._();

/// Routing rules in evaluation order.

final class RoutingRulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoutingRuleInfo>>,
          List<RoutingRuleInfo>,
          Stream<List<RoutingRuleInfo>>
        >
    with
        $FutureModifier<List<RoutingRuleInfo>>,
        $StreamProvider<List<RoutingRuleInfo>> {
  /// Routing rules in evaluation order.
  RoutingRulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routingRulesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routingRulesHash();

  @$internal
  @override
  $StreamProviderElement<List<RoutingRuleInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoutingRuleInfo>> create(Ref ref) {
    return routingRules(ref);
  }
}

String _$routingRulesHash() => r'f9aa8f9bbd269b7cd1e7700f3b90543ba6ec074c';
