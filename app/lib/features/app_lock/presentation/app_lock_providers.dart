import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/app_lock/data/platform_app_lock.dart';
import 'package:vaultvoice/features/app_lock/domain/app_lock.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'app_lock_providers.g.dart';

@Riverpod(keepAlive: true)
DeviceAuthenticator deviceAuthenticator(Ref ref) =>
    const MethodChannelDeviceAuthenticator();

@Riverpod(keepAlive: true)
PrivacyScreen privacyScreen(Ref ref) => const MethodChannelPrivacyScreen();

/// What the lock gate renders.
class AppLockView {
  const AppLockView({
    required this.enabled,
    required this.locked,
    this.authenticating = false,
    this.unavailable = false,
  });

  /// Settings loaded and the lock is on (user choice or MDM
  /// `force_app_lock`, LIC-04 → managed `security.app_lock = true`).
  final bool enabled;
  final bool locked;
  final bool authenticating;

  /// The last attempt found no device credentials.
  final bool unavailable;
}

/// App lock state (SEC-03). Starts **locked** until the settings are known
/// so content never flashes before the lock decision; unlocks immediately
/// when the lock turns out to be off. Kept alive by `AppLockGate`.
@riverpod
class AppLock extends _$AppLock {
  AppLockMachine? _machine;

  @override
  AppLockView build() {
    final enabled = ref.watch(settingStateProvider(AppSettings.appLock.key));
    final timeout = ref.watch(
      settingStateProvider(AppSettings.lockTimeout.key),
    );
    final on = enabled.value?.value;
    final option = timeout.value?.value;
    if (on is! bool || option is! String) {
      // Still loading, or the settings store failed: fail closed only while
      // loading; an error falls back to the default (lock off).
      final failed = enabled.hasError || timeout.hasError;
      return AppLockView(enabled: false, locked: !failed);
    }
    (_machine ??= AppLockMachine(enabled: on, timeout: lockTimeoutFor(option)))
      ..enabled = on
      ..timeout = lockTimeoutFor(option);
    ref.read(privacyScreenProvider).setEnabled(enabled: on).ignore();
    return _view();
  }

  AppLockView _view({bool authenticating = false, bool unavailable = false}) =>
      AppLockView(
        enabled: _machine?.enabled ?? false,
        locked: _machine?.locked ?? true,
        authenticating: authenticating,
        unavailable: unavailable,
      );

  void backgrounded() => _machine?.backgrounded(ref.read(clockProvider).now());

  void resumed() {
    _machine?.resumed(ref.read(clockProvider).now());
    state = _view();
  }

  /// Shows the OS prompt; [reason] is the localised prompt text.
  Future<void> unlock(String reason) async {
    final machine = _machine;
    if (machine == null || !machine.locked || state.authenticating) return;
    state = _view(authenticating: true);
    final outcome = await ref
        .read(deviceAuthenticatorProvider)
        .authenticate(reason);
    machine.authenticated(outcome);
    state = _view(unavailable: outcome == AuthOutcome.unavailable);
  }
}
