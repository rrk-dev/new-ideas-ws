import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings_launcher.g.dart';

/// Opens this app's page in the OS Settings app — the recovery path after
/// the user denied a permission (microphone, notifications). Never requests
/// a permission itself.
abstract interface class AppSettingsLauncher {
  /// Whether the Settings page could be opened.
  Future<bool> openAppSettings();
}

/// Method channel `vaultvoice/app_settings` (`open` → bool):
/// Android `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`
/// (`AppSettingsPlugin.kt`), iOS `UIApplication.openSettingsURLString`
/// (`AppDelegate.swift`).
class MethodChannelAppSettingsLauncher implements AppSettingsLauncher {
  const MethodChannelAppSettingsLauncher([
    this._channel = const MethodChannel(channelName),
  ]);

  static const channelName = 'vaultvoice/app_settings';

  final MethodChannel _channel;

  @override
  Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('open') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
AppSettingsLauncher appSettingsLauncher(Ref ref) =>
    const MethodChannelAppSettingsLauncher();
