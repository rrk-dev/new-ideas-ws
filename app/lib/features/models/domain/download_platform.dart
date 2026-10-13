import 'package:flutter/foundation.dart';

/// Network condition relevant to the Wi-Fi-only default (MDL-02).
@immutable
class NetworkStatus {
  const NetworkStatus({
    required this.connected,
    required this.unmetered,
    this.lowPowerMode = false,
  });

  /// Some network path is up.
  final bool connected;

  /// The path is Wi-Fi/Ethernet (not cellular, not expensive/metered).
  final bool unmetered;

  /// iOS Low Power Mode / Android battery saver.
  final bool lowPowerMode;
}

/// Device facts the downloader needs; implemented natively per platform
/// (`ModelDownloadPlugin` on iOS/Android), faked in tests.
abstract interface class DownloadDeviceInfo {
  /// Free bytes on the volume holding [path], or null if unknown.
  Future<int?> freeBytes(String path);

  Future<NetworkStatus> networkStatus();

  /// Marks [path] (a directory) excluded from iCloud/iTunes backup (iOS
  /// `isExcludedFromBackup`). Android excludes everything via manifest
  /// backup rules, so it returns true there. False when it failed.
  Future<bool> excludeFromBackup(String path);
}

/// Keeps the process alive while an in-process download runs in the
/// background: Android foreground service (type `dataSync`), iOS
/// `beginBackgroundTask` (short grace only — long iOS downloads use the
/// background `URLSession` transport instead).
abstract interface class DownloadKeepAlive {
  /// [title] is public catalog data (model display name), never user content.
  Future<void> start(String title);

  Future<void> update(int receivedBytes, int totalBytes);

  Future<void> stop();
}

/// No keep-alive (host tests, platforms without one).
class NoDownloadKeepAlive implements DownloadKeepAlive {
  const NoDownloadKeepAlive();

  @override
  Future<void> start(String title) async {}

  @override
  Future<void> update(int receivedBytes, int totalBytes) async {}

  @override
  Future<void> stop() async {}
}
