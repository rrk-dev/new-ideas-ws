import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/failure.dart';

/// Pause/cancel signal shared between the downloader and a transport.
class DownloadControl {
  final _stopped = Completer<void>();
  bool _cancel = false;

  /// Completes when [pause] or [cancel] was called.
  Future<void> get stopped => _stopped.future;

  bool get isStopped => _stopped.isCompleted;

  /// True when stopped by [cancel] (partial is deleted) rather than [pause].
  bool get isCancelled => _cancel;

  void pause() {
    if (!_stopped.isCompleted) _stopped.complete();
  }

  void cancel() {
    _cancel = true;
    if (!_stopped.isCompleted) _stopped.complete();
  }
}

/// One attempt to bring [partial] up to [totalBytes] from one URL.
@immutable
class TransportRequest {
  const TransportRequest({
    required this.modelId,
    required this.uri,
    required this.partial,
    required this.offset,
    required this.totalBytes,
    required this.headers,
    required this.allowCellular,
    this.ifRange,
  });

  final String modelId;

  /// Catalog URL (redirects are resolved and validated by the transport).
  final Uri uri;

  /// `models/.partial/<id>`; bytes are appended from [offset].
  final File partial;

  /// Current length of [partial]; `Range: bytes=<offset>-` when > 0.
  final int offset;
  final int totalBytes;

  /// Anonymous headers (`kAnonymousRequestHeaders`); `Range` / `If-Range`
  /// are added by the transport.
  final Map<String, String> headers;
  final bool allowCellular;

  /// Strong validator from an earlier response (`If-Range`).
  final String? ifRange;
}

/// Result of one [DownloadTransport.fetch].
sealed class TransportOutcome {
  const TransportOutcome();
}

/// The server sent everything up to the end of the file.
final class TransportCompleted extends TransportOutcome {
  const TransportCompleted({this.validator});

  /// Strong ETag of the response, if any (stored for `If-Range`).
  final String? validator;
}

/// HTTP 416 for the requested range.
final class TransportRangeNotSatisfiable extends TransportOutcome {
  const TransportRangeNotSatisfiable();
}

/// Paused or cancelled through [DownloadControl].
final class TransportStopped extends TransportOutcome {
  const TransportStopped();
}

/// The network policy changed mid-download (e.g. Wi-Fi lost and cellular
/// not allowed); the partial is kept.
final class TransportBlocked extends TransportOutcome {
  const TransportBlocked(this.failure);
  final Failure failure;
}

/// The attempt failed. [retryable]: network error, 5xx, 429 (back off);
/// otherwise (4xx, egress denied) only the next URL is tried.
final class TransportFailed extends TransportOutcome {
  const TransportFailed(this.failure, {required this.retryable});
  final Failure failure;
  final bool retryable;
}

/// Moves bytes from a URL into the partial file.
abstract interface class DownloadTransport {
  /// [onProgress] gets the partial file's new length. [checkpoint] is
  /// awaited periodically; a non-null failure ends the attempt with
  /// [TransportBlocked].
  Future<TransportOutcome> fetch(
    TransportRequest request, {
    required DownloadControl control,
    required void Function(int fileLength) onProgress,
    required Future<Failure?> Function() checkpoint,
  });
}
