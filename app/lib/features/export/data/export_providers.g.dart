// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Folder picking + persistent access for the current platform.
///
/// iOS: refreshed (stale) bookmarks are handed to `onRefreshed`; persisting
/// them in `vault_targets` is EXP-05's job once that table exists.

@ProviderFor(vaultFolderAccess)
final vaultFolderAccessProvider = VaultFolderAccessProvider._();

/// Folder picking + persistent access for the current platform.
///
/// iOS: refreshed (stale) bookmarks are handed to `onRefreshed`; persisting
/// them in `vault_targets` is EXP-05's job once that table exists.

final class VaultFolderAccessProvider
    extends
        $FunctionalProvider<
          VaultFolderAccess,
          VaultFolderAccess,
          VaultFolderAccess
        >
    with $Provider<VaultFolderAccess> {
  /// Folder picking + persistent access for the current platform.
  ///
  /// iOS: refreshed (stale) bookmarks are handed to `onRefreshed`; persisting
  /// them in `vault_targets` is EXP-05's job once that table exists.
  VaultFolderAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultFolderAccessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultFolderAccessHash();

  @$internal
  @override
  $ProviderElement<VaultFolderAccess> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VaultFolderAccess create(Ref ref) {
    return vaultFolderAccess(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultFolderAccess value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultFolderAccess>(value),
    );
  }
}

String _$vaultFolderAccessHash() => r'c92b528607c8cd6d57c8e9fcf39d873be22e4553';

/// Detects revoked access and drives the re-grant flow.

@ProviderFor(vaultAccessGuard)
final vaultAccessGuardProvider = VaultAccessGuardProvider._();

/// Detects revoked access and drives the re-grant flow.

final class VaultAccessGuardProvider
    extends
        $FunctionalProvider<
          VaultAccessGuard,
          VaultAccessGuard,
          VaultAccessGuard
        >
    with $Provider<VaultAccessGuard> {
  /// Detects revoked access and drives the re-grant flow.
  VaultAccessGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultAccessGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultAccessGuardHash();

  @$internal
  @override
  $ProviderElement<VaultAccessGuard> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VaultAccessGuard create(Ref ref) {
    return vaultAccessGuard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultAccessGuard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultAccessGuard>(value),
    );
  }
}

String _$vaultAccessGuardHash() => r'b9a558eb56cccd19342279fa4a0cf81af46c1b7f';

/// The app's own folder: default/fallback vault target. Android:
/// app-private `filesDir/vault`; iOS: `Documents/`, visible in Files under
/// "On My iPhone › VaultVoice" (`UIFileSharingEnabled`).

@ProviderFor(appLocalVaultWriter)
final appLocalVaultWriterProvider = AppLocalVaultWriterProvider._();

/// The app's own folder: default/fallback vault target. Android:
/// app-private `filesDir/vault`; iOS: `Documents/`, visible in Files under
/// "On My iPhone › VaultVoice" (`UIFileSharingEnabled`).

final class AppLocalVaultWriterProvider
    extends $FunctionalProvider<VaultWriter, VaultWriter, VaultWriter>
    with $Provider<VaultWriter> {
  /// The app's own folder: default/fallback vault target. Android:
  /// app-private `filesDir/vault`; iOS: `Documents/`, visible in Files under
  /// "On My iPhone › VaultVoice" (`UIFileSharingEnabled`).
  AppLocalVaultWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocalVaultWriterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocalVaultWriterHash();

  @$internal
  @override
  $ProviderElement<VaultWriter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VaultWriter create(Ref ref) {
    return appLocalVaultWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultWriter>(value),
    );
  }
}

String _$appLocalVaultWriterHash() =>
    r'd5f7c8509eff3acdd090ef28ae666da01b125dfe';
