import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// Allowlist and switches for [NetworkGateway].
class NetworkConfig {
  const NetworkConfig({
    this.allowedHosts = const {},
    this.redirectHosts = const {},
    this.offline = false,
  });

  /// Exact host names that may be contacted (model catalog / CDN).
  final Set<String> allowedHosts;

  /// Exact host names that may only be reached as the target of a redirect
  /// from an allowlisted host (e.g. the Hugging Face file CDN behind a
  /// mirror `resolve` URL, MDL-02). Never contacted directly.
  final Set<String> redirectHosts;

  /// Offline mode (user setting or MDM `network_disabled`): refuse everything.
  final bool offline;
}

/// A streamed response from [NetworkGateway.getStream]. The caller must
/// either consume or cancel [body].
class GatewayStreamedResponse {
  GatewayStreamedResponse({
    required this.finalUri,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.hops,
  });

  /// URL of the request that produced this response (after redirects).
  final Uri finalUri;
  final int statusCode;

  /// Lower-case header names.
  final Map<String, String> headers;
  final Stream<List<int>> body;

  /// Every redirect target followed, in order (empty without redirects).
  final List<Uri> hops;
}

/// Maximum redirects [NetworkGateway.getStream] follows before failing.
const kMaxGatewayRedirects = 5;

const _redirectStatuses = {301, 302, 303, 307, 308};

/// The only HTTP client in the app. Everything else must go through it.
///
/// Minimal in FND-02; SEC-02 adds the activity log, CI egress guard and audit.
class NetworkGateway {
  /// `networkDisabled` is consulted before **every** request (user offline
  /// mode / MDM `network_disabled`, MDL-04); true or an error refuses it.
  NetworkGateway({
    required this.config,
    http.Client? client,
    this._networkDisabled,
  }) : _client = client ?? http.Client();

  final NetworkConfig config;
  final http.Client _client;
  final Future<bool> Function()? _networkDisabled;

  Future<bool> _disabled() async {
    final check = _networkDisabled;
    if (check == null) return false;
    try {
      return await check();
    } on Object {
      return true; // Fail closed: the setting could not be read.
    }
  }

  /// HTTPS GET to an allowlisted host.
  Future<Result<http.Response>> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final denied = _check(uri, redirect: false);
    if (denied != null) return Err(denied);
    if (await _disabled()) return Err(EgressDeniedFailure(uri.host));
    try {
      // Redirects are not followed: a 3xx could point at a non-allowlisted
      // host. Callers see the 3xx response and decide.
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers.addAll(headers ?? const {});
      final streamed = await _client.send(request);
      return Ok(await http.Response.fromStream(streamed));
    } on http.ClientException catch (e) {
      return Err(NetworkFailure(e.runtimeType.toString()));
    }
  }

  /// Whether a direct request to [uri] would be allowed (used by native
  /// transports that cannot run through this client, MDL-02).
  Future<Result<void>> authorize(Uri uri) async {
    final denied = _check(uri, redirect: false);
    if (denied != null) return Err(denied);
    if (await _disabled()) return Err(EgressDeniedFailure(uri.host));
    return const Ok(null);
  }

  /// Streamed HTTPS GET that follows up to [maxRedirects] redirects itself.
  ///
  /// Every hop is checked **before** it is requested: https only, no
  /// userinfo, host in [NetworkConfig.allowedHosts] or (redirect targets
  /// only) [NetworkConfig.redirectHosts]. An unlisted target fails closed
  /// with [EgressDeniedFailure] and is never contacted. The same [headers]
  /// are sent on every hop (they are anonymous by construction).
  Future<Result<GatewayStreamedResponse>> getStream(
    Uri uri, {
    Map<String, String>? headers,
    int maxRedirects = kMaxGatewayRedirects,
  }) async {
    final first = _check(uri, redirect: false);
    if (first != null) return Err(first);
    if (await _disabled()) return Err(EgressDeniedFailure(uri.host));
    var current = uri;
    final hops = <Uri>[];
    try {
      while (true) {
        final request = http.Request('GET', current)
          ..followRedirects = false
          ..headers.addAll(headers ?? const {});
        final streamed = await _client.send(request);
        if (!_redirectStatuses.contains(streamed.statusCode)) {
          return Ok(
            GatewayStreamedResponse(
              finalUri: current,
              statusCode: streamed.statusCode,
              headers: streamed.headers,
              body: streamed.stream,
              hops: List.unmodifiable(hops),
            ),
          );
        }
        // Do not read redirect bodies.
        unawaited(streamed.stream.listen(null).cancel());
        final location = streamed.headers['location'];
        if (location == null || location.isEmpty) {
          return const Err(NetworkFailure('redirect without location'));
        }
        if (hops.length >= maxRedirects) {
          return const Err(NetworkFailure('too many redirects'));
        }
        final Uri next;
        try {
          next = current.resolve(location);
        } on FormatException {
          return const Err(NetworkFailure('invalid redirect location'));
        }
        final denied = _check(next, redirect: true);
        if (denied != null) return Err(denied);
        hops.add(next);
        current = next;
      }
    } on http.ClientException catch (e) {
      return Err(NetworkFailure(e.runtimeType.toString()));
    }
  }

  EgressDeniedFailure? _check(Uri uri, {required bool redirect}) {
    final hostOk =
        config.allowedHosts.contains(uri.host) ||
        (redirect && config.redirectHosts.contains(uri.host));
    if (config.offline ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !hostOk) {
      return EgressDeniedFailure(uri.host);
    }
    return null;
  }

  void close() => _client.close();
}
