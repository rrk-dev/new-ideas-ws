import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_path.dart';

/// `PlatformException.code`s shared by the SAF (Kotlin) and bookmark (Swift)
/// host APIs. Keep in sync with `SafHostApiImpl.kt` / `BookmarkHostApiImpl`.
abstract final class VaultErrorCodes {
  static const revoked = 'revoked';
  static const unavailable = 'unavailable';
  static const exists = 'exists';
  static const notFound = 'not_found';
  static const invalid = 'invalid';
  static const busy = 'busy';
  static const io = 'io';
}

/// Maps a host-API error to a content-free [Failure]. The exception message
/// is dropped on purpose: it may contain a file name.
Failure vaultFailureFrom(PlatformException e) => switch (e.code) {
  VaultErrorCodes.revoked => const VaultAccessFailure.revoked(),
  VaultErrorCodes.unavailable => const VaultAccessFailure.unavailable(),
  VaultErrorCodes.exists => const VaultFileExistsFailure(),
  VaultErrorCodes.notFound => const StorageFailure('vault path not found'),
  VaultErrorCodes.invalid => const StorageFailure('invalid vault path'),
  VaultErrorCodes.busy => const StorageFailure('folder picker busy'),
  VaultErrorCodes.io => const StorageFailure('vault io error'),
  // `channel-error` = no host implementation (e.g. wrong platform).
  _ => const UnexpectedFailure('PlatformException'),
};

/// Runs a host-API call, converting platform errors into [Err].
Future<Result<T>> guardVaultCall<T>(Future<T> Function() call) async {
  try {
    return Ok(await call());
  } on PlatformException catch (e) {
    return Err(vaultFailureFrom(e));
  } on Exception catch (e) {
    // Never rethrow across the layer boundary; keep only the type.
    return Err(UnexpectedFailure(e.runtimeType.toString()));
  }
}

/// Validates [relativePath] with [VaultPath] and, when valid, runs [call]
/// with its canonical form under [guardVaultCall].
Future<Result<T>> withVaultPath<T>(
  String relativePath,
  Future<T> Function(String path) call, {
  bool allowRoot = false,
}) async {
  switch (VaultPath.parse(relativePath, allowRoot: allowRoot)) {
    case Err(:final failure):
      return Err(failure);
    case Ok(:final value):
      return await guardVaultCall(() => call(value.value));
  }
}
