import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/models/data/catalog_config.dart';
import 'package:vaultvoice/features/models/data/catalog_repository.dart';
import 'package:vaultvoice/features/models/domain/catalog_state_store.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';

import '../../helpers/catalog_signing.dart';

const _host = 'models.vaultvoice.example';
const _mirror = 'mirror.vaultvoice.example';

void main() {
  late TestCatalogSigner signer;
  late Uint8List bundled;
  late Uint8List bundledSig;

  setUpAll(() async {
    signer = await TestCatalogSigner.fromSeed(1);
    bundled = testCatalogBytes(); // issued 2026-10-12
    bundledSig = await signer.sign(bundled);
  });

  /// Serves `catalog.json(.sig)` per host; records every request.
  ({CatalogRepository repo, List<http.BaseRequest> requests}) build(
    Map<String, (Uint8List, Uint8List)?> remote, {
    CatalogStateStore? store,
    Set<String> allowed = const {_host, _mirror},
  }) {
    final requests = <http.BaseRequest>[];
    final client = MockClient((req) async {
      requests.add(req);
      final served = remote[req.url.host];
      if (served == null) return http.Response('nope', 404);
      final (cat, sig) = served;
      return switch (req.url.path) {
        '/catalog/v1/catalog.json' => http.Response.bytes(cat, 200),
        '/catalog/v1/catalog.json.sig' => http.Response.bytes(sig, 200),
        _ => http.Response('nope', 404),
      };
    });
    final repo = CatalogRepository(
      gateway: NetworkGateway(
        config: NetworkConfig(allowedHosts: allowed),
        client: client,
      ),
      verifier: CatalogVerifier(trustedKeys: [signer.publicKey]),
      stateStore: store ?? InMemoryCatalogStateStore(),
      baseUris: [
        Uri.parse('https://$_host/catalog/v1/'),
        Uri.parse('https://$_mirror/catalog/v1/'),
      ],
      loadAsset: (key) async => switch (key) {
        kBundledCatalogAsset => bundled,
        kBundledCatalogSigAsset => bundledSig,
        _ => throw StateError('unexpected asset'),
      },
    );
    return (repo: repo, requests: requests);
  }

  Future<(Uint8List, Uint8List)> signed(String issuedAt) async {
    final c = testCatalogBytes(
      issuedAt: issuedAt,
      models: [
        testModel(),
        testModel(id: 'extra', patch: {'file': 'extra.bin'}),
      ],
    );
    return (c, await signer.sign(c));
  }

  test('bundled catalog is the first-launch fallback (no network)', () async {
    final h = build({});
    final r = await h.repo.loadBundled();
    expect(r.isOk, isTrue);
    expect(h.repo.current!.issuedAt, DateTime.utc(2026, 10, 12));
    expect(h.requests, isEmpty);
  });

  test('newer signed remote catalog replaces the bundled one', () async {
    final store = InMemoryCatalogStateStore();
    final h = build({
      _host: await signed('2026-10-20T00:00:00Z'),
    }, store: store);
    final r = await h.repo.refresh();
    expect(r.isOk, isTrue);
    expect(h.repo.current!.models, hasLength(2));
    expect(await store.lastAcceptedIssuedAt(), DateTime.utc(2026, 10, 20));
  });

  test(
    '[MDL-01/AC1] tampered remote catalog is rejected, bundled stays',
    () async {
      final (cat, sig) = await signed('2026-10-20T00:00:00Z');
      final tampered = Uint8List.fromList(cat)..[cat.length ~/ 3] ^= 0x04;
      final h = build({_host: (tampered, sig)});
      final r = await h.repo.refresh();
      expect(
        r.failureOrNull,
        isA<CatalogFailure>().having(
          (f) => f.reason,
          'reason',
          CatalogRejection.badSignature,
        ),
      );
      expect(h.repo.current!.issuedAt, DateTime.utc(2026, 10, 12));
      expect(h.repo.current!.models, hasLength(1));
    },
  );

  test(
    '[MDL-01/AC1] rollback below bundled or last accepted is rejected',
    () async {
      // Older than the bundled catalog.
      var h = build({_host: await signed('2026-10-01T00:00:00Z')});
      var r = await h.repo.refresh();
      expect(
        (r.failureOrNull! as CatalogFailure).reason,
        CatalogRejection.rollback,
      );
      // Newer than bundled but older than what was accepted before a restart.
      final store = InMemoryCatalogStateStore(DateTime.utc(2026, 11));
      h = build({_host: await signed('2026-10-20T00:00:00Z')}, store: store);
      r = await h.repo.refresh();
      expect(
        (r.failureOrNull! as CatalogFailure).reason,
        CatalogRejection.rollback,
      );
      expect(h.repo.current!.issuedAt, DateTime.utc(2026, 10, 12));
    },
  );

  test('falls through to the mirror when the primary fails', () async {
    final good = await signed('2026-10-20T00:00:00Z');
    final h = build({_host: null, _mirror: good});
    final r = await h.repo.refresh();
    expect(r.isOk, isTrue);
    expect(h.requests.map((q) => q.url.host).toSet(), {_host, _mirror});
  });

  test('a bad primary signature still lets a good mirror win', () async {
    final good = await signed('2026-10-20T00:00:00Z');
    final h = build({
      _host: (
        good.$1,
        await (await TestCatalogSigner.fromSeed(9)).sign(good.$1),
      ),
      _mirror: good,
    });
    expect((await h.repo.refresh()).isOk, isTrue);
  });

  test('non-allowlisted endpoint is refused by the gateway', () async {
    final h = build({
      _host: await signed('2026-10-20T00:00:00Z'),
    }, allowed: const {});
    final r = await h.repo.refresh();
    expect(r.failureOrNull, isA<EgressDeniedFailure>());
    expect(h.requests, isEmpty);
  });

  test(
    '[MDL-01/AC2] catalog fetch sends only anonymous catalog requests',
    () async {
      final h = build({
        _host: null,
        _mirror: await signed('2026-10-20T00:00:00Z'),
      });
      await h.repo.loadBundled();
      await h.repo.refresh();

      expect(h.requests, isNotEmpty);
      for (final q in h.requests) {
        expect(q.method, 'GET');
        expect(q.url.scheme, 'https');
        expect({_host, _mirror}, contains(q.url.host));
        expect(
          ['/catalog/v1/catalog.json', '/catalog/v1/catalog.json.sig'],
          contains(q.url.path),
          reason: 'only manifest requests',
        );
        expect(q.url.hasQuery, isFalse, reason: 'no identifiers in query');
        expect(q.url.userInfo, isEmpty);
        expect(q.followRedirects, isFalse);
        // Exactly the anonymous header set: no Cookie, Authorization,
        // device/install ids, locale or app build details.
        expect(q.headers.map((k, v) => MapEntry(k.toLowerCase(), v)), {
          'user-agent': 'VaultVoice/1',
          'accept': '*/*',
        });
        expect(q.contentLength ?? 0, 0, reason: 'no request body');
      }
    },
  );
}
