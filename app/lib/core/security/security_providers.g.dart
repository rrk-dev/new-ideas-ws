// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// OS key store. Tests and host runs use the in-memory vault; `bootstrap`
/// installs the Keychain/Keystore one on iOS and Android.

@ProviderFor(keyVault)
final keyVaultProvider = KeyVaultProvider._();

/// OS key store. Tests and host runs use the in-memory vault; `bootstrap`
/// installs the Keychain/Keystore one on iOS and Android.

final class KeyVaultProvider
    extends $FunctionalProvider<KeyVault, KeyVault, KeyVault>
    with $Provider<KeyVault> {
  /// OS key store. Tests and host runs use the in-memory vault; `bootstrap`
  /// installs the Keychain/Keystore one on iOS and Android.
  KeyVaultProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'keyVaultProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keyVaultHash();

  @$internal
  @override
  $ProviderElement<KeyVault> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KeyVault create(Ref ref) {
    return keyVault(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KeyVault value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KeyVault>(value),
    );
  }
}

String _$keyVaultHash() => r'40b75006d83571ed610b2a6eab745993f9bd6da7';

@ProviderFor(encryptionStatus)
final encryptionStatusProvider = EncryptionStatusProvider._();

final class EncryptionStatusProvider
    extends
        $FunctionalProvider<
          EncryptionStatus,
          EncryptionStatus,
          EncryptionStatus
        >
    with $Provider<EncryptionStatus> {
  EncryptionStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'encryptionStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$encryptionStatusHash();

  @$internal
  @override
  $ProviderElement<EncryptionStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EncryptionStatus create(Ref ref) {
    return encryptionStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EncryptionStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EncryptionStatus>(value),
    );
  }
}

String _$encryptionStatusHash() => r'0d542206d51acbd07e9f472cc2c64b6d20df7427';

/// Crypto-shredding of the database key (SEC-04 "Delete all data").

@ProviderFor(databaseKeyRotation)
final databaseKeyRotationProvider = DatabaseKeyRotationProvider._();

/// Crypto-shredding of the database key (SEC-04 "Delete all data").

final class DatabaseKeyRotationProvider
    extends
        $FunctionalProvider<
          AsyncValue<DatabaseKeyRotation>,
          DatabaseKeyRotation,
          FutureOr<DatabaseKeyRotation>
        >
    with
        $FutureModifier<DatabaseKeyRotation>,
        $FutureProvider<DatabaseKeyRotation> {
  /// Crypto-shredding of the database key (SEC-04 "Delete all data").
  DatabaseKeyRotationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseKeyRotationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseKeyRotationHash();

  @$internal
  @override
  $FutureProviderElement<DatabaseKeyRotation> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DatabaseKeyRotation> create(Ref ref) {
    return databaseKeyRotation(ref);
  }
}

String _$databaseKeyRotationHash() =>
    r'4843a623c80b95d4a44a250d72910b651ab08fc2';
