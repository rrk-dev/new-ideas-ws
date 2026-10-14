import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/models/domain/download_transport.dart';

/// In-process transport: a streamed GET through the [NetworkGateway]
/// (redirects validated hop by hop), appending to the partial file with
/// HTTP Range resume. Used on Android (kept alive by a `dataSync`
/// foreground service) and in host tests; iOS uses it in the foreground.
class GatewayDownloadTransport implements DownloadTransport {
  GatewayDownloadTransport(
    this._gateway, {
    this.checkpointEveryBytes = 8 * 1024 * 1024,
  });

  final NetworkGateway _gateway;

  /// How often (in received bytes) the network policy is re-checked.
  final int checkpointEveryBytes;

  static final _contentRange = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$');

  @override
  Future<TransportOutcome> fetch(
    TransportRequest request, {
    required DownloadControl control,
    required void Function(int fileLength) onProgress,
    required Future<Failure?> Function() checkpoint,
  }) async {
    final offset = request.offset;
    final headers = {
      ...request.headers,
      if (offset > 0) 'Range': 'bytes=$offset-',
      if (offset > 0 && request.ifRange != null) 'If-Range': request.ifRange!,
    };
    final res = await _gateway.getStream(request.uri, headers: headers);
    final GatewayStreamedResponse response;
    switch (res) {
      case Err(:final failure):
        return TransportFailed(
          failure,
          retryable: failure is! EgressDeniedFailure,
        );
      case Ok(:final value):
        response = value;
    }

    final status = response.statusCode;
    int start;
    if (status == 200) {
      // Server ignored Range (or If-Range did not match): start over.
      start = 0;
    } else if (status == 206) {
      final range = response.headers['content-range'] ?? '';
      final m = _contentRange.firstMatch(range);
      final total = m?.group(3);
      if (m == null ||
          int.parse(m.group(1)!) != offset ||
          (total != '*' && int.parse(total!) != request.totalBytes)) {
        await _discard(response);
        return const TransportFailed(
          NetworkFailure('unexpected content-range'),
          retryable: false,
        );
      }
      start = offset;
    } else if (status == 416) {
      await _discard(response);
      return const TransportRangeNotSatisfiable();
    } else {
      await _discard(response);
      return TransportFailed(
        NetworkFailure('http $status'),
        retryable: status == 429 || status == 408 || status >= 500,
      );
    }

    final raf = await request.partial.open(
      mode: start == 0 ? FileMode.write : FileMode.append,
    );
    final it = StreamIterator(response.body);
    unawaited(control.stopped.then((_) => it.cancel()));
    var written = start;
    var sinceCheckpoint = 0;
    try {
      while (await it.moveNext()) {
        if (control.isStopped) break;
        var chunk = it.current;
        final room = request.totalBytes - written;
        if (chunk.length > room) chunk = chunk.sublist(0, room);
        await raf.writeFrom(chunk);
        written += chunk.length;
        onProgress(written);
        if (written >= request.totalBytes) break;
        sinceCheckpoint += chunk.length;
        if (sinceCheckpoint >= checkpointEveryBytes) {
          sinceCheckpoint = 0;
          final blocked = await checkpoint();
          if (blocked != null) return TransportBlocked(blocked);
        }
      }
    } on http.ClientException catch (e) {
      return TransportFailed(
        NetworkFailure(e.runtimeType.toString()),
        retryable: true,
      );
    } on IOException catch (e) {
      return TransportFailed(
        NetworkFailure(e.runtimeType.toString()),
        retryable: true,
      );
    } finally {
      await it.cancel();
      await raf.close();
    }
    if (control.isStopped) return const TransportStopped();
    if (written < request.totalBytes) {
      return const TransportFailed(
        NetworkFailure('connection closed early'),
        retryable: true,
      );
    }
    final etag = response.headers['etag'];
    return TransportCompleted(
      validator: etag != null && !etag.startsWith('W/') ? etag : null,
    );
  }

  static Future<void> _discard(GatewayStreamedResponse r) async {
    try {
      await r.body.listen(null).cancel();
    } on Object {
      // Nothing to clean up: the body was never read.
    }
  }
}
