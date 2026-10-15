import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';

const int kMaxLicenseBytes = 64 * 1024;
const Duration kLicenseGrace = Duration(days: 30);
const Duration kLicenseWarnBefore = Duration(days: 30);
const Duration _kIssuedAtSkew = Duration(hours: 24);

/// Public keys that may sign enterprise licences. Empty until the production
/// key is generated (ADR-LIC-03 "Open"): every licence is then rejected.
final List<CatalogPublicKey> kEnterpriseLicenseKeys = <CatalogPublicKey>[];

enum LicenseStatus { valid, expiringSoon, inGrace, expired }

/// A signature-checked enterprise licence payload.
final class EnterpriseLicense {
  const EnterpriseLicense({
    required this.licenseId,
    required this.orgId,
    required this.orgName,
    required this.seats,
    required this.issuedAt,
    required this.expiresAt,
    required this.features,
    this.orgProfilePubKey,
  });

  final String licenseId;
  final String orgId;
  final String orgName;
  final int seats;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Set<Feature> features;

  /// Raw 32-byte key that signs the org's profile packs (PRF-08).
  final Uint8List? orgProfilePubKey;

  LicenseStatus statusAt(DateTime now) {
    if (now.isBefore(expiresAt.subtract(kLicenseWarnBefore))) {
      return LicenseStatus.valid;
    }
    if (now.isBefore(expiresAt)) return LicenseStatus.expiringSoon;
    if (now.isBefore(expiresAt.add(kLicenseGrace))) {
      return LicenseStatus.inGrace;
    }
    return LicenseStatus.expired;
  }

  /// The Enterprise entitlement; its expiry is the end of the grace window.
  Entitlement toEntitlement(DateTime now) => Entitlement(
    plan: Plan.enterprise,
    verifiedAt: now,
    source: EntitlementSource.enterpriseLicense,
    expiresAt: expiresAt.add(kLicenseGrace),
    extraFeatures: features,
  );
}

/// Verifies `.vvlicense` files (format in `docs/enterprise-licensing.md`).
class EnterpriseLicenseVerifier {
  EnterpriseLicenseVerifier({required List<CatalogPublicKey> trustedKeys})
    : _keys = {for (final k in trustedKeys) k.keyId: k};

  final Map<String, CatalogPublicKey> _keys;
  static final _ed25519 = DartEd25519();

  Future<Result<EnterpriseLicense>> verify(
    List<int> fileBytes, {
    required DateTime now,
  }) async {
    if (fileBytes.length > kMaxLicenseBytes) return _err(.tooLarge);
    final Object? doc;
    try {
      doc = jsonDecode(utf8.decode(fileBytes));
    } on FormatException {
      return _err(.malformed);
    }
    if (doc is! Map<String, Object?>) return _err(.malformed);
    if (doc['format'] != 1 || doc['alg'] != 'ed25519') {
      return _err(.unsupportedFormat);
    }
    final keyId = doc['key_id'];
    final payloadB64 = doc['payload'];
    final sigB64 = doc['sig'];
    if (keyId is! String || payloadB64 is! String || sigB64 is! String) {
      return _err(.malformed);
    }
    final List<int> payload;
    final List<int> sig;
    try {
      payload = base64Decode(payloadB64);
      sig = base64Decode(sigB64);
    } on FormatException {
      return _err(.malformed);
    }
    if (sig.length != 64) return _err(.malformed);
    final key = _keys[keyId];
    if (key == null) return _err(.unknownKey);
    final ok = await _ed25519.verify(
      payload,
      signature: Signature(
        sig,
        publicKey: SimplePublicKey(key.bytes, type: KeyPairType.ed25519),
      ),
    );
    if (!ok) return _err(.badSignature);

    final license = _parse(payload);
    if (license == null) return _err(.invalidField);
    if (license.issuedAt.isAfter(now.add(_kIssuedAtSkew))) {
      return _err(.notYetValid);
    }
    if (license.statusAt(now) == LicenseStatus.expired) return _err(.expired);
    return Ok(license);
  }

  static Err<EnterpriseLicense> _err(LicenseRejection r) =>
      Err(LicenseFailure(r));

  static EnterpriseLicense? _parse(List<int> payload) {
    try {
      final m = jsonDecode(utf8.decode(payload));
      if (m is! Map<String, Object?>) return null;
      final id = m['license_id'];
      final orgId = m['org_id'];
      final orgName = m['org_name'];
      final seats = m['seats'];
      final issued = DateTime.tryParse('${m['issued_at']}');
      final expires = DateTime.tryParse('${m['expires_at']}');
      final features = m['features'];
      final profileKey = m['org_profile_pubkey'];
      if (id is! String || id.isEmpty) return null;
      if (orgId is! String || orgId.isEmpty) return null;
      if (orgName is! String || orgName.isEmpty) return null;
      if (seats is! int || seats < 1) return null;
      if (issued == null || expires == null || !expires.isAfter(issued)) {
        return null;
      }
      if (features is! List || features.any((f) => f is! String)) return null;
      Uint8List? orgKey;
      if (profileKey != null) {
        if (profileKey is! String) return null;
        orgKey = Uint8List.fromList(base64Decode(profileKey));
        if (orgKey.length != 32) return null;
      }
      final known = {for (final f in Feature.values) f.name: f};
      return EnterpriseLicense(
        licenseId: id,
        orgId: orgId,
        orgName: orgName,
        seats: seats,
        issuedAt: issued.toUtc(),
        expiresAt: expires.toUtc(),
        // Unknown names come from a newer issuer; ignoring them is safe.
        features: {
          for (final n in features.cast<String>())
            if (known[n] != null) known[n]!,
        },
        orgProfilePubKey: orgKey,
      );
    } on FormatException {
      return null;
    }
  }
}
