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

/// Why the recording policy (SEC-09) refused a start/resume request.
enum RecordingBlockReason {
  /// A phone or VoIP call is ringing or active ("Recording is unavailable
  /// during calls").
  inCall,

  /// The call state could not be determined; the guard fails closed.
  callGuardUnavailable,

  /// The request did not come from an allowed user-tap source.
  sourceNotAllowed,

  /// The app is not in the foreground (no background/headless starts).
  notForeground,

  /// The request does not fit the current recording phase.
  invalidState,
}

/// The recording policy refused to open or reopen the microphone.
final class RecordingBlockedFailure extends Failure {
  RecordingBlockedFailure(this.reason)
    : super('recording blocked: ${reason.name}');

  final RecordingBlockReason reason;
}

/// Why a model catalog (manifest + signature) was rejected (MDL-01).
enum CatalogRejection {
  /// Signature file missing fields, wrong algorithm or wrong length.
  malformedSignature,

  /// Signed by a key that is not pinned in the app.
  unknownKey,

  /// Signature does not match the catalog bytes (tampered or forged).
  badSignature,

  /// Catalog `schema` is not one this app understands.
  unknownSchema,

  /// Catalog JSON is invalid or a field breaks the schema.
  malformed,

  /// `issued_at` is older than the bundled / last accepted catalog.
  rollback,

  /// The catalog requires a newer app version.
  appTooOld,

  /// Catalog or signature exceeds the size cap.
  tooLarge,

  /// HTTP status other than 200 when fetching the catalog.
  httpStatus,
}

/// A model catalog failed verification; the previous catalog stays active.
final class CatalogFailure extends Failure {
  CatalogFailure(this.reason) : super('catalog rejected: ${reason.name}');

  final CatalogRejection reason;
}

/// A model file does not match its catalog entry (MDL-01; used by MDL-02).
final class ModelIntegrityFailure extends Failure {
  const ModelIntegrityFailure(this.modelId, {required this.sizeMismatch})
    : super(
        sizeMismatch
            ? 'model size mismatch: $modelId'
            : 'model sha256 mismatch: $modelId',
      );

  final String modelId;

  /// True when the byte count differs, false when only the hash differs.
  final bool sizeMismatch;
}

/// A profile definition (or its template) failed validation (PRF-01).
///
/// [issues] hold `path: message` strings that name keys and limits only,
/// never field values (`schema.action_items[].owner: missing maxLength …`).
final class ProfileValidationFailure extends Failure {
  ProfileValidationFailure(List<String> issues)
    : issues = List.unmodifiable(issues),
      super('profile invalid: ${issues.length} issue(s)');

  final List<String> issues;
}

/// A profile operation is not allowed (PRF-01): editing a built-in or
/// managed profile, or reusing an id owned by another profile.
final class ProfileReadOnlyFailure extends Failure {
  const ProfileReadOnlyFailure(super.message);
}
