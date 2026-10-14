import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/models/domain/download_platform.dart';
import 'package:vaultvoice/features/models/domain/download_transport.dart';

/// Native side: `ModelDownloadPlugin` (iOS `Runner/ModelDownload/`, Android
/// `modeldownload/`).
const kModelDownloadChannel = MethodChannel('vaultvoice/model_download');

/// Device facts + keep-alive over [kModelDownloadChannel].
class MethodChannelDownloadPlatform
    implements DownloadDeviceInfo, DownloadKeepAlive {
  const MethodChannelDownloadPlatform([this._channel = kModelDownloadChannel]);

  final MethodChannel _channel;

  @override
  Future<int?> freeBytes(String path) async {
    try {
      return await _channel.invokeMethod<int>('freeBytes', {'path': path});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Unknown state counts as "connected but metered": downloads then need
  /// the cellular opt-in rather than silently using a metered link.
  @override
  Future<NetworkStatus> networkStatus() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>(
        'networkStatus',
      );
      return NetworkStatus(
        connected: m?['connected'] == true,
        unmetered: m?['unmetered'] == true,
        lowPowerMode: m?['lowPowerMode'] == true,
      );
    } on PlatformException {
      return const NetworkStatus(connected: true, unmetered: false);
    } on MissingPluginException {
      return const NetworkStatus(connected: true, unmetered: false);
    }
  }

  @override
  Future<bool> excludeFromBackup(String path) async {
    try {
      return await _channel.invokeMethod<bool>('excludeFromBackup', {
            'path': path,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> start(String title) =>
      _quiet('keepAliveStart', {'title': title});

  @override
  Future<void> update(int receivedBytes, int totalBytes) => _quiet(
    'keepAliveUpdate',
    {'received': receivedBytes, 'total': totalBytes},
  );

  @override
  Future<void> stop() => _quiet('keepAliveStop');

  Future<void> _quiet(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
      // Keep-alive is best effort; the download resumes later if killed.
    } on MissingPluginException {
      // Host / tests.
    }
  }
}

/// iOS transport: the Dart [NetworkGateway] resolves and validates the
/// redirect chain (every hop allowlisted, fail closed), then the final URL
/// is handed to the native background download session, which keeps going
/// while the app is suspended or terminated and re-checks the host natively.
class BackgroundSessionTransport implements DownloadTransport {
  BackgroundSessionTransport(
    this._gateway, [
    this._channel = kModelDownloadChannel,
  ]) {
    _channel.setMethodCallHandler(_onCall);
  }

  final NetworkGateway _gateway;
  final MethodChannel _channel;
  final _pending = <String, _Pending>{};

  @override
  Future<TransportOutcome> fetch(
    TransportRequest request, {
    required DownloadControl control,
    required void Function(int fileLength) onProgress,
    required Future<Failure?> Function() checkpoint,
  }) async {
    final headers = {
      ...request.headers,
      if (request.offset > 0) 'Range': 'bytes=${request.offset}-',
    };
    // 1. Resolve redirects in Dart (validated), read only the status line.
    final res = await _gateway.getStream(request.uri, headers: headers);
    final GatewayStreamedResponse resolved;
    switch (res) {
      case Err(:final failure):
        return TransportFailed(
          failure,
          retryable: failure is! EgressDeniedFailure,
        );
      case Ok(:final value):
        resolved = value;
    }
    unawaited(resolved.body.listen(null).cancel().catchError((_) {}));
    final status = resolved.statusCode;
    if (status == 416) return const TransportRangeNotSatisfiable();
    if (status != 200 && status != 206) {
      return _httpFailure(status);
    }

    // 2. Hand the validated final URL to the background session.
    final key = request.modelId;
    final pending = _Pending(onProgress);
    _pending[key] = pending;
    unawaited(
      control.stopped.then(
        (_) =>
            _invoke(control.isCancelled ? 'bgCancel' : 'bgPause', {'key': key}),
      ),
    );
    final config = _gateway.config;
    await _invoke('bgStart', {
      'key': key,
      'url': resolved.finalUri.toString(),
      'headers': headers,
      'partialPath': request.partial.path,
      'offset': request.offset,
      'total': request.totalBytes,
      'allowCellular': request.allowCellular,
      'allowedHosts': [...config.allowedHosts, ...config.redirectHosts],
    });
    final outcome = await pending.done.future;
    _pending.remove(key);
    await _invoke('bgAck', {'key': key});
    return _map(outcome);
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'bgEvent') return;
    final args = (call.arguments as Map<Object?, Object?>)
        .cast<String, Object?>();
    final pending = _pending[args['key']];
    if (pending == null) return;
    if (args['event'] == 'progress') {
      final length = args['length'];
      if (length is int) pending.onProgress(length);
    } else if (args['event'] == 'done' && !pending.done.isCompleted) {
      pending.done.complete(args);
    }
  }

  static TransportOutcome _map(Map<String, Object?> e) {
    switch (e['result']) {
      case 'completed':
        final etag = e['etag'];
        return TransportCompleted(
          validator: etag is String && !etag.startsWith('W/') ? etag : null,
        );
      case 'rangeNotSatisfiable':
        return const TransportRangeNotSatisfiable();
      case 'stopped':
        return const TransportStopped();
      case 'redirectDenied':
        return TransportFailed(
          EgressDeniedFailure('${e['host']}'),
          retryable: false,
        );
      case 'http':
        final status = e['status'];
        return _httpFailure(status is int ? status : 0);
      case 'io':
        return const TransportFailed(
          StorageFailure('model download io'),
          retryable: true,
        );
      default:
        return TransportFailed(
          NetworkFailure('network ${e['code'] ?? '?'}'),
          retryable: true,
        );
    }
  }

  static TransportFailed _httpFailure(int status) => TransportFailed(
    NetworkFailure('http $status'),
    retryable: status == 429 || status == 408 || status >= 500,
  );

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      final pending = _pending[args['key']];
      if (pending != null && !pending.done.isCompleted) {
        pending.done.complete({'result': 'network', 'code': e.code});
      }
    }
  }
}

class _Pending {
  _Pending(this.onProgress);
  final void Function(int) onProgress;
  final done = Completer<Map<String, Object?>>();
}
