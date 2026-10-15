import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/security/key_vault.dart';

/// OS file protection of the `vv/` storage root (ADR-SEC-01).
class StorageProtectionInfo {
  const StorageProtectionInfo({
    required this.protectionClass,
    required this.excludedFromBackup,
  });

  /// iOS: `completeUntilFirstUserAuthentication`; Android:
  /// `credentialEncrypted` (file-based encryption of `filesDir`).
  final String protectionClass;

  /// iOS `isExcludedFromBackup` on the directory; Android: backups are
  /// disabled in the manifest (`allowBackup=false` + extraction rules).
  final bool excludedFromBackup;
}

/// Applies the chosen OS protection to the app storage root.
abstract interface class StorageProtection {
  /// Creates [directory] if needed, sets the iOS Data Protection class
  /// `NSFileProtectionCompleteUntilFirstUserAuthentication` (inherited by new
  /// files; `.complete` would break background recording while locked) and
  /// excludes it from iCloud/iTunes backup.
  Future<Result<StorageProtectionInfo>> protectDirectory(String directory);
}

class MethodChannelStorageProtection implements StorageProtection {
  const MethodChannelStorageProtection([
    this._channel = const MethodChannel(secureStorageChannel),
  ]);

  final MethodChannel _channel;

  @override
  Future<Result<StorageProtectionInfo>> protectDirectory(
    String directory,
  ) async {
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>(
        'protectDirectory',
        {'path': directory},
      );
      return Ok(
        StorageProtectionInfo(
          protectionClass: reply?['protectionClass'] as String? ?? 'unknown',
          excludedFromBackup: reply?['excludedFromBackup'] == true,
        ),
      );
    } on PlatformException catch (e) {
      return Err(StorageFailure('storage protection: ${e.code}'));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
