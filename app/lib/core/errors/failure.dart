import 'package:vaultvoice/core/platform/vault_writer.dart';

/// Expected, recoverable errors that cross layer boundaries.
///
/// Messages must be content-free: never put transcript text, LLM output,
/// file names or vault paths in a failure (see `vv-privacy-security`).
sealed class Failure {
  const Failure(this.message);

  /// Short, content-free description for logs and diagnostics.
  final String message;

  @override
  String toString() => 'Failure($message)';
}

/// A required OS permission (microphone, folder access) is missing.
final class PermissionFailure extends Failure {
  const PermissionFailure(this.permission)
    : super('permission not granted: $permission');

  final String permission;
}

/// Disk is full, unreadable or a path is not writable.
final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

/// A model file required for the operation is not installed.
final class ModelMissingFailure extends Failure {
  const ModelMissingFailure(this.modelId) : super('model missing: $modelId');

  final String modelId;
}

/// The device ran out of memory (or the OS signalled critical pressure).
final class OutOfMemoryFailure extends Failure {
  const OutOfMemoryFailure() : super('out of memory');
}

/// The caller cancelled the operation.
final class CancelledFailure extends Failure {
  const CancelledFailure() : super('cancelled');
}

/// An error code returned by the native bridge (mapped in one place).
final class NativeFailure extends Failure {
  const NativeFailure(this.code, String message) : super(message);

  final int code;
}

/// The network gateway refused a request (host not allowlisted, offline).
final class EgressDeniedFailure extends Failure {
  const EgressDeniedFailure(this.host) : super('egress denied: $host');

  final String host;
}

/// A request that the gateway allowed failed on the wire.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// The vault folder cannot be written: access was [VaultAccess.revoked]
/// (re-pick the folder) or the storage is [VaultAccess.unavailable] (retry).
final class VaultAccessFailure extends Failure {
  /// The grant was withdrawn or the folder moved/deleted: re-pick it.
  const VaultAccessFailure.revoked()
    : access = VaultAccess.revoked,
      super('vault access: revoked');

  /// Storage temporarily unreachable (SD card, iCloud, provider): retry.
  const VaultAccessFailure.unavailable()
    : access = VaultAccess.unavailable,
      super('vault access: unavailable');

  final VaultAccess access;
}

/// A vault file already exists and the write did not allow overwriting.
final class VaultFileExistsFailure extends Failure {
  const VaultFileExistsFailure() : super('vault file exists');
}

/// A bug or an unclassified exception caught at a boundary.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(this.errorType) : super('unexpected: $errorType');

  /// `runtimeType` of the caught error (never its message, which may leak
  /// content).
  final String errorType;
}
