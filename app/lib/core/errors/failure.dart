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
