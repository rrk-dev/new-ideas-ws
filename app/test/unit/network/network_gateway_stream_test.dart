import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';

/// `getStream` redirect policy (MDL-02): every hop is validated before it
/// is requested; unlisted hosts fail closed.
void main() {
  late List<Uri> requested;

  NetworkGateway gateway(
    Map<String, http.Response Function()> routes, {
    bool offline = false,
  }) {
    requested = [];
    final client = MockClient((req) async {
      requested.add(req.url);
      expect(req.followRedirects, isFalse);
      final route = routes[req.url.toString()];
      return route == null ? http.Response('', 404) : route();
    });
    return NetworkGateway(
      config: NetworkConfig(
        allowedHosts: const {'huggingface.co', 'models.vaultvoice.example'},
        redirectHosts: const {'us.aws.cdn.hf.co'},
        offline: offline,
      ),
      client: client,
    );
  }

  http.Response redirect(String to, [int status = 302]) =>
      http.Response('', status, headers: {'location': to});

  const start = 'https://huggingface.co/r/resolve/abc/m.bin';

  test('follows an allowlisted redirect chain (incl. relative)', () async {
    final g = gateway({
      start: () => redirect('/r2/resolve/abc/m.bin', 307),
      'https://huggingface.co/r2/resolve/abc/m.bin': () =>
          redirect('https://us.aws.cdn.hf.co/x?sig=1'),
      'https://us.aws.cdn.hf.co/x?sig=1': () => http.Response('ok', 200),
    });
    final r = (await g.getStream(Uri.parse(start))).valueOrNull!;
    expect(r.statusCode, 200);
    expect(r.finalUri.host, 'us.aws.cdn.hf.co');
    expect(r.hops, hasLength(2));
    expect(await r.body.expand((c) => c).toList(), 'ok'.codeUnits);
  });

  test(
    'redirect to an unlisted host fails closed without contacting it',
    () async {
      final g = gateway({start: () => redirect('https://evil.example/m.bin')});
      final r = await g.getStream(Uri.parse(start));
      expect(r.failureOrNull, isA<EgressDeniedFailure>());
      expect((r.failureOrNull! as EgressDeniedFailure).host, 'evil.example');
      expect(requested, [Uri.parse(start)]);
    },
  );

  test('https → http downgrade is refused', () async {
    final g = gateway({start: () => redirect('http://us.aws.cdn.hf.co/x')});
    expect(
      (await g.getStream(Uri.parse(start))).failureOrNull,
      isA<EgressDeniedFailure>(),
    );
    expect(requested, hasLength(1));
  });

  test('userinfo in a redirect target is refused', () async {
    final g = gateway({
      start: () => redirect('https://u:p@us.aws.cdn.hf.co/x'),
    });
    expect(
      (await g.getStream(Uri.parse(start))).failureOrNull,
      isA<EgressDeniedFailure>(),
    );
  });

  test('redirect-only hosts cannot be requested directly', () async {
    final g = gateway({});
    final r = await g.getStream(Uri.parse('https://us.aws.cdn.hf.co/x'));
    expect(r.failureOrNull, isA<EgressDeniedFailure>());
    expect(requested, isEmpty);
    expect(g.authorize(Uri.parse('https://us.aws.cdn.hf.co/x')).isOk, isFalse);
    expect(g.authorize(Uri.parse(start)).isOk, isTrue);
  });

  test('stops after the redirect limit', () async {
    final g = gateway({
      for (var i = 0; i <= kMaxGatewayRedirects + 1; i++)
        'https://huggingface.co/$i': () =>
            redirect('https://huggingface.co/${i + 1}'),
    });
    final r = await g.getStream(Uri.parse('https://huggingface.co/0'));
    expect(r.failureOrNull, isA<NetworkFailure>());
    expect(requested, hasLength(kMaxGatewayRedirects + 1));
  });

  test('a redirect without Location is an error', () async {
    final g = gateway({start: () => http.Response('', 302)});
    expect(
      (await g.getStream(Uri.parse(start))).failureOrNull,
      isA<NetworkFailure>(),
    );
  });

  test('offline mode refuses even allowlisted hosts', () async {
    final g = gateway({start: () => http.Response('ok', 200)}, offline: true);
    expect(
      (await g.getStream(Uri.parse(start))).failureOrNull,
      isA<EgressDeniedFailure>(),
    );
    expect(g.authorize(Uri.parse(start)), isA<Err<void>>());
    expect(requested, isEmpty);
  });
}
