import 'dart:math';

import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// Length of every key the vault hands out (AES-256 / sqlite3mc key).
const kVaultKeyBytes = 32;

/// Name of the drift database key (SEC-01).
const kDatabaseKeyName = 'db.v1';

/// A data key released by the [KeyVault]. Never log [bytes].
class VaultKey {
  VaultKey(this.bytes, {required this.hardwareBacked}) {
    if (bytes.length != kVaultKeyBytes) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must be 32 bytes');
    }
  }

  final Uint8List bytes;

  /// The wrapping key lives in secure hardware (Secure Enclave-protected
  /// Keychain on iOS; TEE/StrongBox Android Keystore).
  final bool hardwareBacked;

  @override
  String toString() => 'VaultKey(<redacted>)';
}

/// Random 32-byte data keys kept by the OS key store (ADR-SEC-01):
///
/// - iOS: Keychain generic password, `kSecAttrAccessibleAfterFirstUnlock-
///   ThisDeviceOnly` (background recording/processing can open the DB while
///   the device is locked; never synced or restored to another device).
/// - Android: the data key is AES-GCM-wrapped by a non-exportable
///   AndroidKeyStore AES-256 key (StrongBox when available,
///   `setUserAuthenticationRequired(false)` so background work runs) and the
///   wrapped blob is stored under `noBackupFilesDir`.
///
/// Deleting a key is crypto-shredding: data encrypted with it is unreadable.
abstract interface class KeyVault {
  /// Returns key [name], creating it on first use.
  Future<Result<VaultKey>> getOrCreateKey(String name);

  /// Destroys key [name] (no-op when absent).
  Future<Result<void>> deleteKey(String name);

  /// Destroys every key of this app, including the Android wrapping key
  /// ("Delete all data", SEC-04).
  Future<Result<void>> deleteAllKeys();
}

/// [KeyVault] backed by `SecureStoragePlugin` (Swift / Kotlin, channel
/// `vaultvoice/secure_storage`).
class MethodChannelKeyVault implements KeyVault {
  const MethodChannelKeyVault([
    this._channel = const MethodChannel(secureStorageChannel),
  ]);

  final MethodChannel _channel;

  @override
  Future<Result<VaultKey>> getOrCreateKey(String name) async {
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>(
        'getOrCreateKey',
        {'name': name},
      );
      final bytes = reply?['key'];
      if (bytes is! Uint8List || bytes.length != kVaultKeyBytes) {
        return const Err(StorageFailure('key vault: invalid key'));
      }
      return Ok(
        VaultKey(bytes, hardwareBacked: reply?['hardwareBacked'] == true),
      );
    } on PlatformException catch (e) {
      return Err(StorageFailure('key vault: ${e.code}'));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }

  @override
  Future<Result<void>> deleteKey(String name) =>
      _invoke('deleteKey', {'name': name});

  @override
  Future<Result<void>> deleteAllKeys() => _invoke('deleteAllKeys', null);

  Future<Result<void>> _invoke(String method, Object? args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
      return const Ok(null);
    } on PlatformException catch (e) {
      return Err(StorageFailure('key vault: ${e.code}'));
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }
}

/// Channel shared by [MethodChannelKeyVault] and `StorageProtection`.
const secureStorageChannel = 'vaultvoice/secure_storage';

/// In-memory [KeyVault] for tests and host runs (keys die with the process).
class MemoryKeyVault implements KeyVault {
  MemoryKeyVault({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, Uint8List> keys = {};

  @override
  Future<Result<VaultKey>> getOrCreateKey(String name) async {
    final key = keys.putIfAbsent(
      name,
      () => Uint8List.fromList(
        List.generate(kVaultKeyBytes, (_) => _random.nextInt(256)),
      ),
    );
    return Ok(VaultKey(Uint8List.fromList(key), hardwareBacked: false));
  }

  @override
  Future<Result<void>> deleteKey(String name) async {
    keys.remove(name);
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteAllKeys() async {
    keys.clear();
    return const Ok(null);
  }
}
