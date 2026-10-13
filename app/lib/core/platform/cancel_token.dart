/// Cooperative cancellation handed to long-running engine calls.
class CancelToken {
  bool _cancelled = false;

  /// Whether [cancel] was called.
  bool get isCancelled => _cancelled;

  /// Requests cancellation; engines stop at the next checkpoint and return
  /// `CancelledFailure`.
  void cancel() => _cancelled = true;
}

/// Progress in the range 0.0–1.0.
typedef ProgressCallback = void Function(double fraction);
