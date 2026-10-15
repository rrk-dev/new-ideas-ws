import 'package:flutter/services.dart';
import 'package:vaultvoice/features/app_lock/domain/app_lock.dart';

/// [DeviceAuthenticator] over channel `vaultvoice/device_auth`
/// (`AppLockPlugin.swift`: `LAContext.deviceOwnerAuthentication`;
/// `AppLockPlugin.kt`: platform `BiometricPrompt` / confirm-credential).
/// Biometrics with the device passcode as fallback (ADR-SEC-03).
class MethodChannelDeviceAuthenticator implements DeviceAuthenticator {
  const MethodChannelDeviceAuthenticator([
    this._channel = const MethodChannel(channelName),
  ]);

  static const channelName = 'vaultvoice/device_auth';

  final MethodChannel _channel;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      final reply = await _channel.invokeMethod<String>('authenticate', {
        'reason': reason,
      });
      return switch (reply) {
        'success' => AuthOutcome.success,
        'unavailable' => AuthOutcome.unavailable,
        _ => AuthOutcome.failed,
      };
    } on MissingPluginException {
      // No platform implementation (host): nothing to authenticate with.
      return AuthOutcome.unavailable;
    } on PlatformException {
      return AuthOutcome.failed;
    }
  }
}

/// [PrivacyScreen] over channel `vaultvoice/privacy_screen` (same plugin).
class MethodChannelPrivacyScreen implements PrivacyScreen {
  const MethodChannelPrivacyScreen([
    this._channel = const MethodChannel(channelName),
  ]);

  static const channelName = 'vaultvoice/privacy_screen';

  final MethodChannel _channel;

  @override
  Future<void> setEnabled({required bool enabled}) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on MissingPluginException {
      // Host / tests: no native snapshot to protect.
    } on PlatformException {
      // Best effort: the in-app lock screen still hides content.
    }
  }
}
