import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/failure.dart';

/// Where a model download is (MDL-02). UI (MDL-03) renders this.
enum DownloadPhase {
  /// Checking space / network before (re)starting.
  checking,

  /// Bytes are arriving.
  downloading,

  /// Waiting before a retry (backoff).
  retrying,

  /// Stopped by the user or by the network policy; the partial is kept.
  paused,

  /// Checking size + SHA-256 in a background isolate.
  verifying,

  /// Moving into `models/<id>/` and recording `models_installed`.
  installing,

  /// Installed and recorded.
  installed,

  /// Gave up or refused (see [DownloadProgress.failure]).
  failed,

  /// Cancelled by the user; the partial file was deleted.
  cancelled,
}

/// Progress snapshot of one model download.
@immutable
class DownloadProgress {
  const DownloadProgress({
    required this.modelId,
    required this.phase,
    required this.receivedBytes,
    required this.totalBytes,
    this.retry = 0,
    this.failure,
  });

  final String modelId;
  final DownloadPhase phase;
  final int receivedBytes;
  final int totalBytes;

  /// Retries used so far (0 on the first attempt).
  final int retry;
  final Failure? failure;

  double get fraction =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1);

  @override
  String toString() =>
      'DownloadProgress($modelId, ${phase.name}, $receivedBytes/$totalBytes)';
}

/// What starting a download would involve — shown to the user up front
/// (size, cellular opt-in, low-power prompt).
@immutable
class DownloadPlan {
  const DownloadPlan({
    required this.modelId,
    required this.totalBytes,
    required this.alreadyDownloadedBytes,
    required this.requiredFreeBytes,
    required this.freeBytes,
    required this.blocks,
  });

  final String modelId;
  final int totalBytes;

  /// Bytes already in the partial file (a resume).
  final int alreadyDownloadedBytes;
  final int requiredFreeBytes;

  /// Free bytes on the models volume, or null when the platform could not
  /// tell (treated as "not enough").
  final int? freeBytes;

  /// Preconditions that currently prevent starting; empty = can start.
  final Set<ModelDownloadBlock> blocks;

  int get remainingBytes => totalBytes - alreadyDownloadedBytes;
}
