import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/features/models/data/catalog_config.dart';
import 'package:vaultvoice/features/models/domain/catalog_keys.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/models/domain/model_file_verifier.dart';

import '../../helpers/catalog_signing.dart';

const _app = SemVer(1, 0, 0);

CatalogRejection? _reason(Result<ModelCatalog> r) => switch (r.failureOrNull) {
  CatalogFailure(:final reason) => reason,
  _ => null,
};

void main() {
  late TestCatalogSigner signer;
  late TestCatalogSigner other;
  late CatalogVerifier verifier;

  setUpAll(() async {
    signer = await TestCatalogSigner.fromSeed(1);
    other = await TestCatalogSigner.fromSeed(2);
  });
  setUp(() => verifier = CatalogVerifier(trustedKeys: [signer.publicKey]));

  Future<Result<ModelCatalog>> check(
    Uint8List catalog, {
    Uint8List? sig,
    DateTime? floor,
    CatalogVerifier? v,
    SemVer app = _app,
  }) async => await (v ?? verifier).verify(
    catalogBytes: catalog,
    signatureBytes: sig ?? await signer.sign(catalog),
    appVersion: app,
    rollbackFloor: floor,
  );

  group('signature', () {
    test('[MDL-01/AC1] a correctly signed catalog is accepted', () async {
      final r = await check(testCatalogBytes());
      final c = r.valueOrNull!;
      expect(c.schema, 1);
      expect(c.issuedAt, DateTime.utc(2026, 10, 12));
      expect(c.models.single.id, 'whisper-tiny.en');
      expect(c.models.single.type, ModelType.stt);
      expect(c.byId('whisper-tiny.en')!.size, 11);
    });

    test(
      '[MDL-01/AC1] tampered catalog (one byte / one field) is rejected',
      () async {
        final bytes = testCatalogBytes();
        final sig = await signer.sign(bytes);

        // Flip a single byte anywhere in the signed file.
        for (final i in [0, bytes.length ~/ 2, bytes.length - 1]) {
          final t = Uint8List.fromList(bytes)..[i] ^= 0x01;
          expect(
            _reason(await check(t, sig: sig)),
            CatalogRejection.badSignature,
            reason: 'byte $i',
          );
        }
        // Swap the model hash for an attacker's file (valid JSON, same length).
        final evil = utf8.encode(
          utf8.decode(bytes).replaceFirst('b94d27b9', 'deadbeef'),
        );
        expect(
          _reason(await check(evil, sig: sig)),
          CatalogRejection.badSignature,
        );
        // Append whitespace: still rejected, the signature covers exact bytes.
        final padded = Uint8List.fromList([...bytes, 0x20]);
        expect(
          _reason(await check(padded, sig: sig)),
          CatalogRejection.badSignature,
        );
      },
    );

    test('[MDL-01/AC1] bad signature: forged, other key, zeroed', () async {
      final bytes = testCatalogBytes();
      // Signed by an unpinned key but claiming the pinned key id.
      final forged = await other.sign(bytes, keyId: signer.publicKey.keyId);
      expect(
        _reason(await check(bytes, sig: forged)),
        CatalogRejection.badSignature,
      );
      // Signed by an unpinned key with its own id.
      expect(
        _reason(await check(bytes, sig: await other.sign(bytes))),
        CatalogRejection.unknownKey,
      );
      final zero = utf8.encode(
        jsonEncode({
          'alg': 'ed25519',
          'key_id': signer.publicKey.keyId,
          'sig': base64Encode(List<int>.filled(64, 0)),
        }),
      );
      expect(
        _reason(await check(bytes, sig: Uint8List.fromList(zero))),
        CatalogRejection.badSignature,
      );
    });

    test(
      '[MDL-01/AC1] unsigned or malformed signature file is rejected',
      () async {
        final bytes = testCatalogBytes();
        final good = jsonDecode(utf8.decode(await signer.sign(bytes))) as Map;
        final cases = <Object>[
          '',
          'not json',
          '[]',
          {...good, 'alg': 'rsa'},
          {...good, 'sig': base64Encode(List<int>.filled(63, 1))},
          {...good, 'sig': '***'},
          {'alg': 'ed25519', 'sig': good['sig']},
          {...good, 'key_id': 7},
        ];
        for (final c in cases) {
          final sig = utf8.encode(c is String ? c : jsonEncode(c));
          expect(
            _reason(await check(bytes, sig: Uint8List.fromList(sig))),
            CatalogRejection.malformedSignature,
            reason: '$c',
          );
        }
      },
    );

    test(
      '[MDL-01/AC1] key rotation: either of two pinned keys verifies',
      () async {
        final both = CatalogVerifier(
          trustedKeys: [signer.publicKey, other.publicKey],
        );
        final bytes = testCatalogBytes();
        expect((await check(bytes, v: both)).isOk, isTrue);
        expect(
          (await check(bytes, v: both, sig: await other.sign(bytes))).isOk,
          isTrue,
        );
        final third = await TestCatalogSigner.fromSeed(3);
        expect(
          _reason(await check(bytes, v: both, sig: await third.sign(bytes))),
          CatalogRejection.unknownKey,
        );
        expect(
          () => CatalogVerifier(
            trustedKeys: [signer.publicKey, other.publicKey, third.publicKey],
          ),
          throwsArgumentError,
        );
        expect(() => CatalogVerifier(trustedKeys: []), throwsArgumentError);
      },
    );

    test('[MDL-01/AC1] oversized catalog is rejected before parsing', () async {
      final big = Uint8List(kMaxCatalogBytes + 1);
      expect(_reason(await check(big)), CatalogRejection.tooLarge);
    });
  });

  group('content rules (validly signed)', () {
    test(
      '[MDL-01/AC1] rollback: older issued_at than accepted is rejected',
      () async {
        final old = testCatalogBytes(issuedAt: '2026-10-01T00:00:00Z');
        final floor = DateTime.utc(2026, 10, 12);
        expect(
          _reason(await check(old, floor: floor)),
          CatalogRejection.rollback,
        );
        // Same or newer is fine.
        expect((await check(testCatalogBytes(), floor: floor)).isOk, isTrue);
        final newer = testCatalogBytes(issuedAt: '2026-10-13T00:00:00Z');
        expect((await check(newer, floor: floor)).isOk, isTrue);
      },
    );

    test('[MDL-01/AC1] unknown schema is rejected', () async {
      for (final s in <Object?>[2, 0, '1', 1.5, null]) {
        expect(
          _reason(await check(testCatalogBytes(patch: {'schema': s}))),
          CatalogRejection.unknownSchema,
          reason: '$s',
        );
      }
    });

    test('[MDL-01/AC1] catalog requiring a newer app is rejected', () async {
      final bytes = testCatalogBytes(patch: {'min_app_version': '1.0.1'});
      expect(_reason(await check(bytes)), CatalogRejection.appTooOld);
      expect((await check(bytes, app: const SemVer(1, 0, 1))).isOk, isTrue);
      expect((await check(bytes, app: const SemVer(1, 10, 0))).isOk, isTrue);
    });

    test('[MDL-01/AC1] malformed fields are rejected', () async {
      final bad = <String, Map<String, Object?>>{
        'path traversal file': {'file': '../../etc/passwd'},
        'subdir file': {'file': 'a/b.bin'},
        'http url': {
          'urls': ['http://models.vaultvoice.example/a.bin'],
        },
        'query in url': {
          'urls': ['https://models.vaultvoice.example/a.bin?uid=1'],
        },
        'credentials in url': {
          'urls': ['https://u:p@models.vaultvoice.example/a.bin'],
        },
        'no urls': {'urls': <String>[]},
        'short sha': {'sha256': 'abcd'},
        'upper sha': {
          'sha256': testModel()['sha256']!.toString().toUpperCase(),
        },
        'zero size': {'size': 0},
        'string size': {'size': '11'},
        'bad type': {'type': 'tts'},
        'bad tier': {'tier': 'gold'},
        'bad device tier': {
          'recommended_device_tiers': ['ultra'],
        },
        'empty name': {'display_name': ' '},
        'bad id': {'id': 'Whisper Tiny'},
        'unknown companion': {
          'companions': ['nope'],
        },
        'bad min_app_version': {'min_app_version': '1.0'},
      };
      for (final MapEntry(:key, :value) in bad.entries) {
        final bytes = testCatalogBytes(models: [testModel(patch: value)]);
        expect(
          _reason(await check(bytes)),
          CatalogRejection.malformed,
          reason: key,
        );
      }
      final dup = testCatalogBytes(models: [testModel(), testModel()]);
      expect(_reason(await check(dup)), CatalogRejection.malformed);
      final noModels = testCatalogBytes(models: []);
      expect(_reason(await check(noModels)), CatalogRejection.malformed);
      final badTime = testCatalogBytes(issuedAt: '2026-13-01T00:00:00Z');
      expect(_reason(await check(badTime)), CatalogRejection.malformed);
      final missingAttribution = testModel()..remove('attribution');
      expect(
        _reason(await check(testCatalogBytes(models: [missingAttribution]))),
        CatalogRejection.malformed,
      );
    });

    test('per-model min_app_version filters usable models', () async {
      final c = (await check(
        testCatalogBytes(
          models: [
            testModel(),
            testModel(id: 'future', patch: {'min_app_version': '2.0.0'}),
          ],
        ),
      )).valueOrNull!;
      expect(c.usable(ModelType.stt, _app).map((m) => m.id), [
        'whisper-tiny.en',
      ]);
      expect(c.usable(ModelType.stt, const SemVer(2, 0, 0)), hasLength(2));
      expect(c.usable(ModelType.llm, _app), isEmpty);
    });
  });

  group('model file', () {
    final model = ModelCatalog.parse(testCatalogBytes())
        .valueOrNull!
        .models
        .single;
    Stream<List<int>> chunks(String s) => Stream.fromIterable([
      utf8.encode(s.substring(0, 4)),
      utf8.encode(s.substring(4)),
    ]);

    test('[MDL-01/AC1] model file with the catalog hash is accepted', () async {
      expect(
        (await verifyModelBytes(chunks('hello world'), model)).isOk,
        isTrue,
      );
    });

    test(
      '[MDL-01/AC1] tampered model file (hash or size) is rejected',
      () async {
        final sameSize = await verifyModelBytes(chunks('hello World'), model);
        expect(
          sameSize.failureOrNull,
          isA<ModelIntegrityFailure>().having(
            (f) => f.sizeMismatch,
            'size',
            false,
          ),
        );
        final longer = await verifyModelBytes(chunks('hello world!'), model);
        expect(
          longer.failureOrNull,
          isA<ModelIntegrityFailure>().having(
            (f) => f.sizeMismatch,
            'size',
            true,
          ),
        );
        final truncated = await verifyModelBytes(chunks('hello worl'), model);
        expect(
          truncated.failureOrNull,
          isA<ModelIntegrityFailure>().having(
            (f) => f.sizeMismatch,
            'size',
            true,
          ),
        );
      },
    );
  });

  group('bundled catalog asset', () {
    // flutter test runs with the package root (app/) as cwd.
    final bytes = File(kBundledCatalogAsset).readAsBytesSync();
    final sig = File(kBundledCatalogSigAsset).readAsBytesSync();

    test('[MDL-01/AC1] verifies with the pinned keys and is seeded', () async {
      final v = CatalogVerifier(trustedKeys: pinnedCatalogKeys());
      final r = await v.verify(
        catalogBytes: bytes,
        signatureBytes: sig,
        appVersion: kCatalogAppVersion,
      );
      final c = r.valueOrNull!;
      final stt = c.byId('whisper-tiny.en')!;
      expect(stt.file, 'ggml-tiny.en.bin');
      expect(stt.size, 77704715);
      expect(
        stt.sha256,
        '921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f',
      );
      final llm = c.usable(ModelType.llm, kCatalogAppVersion).single;
      expect(llm.file, endsWith('.gguf'));
      // Tampering with the shipped file is caught too.
      final t = Uint8List.fromList(bytes)..[bytes.length ~/ 2] ^= 0x20;
      expect(
        _reason(
          await v.verify(
            catalogBytes: t,
            signatureBytes: sig,
            appVersion: kCatalogAppVersion,
          ),
        ),
        CatalogRejection.badSignature,
      );
    });

    test('every catalog URL host is on the gateway allowlist', () {
      final c = ModelCatalog.parse(bytes).valueOrNull!;
      for (final m in c.models) {
        for (final u in m.urls) {
          expect(kModelHosts, contains(u.host), reason: '$u');
        }
      }
      for (final b in kCatalogBaseUris) {
        expect(kModelHosts, contains(b.host));
        expect(b.path, endsWith('/'));
      }
    });

    test('Hugging Face only (product owner 2026-10-14): one allowlisted '
        'host, every catalog URL on it, no CDN placeholder', () {
      expect(kModelHosts, {'huggingface.co'});
      expect(kModelRedirectHosts, {'us.aws.cdn.hf.co'});
      final c = ModelCatalog.parse(bytes).valueOrNull!;
      for (final m in c.models) {
        for (final u in m.urls) {
          expect(u.host, 'huggingface.co', reason: '$u');
          expect(u.path, contains('/resolve/'), reason: '$u');
        }
      }
      expect(utf8.decode(bytes), isNot(contains('vaultvoice.example')));
      // No catalog repo named yet → bundled catalog only (PRODUCT-DECISION).
      expect(kCatalogBaseUris, isEmpty);
    });

    test('pinned key ids match the documented ids; at most two keys', () {
      final keys = pinnedCatalogKeys();
      expect(keys, hasLength(inInclusiveRange(1, 2)));
      expect(keys.first.keyId, 'c6ced0f07343ec41');
    });

    test('kCatalogAppVersion equals the pubspec version', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final v = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1)!;
      expect(kCatalogAppVersion.toString(), v);
    });
  });

  group('SemVer', () {
    test('parses and orders numerically', () {
      expect(
        SemVer.tryParse('1.10.0')!.compareTo(SemVer.tryParse('1.9.9')!),
        1,
      );
      expect(SemVer.tryParse('01.0.0'), isNull);
      expect(SemVer.tryParse('1.0'), isNull);
      expect(SemVer.tryParse('1.0.0-beta'), isNull);
    });
  });
}
