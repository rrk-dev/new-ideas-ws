import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/data/entitlement_license_port.dart';
import 'package:vaultvoice/features/licensing/data/local_entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/enterprise_license.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';

import '../../fakes/fake_clock.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15);
  final ed = DartEd25519();

  late SimpleKeyPair pair;
  late SimpleKeyPair otherPair;
  late EnterpriseLicenseVerifier verifier;

  Future<CatalogPublicKey> pubOf(SimpleKeyPair p) async =>
      CatalogPublicKey((await p.extractPublicKey()).bytes);

  setUp(() async {
    pair = await ed.newKeyPair();
    otherPair = await ed.newKeyPair();
    verifier = EnterpriseLicenseVerifier(trustedKeys: [await pubOf(pair)]);
  });

  Future<List<int>> license({
    SimpleKeyPair? signer,
    Duration expiresIn = const Duration(days: 365),
    Duration issuedAgo = Duration.zero,
    Map<String, Object?> extra = const {},
  }) async {
    final p = signer ?? pair;
    final payload = utf8.encode(
      jsonEncode({
        'license_id': 'L1',
        'org_id': 'acme',
        'org_name': 'Acme',
        'seats': 25,
        'issued_at': now.subtract(issuedAgo).toIso8601String(),
        'expires_at': now.add(expiresIn).toIso8601String(),
        'features': ['managedProfiles', 'someFutureFeature'],
        ...extra,
      }),
    );
    final sig = await ed.sign(payload, keyPair: p);
    return utf8.encode(
      jsonEncode({
        'format': 1,
        'alg': 'ed25519',
        'key_id': (await pubOf(p)).keyId,
        'payload': base64Encode(payload),
        'sig': base64Encode(sig.bytes),
      }),
    );
  }

  LicenseRejection? reasonOf(Result<EnterpriseLicense> r) => switch (r) {
    Err(:final failure) => (failure as LicenseFailure).reason,
    Ok() => null,
  };

  test('[LIC-03/AC1] accepts a valid licence', () async {
    final r = await verifier.verify(await license(), now: now);
    final l = r.valueOrNull!;
    expect(l.orgId, 'acme');
    expect(l.seats, 25);
    expect(l.features, {Feature.managedProfiles});
    expect(l.statusAt(now), LicenseStatus.valid);
  });

  test('[LIC-03/AC1] rejects a tampered payload', () async {
    final doc =
        jsonDecode(utf8.decode(await license())) as Map<String, Object?>;
    final payload = jsonDecode(
      utf8.decode(base64Decode(doc['payload']! as String)),
    ) as Map<String, Object?>;
    payload['seats'] = 5000;
    doc['payload'] = base64Encode(utf8.encode(jsonEncode(payload)));
    final r = await verifier.verify(utf8.encode(jsonEncode(doc)), now: now);
    expect(reasonOf(r), LicenseRejection.badSignature);
  });

  test('[LIC-03/AC1] rejects an unknown signing key', () async {
    final r = await verifier.verify(await license(signer: otherPair), now: now);
    expect(reasonOf(r), LicenseRejection.unknownKey);
  });

  test(
    '[LIC-03/AC1] rejects an expired licence past the grace window',
    () async {
      final bytes = await license(
        issuedAgo: const Duration(days: 400),
        expiresIn: const Duration(days: -31),
      );
      expect(
        reasonOf(await verifier.verify(bytes, now: now)),
        LicenseRejection.expired,
      );
    },
  );

  test(
    '[LIC-03/AC1] future issued_at, garbage and oversize are rejected',
    () async {
      final future = await license(issuedAgo: const Duration(days: -3));
      expect(
        reasonOf(await verifier.verify(future, now: now)),
        LicenseRejection.notYetValid,
      );
      expect(
        reasonOf(await verifier.verify(utf8.encode('nope'), now: now)),
        LicenseRejection.malformed,
      );
      expect(
        reasonOf(
          await verifier.verify(List.filled(kMaxLicenseBytes + 1, 0), now: now),
        ),
        LicenseRejection.tooLarge,
      );
      final badSeats = await license(extra: {'seats': 0});
      expect(
        reasonOf(await verifier.verify(badSeats, now: now)),
        LicenseRejection.invalidField,
      );
    },
  );

  test('[LIC-03/AC1] no pinned key means every licence is rejected', () async {
    final none = EnterpriseLicenseVerifier(trustedKeys: const []);
    expect(
      reasonOf(await none.verify(await license(), now: now)),
      LicenseRejection.unknownKey,
    );
  });

  test(
    '[LIC-03/AC1] warning from T-30d, grace for 30 days after expiry',
    () async {
      final l = (await verifier.verify(await license(), now: now)).valueOrNull!;
      expect(
        l.statusAt(l.expiresAt.subtract(const Duration(days: 31))),
        LicenseStatus.valid,
      );
      expect(
        l.statusAt(l.expiresAt.subtract(const Duration(days: 29))),
        LicenseStatus.expiringSoon,
      );
      expect(
        l.statusAt(l.expiresAt.add(const Duration(days: 1))),
        LicenseStatus.inGrace,
      );
      expect(
        l.statusAt(l.expiresAt.add(const Duration(days: 31))),
        LicenseStatus.expired,
      );
    },
  );

  test(
    '[LIC-03/AC1] install grants Enterprise and falls back to Free after grace',
    () async {
      final clock = FakeClock(now);
      final svc = LocalEntitlementService(
        clock: clock,
        mode: DistributionMode.commercial,
      );
      final port = EntitlementLicensePort(
        svc,
        verifier: verifier,
        now: clock.now,
      );
      final file = utf8.decode(
        await license(expiresIn: const Duration(days: 10)),
      );

      expect((await port.installEnterpriseLicense(file)).isOk, isTrue);
      expect(svc.has(Feature.managedProfiles), isTrue);
      expect(svc.access.effectivePlan, Plan.enterprise);

      clock.advance(const Duration(days: 41));
      svc.refresh();
      expect(svc.access.effectivePlan, Plan.free);
    },
  );

  test(
    '[LIC-03/AC1] install accepts base64 (MDM) and keeps state on failure',
    () async {
      final svc = LocalEntitlementService(
        clock: FakeClock(now),
        mode: DistributionMode.commercial,
      );
      final port = EntitlementLicensePort(
        svc,
        verifier: verifier,
        now: () => now,
      );
      final bad = await port.installEnterpriseLicense('not base64 !!');
      expect(bad.isOk, isFalse);
      final tampered = base64Encode(await license(signer: otherPair));
      expect((await port.installEnterpriseLicense(tampered)).isOk, isFalse);
      expect(svc.access.effectivePlan, Plan.free);
      final ok = base64Encode(await license());
      expect((await port.installEnterpriseLicense(ok)).isOk, isTrue);
      expect(svc.access.effectivePlan, Plan.enterprise);
    },
  );
}
