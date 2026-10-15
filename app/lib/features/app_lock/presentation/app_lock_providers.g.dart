// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lock_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceAuthenticator)
final deviceAuthenticatorProvider = DeviceAuthenticatorProvider._();

final class DeviceAuthenticatorProvider
    extends
        $FunctionalProvider<
          DeviceAuthenticator,
          DeviceAuthenticator,
          DeviceAuthenticator
        >
    with $Provider<DeviceAuthenticator> {
  DeviceAuthenticatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceAuthenticatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceAuthenticatorHash();

  @$internal
  @override
  $ProviderElement<DeviceAuthenticator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeviceAuthenticator create(Ref ref) {
    return deviceAuthenticator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceAuthenticator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceAuthenticator>(value),
    );
  }
}

String _$deviceAuthenticatorHash() =>
    r'44cbcea1c99b463f23389b30ccf59561ed7fbf0d';

@ProviderFor(privacyScreen)
final privacyScreenProvider = PrivacyScreenProvider._();

final class PrivacyScreenProvider
    extends $FunctionalProvider<PrivacyScreen, PrivacyScreen, PrivacyScreen>
    with $Provider<PrivacyScreen> {
  PrivacyScreenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacyScreenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacyScreenHash();

  @$internal
  @override
  $ProviderElement<PrivacyScreen> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PrivacyScreen create(Ref ref) {
    return privacyScreen(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivacyScreen value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivacyScreen>(value),
    );
  }
}

String _$privacyScreenHash() => r'546227fff4c5e99ab0be53d783e382c95da5db2d';

/// App lock state (SEC-03). Starts **locked** until the settings are known
/// so content never flashes before the lock decision; unlocks immediately
/// when the lock turns out to be off. Kept alive by `AppLockGate`.

@ProviderFor(AppLock)
final appLockProvider = AppLockProvider._();

/// App lock state (SEC-03). Starts **locked** until the settings are known
/// so content never flashes before the lock decision; unlocks immediately
/// when the lock turns out to be off. Kept alive by `AppLockGate`.
final class AppLockProvider extends $NotifierProvider<AppLock, AppLockView> {
  /// App lock state (SEC-03). Starts **locked** until the settings are known
  /// so content never flashes before the lock decision; unlocks immediately
  /// when the lock turns out to be off. Kept alive by `AppLockGate`.
  AppLockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockHash();

  @$internal
  @override
  AppLock create() => AppLock();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLockView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLockView>(value),
    );
  }
}

String _$appLockHash() => r'd08d5cc9fdd848a3b1d681509c3656909340de0d';

/// App lock state (SEC-03). Starts **locked** until the settings are known
/// so content never flashes before the lock decision; unlocks immediately
/// when the lock turns out to be off. Kept alive by `AppLockGate`.

abstract class _$AppLock extends $Notifier<AppLockView> {
  AppLockView build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppLockView, AppLockView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppLockView, AppLockView>,
              AppLockView,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
