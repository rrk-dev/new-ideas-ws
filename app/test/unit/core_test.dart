import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaultvoice/core/errors/error_boundary.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';

void main() {
  group('Result', () {
    test('[FND-02/AC2] ok/err fold and map', () {
      const Result<int> ok = Ok(2);
      const Result<int> err = Err(CancelledFailure());

      expect(ok.map((v) => v * 2).valueOrNull, 4);
      expect(err.map((v) => v * 2).failureOrNull, isA<CancelledFailure>());
      expect(ok.when(ok: (v) => 'v$v', err: (f) => 'f'), 'v2');
      expect(err.when(ok: (v) => 'v', err: (f) => f.message), 'cancelled');
    });
  });

  group('error boundary', () {
    late FlutterExceptionHandler? savedFlutter;
    late ErrorCallback? savedPlatform;

    setUp(() {
      savedFlutter = FlutterError.onError;
      savedPlatform = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = savedFlutter;
      PlatformDispatcher.instance.onError = savedPlatform;
    });

    test('[FND-02/AC3] uncaught errors are absorbed, only type reported', () {
      final reported = <String>[];
      installErrorBoundary(onError: reported.add);

      final handled = PlatformDispatcher.instance.onError!(
        StateError('secret transcript text'),
        StackTrace.empty,
      );
      FlutterError.onError!(
        FlutterErrorDetails(exception: ArgumentError('more secret')),
      );

      expect(handled, isTrue);
      expect(reported, ['StateError', 'ArgumentError']);
    });
  });

  group('NetworkGateway', () {
    NetworkGateway gateway({NetworkConfig? config, int? status}) =>
        NetworkGateway(
          config:
              config ?? const NetworkConfig(allowedHosts: {'cdn.example.com'}),
          client: MockClient((_) async => http.Response('ok', status ?? 200)),
        );

    test('[FND-02/AC2] allows only https hosts on the allowlist', () async {
      final g = gateway();
      expect(
        (await g.get(Uri.parse('https://cdn.example.com/m.json'))).isOk,
        isTrue,
      );
      final other = await g.get(Uri.parse('https://evil.example.org/'));
      expect(other.failureOrNull, isA<EgressDeniedFailure>());
      final plain = await g.get(Uri.parse('http://cdn.example.com/'));
      expect(plain.failureOrNull, isA<EgressDeniedFailure>());
    });

    test('[FND-02/AC2] offline mode and empty allowlist deny all', () async {
      final offline = gateway(
        config: const NetworkConfig(
          allowedHosts: {'cdn.example.com'},
          offline: true,
        ),
      );
      expect(
        (await offline.get(Uri.parse('https://cdn.example.com/')))
            .failureOrNull,
        isA<EgressDeniedFailure>(),
      );
      final empty = gateway(config: const NetworkConfig());
      expect(
        (await empty.get(Uri.parse('https://cdn.example.com/'))).failureOrNull,
        isA<EgressDeniedFailure>(),
      );
    });
  });
}
