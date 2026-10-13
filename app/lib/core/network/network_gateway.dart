import 'package:http/http.dart' as http;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// Allowlist and switches for [NetworkGateway].
class NetworkConfig {
  const NetworkConfig({this.allowedHosts = const {}, this.offline = false});

  /// Exact host names that may be contacted (model catalog / CDN).
  final Set<String> allowedHosts;

  /// Offline mode (user setting or MDM `network_disabled`): refuse everything.
  final bool offline;
}

/// The only HTTP client in the app. Everything else must go through it.
///
/// Minimal in FND-02; SEC-02 adds the activity log, CI egress guard and audit.
class NetworkGateway {
  NetworkGateway({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  final NetworkConfig config;
  final http.Client _client;

  /// HTTPS GET to an allowlisted host.
  Future<Result<http.Response>> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    if (config.offline ||
        uri.scheme != 'https' ||
        !config.allowedHosts.contains(uri.host)) {
      return Err(EgressDeniedFailure(uri.host));
    }
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

  void close() => _client.close();
}
