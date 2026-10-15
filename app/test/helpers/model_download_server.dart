import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:vaultvoice/features/models/domain/download_platform.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Header the [LoopbackClient] uses to tell the [ModelFileServer] which
/// (fake) host the gateway asked for. Never sent by app code.
const kTestHostHeader = 'x-vv-test-host';

/// Sends every request to `127.0.0.1:<port>` over plain HTTP, keeping the
/// original https host in [kTestHostHeader]. Lets the real
/// `NetworkGateway` (https + allowlist checks) talk to a local test server.
class LoopbackClient extends http.BaseClient {
  LoopbackClient(this.port);

  final int port;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final url = request.url;
    final target = url.replace(scheme: 'http', host: '127.0.0.1', port: port);
    final forwarded = http.Request(request.method, target)
      ..followRedirects = request.followRedirects
      ..headers.addAll(request.headers)
      ..headers[kTestHostHeader] = url.host;
    return _inner.send(forwarded);
  }

  @override
  void close() => _inner.close();
}

/// One request the server saw.
class SeenRequest {
  SeenRequest(this.host, this.uri, this.headers);
  final String host;
  final Uri uri;

  /// Lower-case names; excludes [kTestHostHeader].
  final Map<String, String> headers;

  String? get range => headers['range'];
}

/// What a `host + path` answers.
sealed class Route {
  const Route();
}

/// Serves [bytes] with Range support.
class FileRoute extends Route {
  FileRoute(
    this.bytes, {
    this.honourRange = true,
    this.corruptTimes = 0,
    this.stallAfterBytes,
    this.etag,
  });

  final Uint8List bytes;

  /// False: ignore `Range` and always send 200 + full body.
  final bool honourRange;

  /// The first N full-body responses flip one byte (hash mismatch).
  int corruptTimes;

  /// The first response stops sending after this many body bytes and keeps
  /// the connection open (simulates a slow link while the app is killed).
  int? stallAfterBytes;
  final String? etag;
}

/// Redirects to [location] with [status].
class RedirectRoute extends Route {
  const RedirectRoute(this.location, {this.status = 302});
  final String location;
  final int status;
}

/// Answers [status] the first [times] requests, then falls through to
/// [then] (or keeps answering [status] when [then] is null).
class StatusRoute extends Route {
  StatusRoute(this.status, {this.times, this.then});
  final int status;
  int? times;
  final Route? then;
}

/// Local HTTP server that plays catalog hosts / mirrors / CDNs.
class ModelFileServer {
  ModelFileServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<ModelFileServer> start() async =>
      ModelFileServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final routes = <String, Route>{};
  final requests = <SeenRequest>[];

  /// Body bytes sent per request (same order as [requests]).
  final bodyBytesSent = <int>[];

  final _stalled = <Completer<void>>[];

  int get port => _server.port;

  /// Requests that reached [host].
  List<SeenRequest> to(String host) => [
    for (final r in requests)
      if (r.host == host) r,
  ];

  /// Releases stalled responses (they then close without more bytes).
  void releaseStalled() {
    for (final c in _stalled) {
      if (!c.isCompleted) c.complete();
    }
  }

  Future<void> close() async {
    releaseStalled();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest req) async {
    final host = req.headers.value(kTestHostHeader) ?? '?';
    final headers = <String, String>{};
    req.headers.forEach((name, values) {
      if (name != kTestHostHeader) headers[name] = values.join(',');
    });
    requests.add(SeenRequest(host, req.uri, headers));
    final index = bodyBytesSent.length;
    bodyBytesSent.add(0);
    final res = req.response;
    try {
      await _answer(routes['$host${req.uri.path}'], req, res, index);
    } on Object {
      // Client went away (killed / cancelled): nothing to do.
    }
  }

  Future<void> _answer(
    Route? route,
    HttpRequest req,
    HttpResponse res,
    int index,
  ) async {
    switch (route) {
      case null:
        res.statusCode = 404;
        await res.close();
      case RedirectRoute(:final location, :final status):
        res
          ..statusCode = status
          ..headers.set('location', location);
        await res.close();
      case StatusRoute(:final status, :final then):
        final left = route.times;
        if (left == null || left > 0 || then == null) {
          if (left != null) route.times = left - 1;
          res.statusCode = status;
          await res.close();
        } else {
          await _answer(then, req, res, index);
        }
      case FileRoute():
        await _serveFile(route, req, res, index);
    }
  }

  Future<void> _serveFile(
    FileRoute route,
    HttpRequest req,
    HttpResponse res,
    int index,
  ) async {
    final total = route.bytes.length;
    var start = 0;
    final range = req.headers.value('range');
    if (route.etag != null) res.headers.set('etag', route.etag!);
    if (route.honourRange && range != null) {
      final m = RegExp(r'^bytes=(\d+)-$').firstMatch(range);
      start = int.parse(m!.group(1)!);
      if (start >= total) {
        res
          ..statusCode = 416
          ..headers.set('content-range', 'bytes */$total');
        await res.close();
        return;
      }
      res
        ..statusCode = 206
        ..headers.set('content-range', 'bytes $start-${total - 1}/$total');
    } else {
      res.statusCode = 200;
    }
    var body = Uint8List.sublistView(route.bytes, start);
    if (start == 0 && route.corruptTimes > 0) {
      route.corruptTimes--;
      body = Uint8List.fromList(body);
      body[body.length ~/ 2] ^= 0xff;
    }
    res.contentLength = body.length;
    final stallAt = route.stallAfterBytes;
    route.stallAfterBytes = null;
    const chunk = 64 * 1024;
    final limit = stallAt == null ? body.length : min(stallAt, body.length);
    for (var o = 0; o < limit; o += chunk) {
      final end = min(o + chunk, limit);
      res.add(Uint8List.sublistView(body, o, end));
      bodyBytesSent[index] += end - o;
      await res.flush();
    }
    if (limit < body.length) {
      final c = Completer<void>();
      _stalled.add(c);
      await c.future;
      // Closing short of Content-Length aborts the connection.
      try {
        await res.close();
      } on Object {
        // Expected: content size below the declared length.
      }
      return;
    }
    await res.close();
  }
}

/// Deterministic pseudo-random model bytes.
Uint8List modelBytes(int length, {int seed = 7}) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

/// A catalog entry for [bytes] served at [urls].
CatalogModel testCatalogModel(
  Uint8List bytes, {
  required List<String> urls,
  String id = 'whisper-tiny.en',
  String file = 'ggml-tiny.en.bin',
  ModelType type = ModelType.stt,
  List<String> companions = const [],
}) => CatalogModel(
  id: id,
  type: type,
  version: '1',
  displayName: 'Whisper Tiny (English)',
  tier: ModelTier.free,
  file: file,
  size: bytes.length,
  sha256: crypto.sha256.convert(bytes).toString(),
  minRamMb: 2048,
  recommendedDeviceTiers: const [DeviceTier.low],
  license: 'MIT',
  licenseUrl: Uri.parse('https://example.com/license'),
  urls: [for (final u in urls) Uri.parse(u)],
  companions: companions,
);

/// Scriptable [DownloadDeviceInfo].
class FakeDownloadDevice implements DownloadDeviceInfo {
  FakeDownloadDevice({
    this.free = 1 << 40,
    this.status = const NetworkStatus(connected: true, unmetered: true),
  });

  int? free;
  NetworkStatus status;
  final excluded = <String>[];
  int statusCalls = 0;

  /// Called on every [networkStatus]; may change [status].
  void Function(int call)? onStatus;

  @override
  Future<int?> freeBytes(String path) async => free;

  @override
  Future<NetworkStatus> networkStatus() async {
    statusCalls++;
    onStatus?.call(statusCalls);
    return status;
  }

  @override
  Future<bool> excludeFromBackup(String path) async {
    excluded.add(path);
    return true;
  }
}
