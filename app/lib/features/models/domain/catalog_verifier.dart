import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Upper bound for `catalog.json` (and its `.sig`): parsing more is a DoS risk.
const int kMaxCatalogBytes = 1024 * 1024;
const _kMaxSignatureFileBytes = 4096;

/// An Ed25519 public key pinned in the app.
class CatalogPublicKey {
  /// [bytes] is the raw 32-byte Ed25519 public key.
  CatalogPublicKey(List<int> bytes)
    : bytes = Uint8List.fromList(bytes),
      keyId = catalogKeyId(bytes) {
    if (bytes.length != 32) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must be 32');
    }
  }

  /// From a base64 string (as printed by `catalog.py pubkey`).
  factory CatalogPublicKey.base64(String b64) =>
      CatalogPublicKey(base64Decode(b64));

  final Uint8List bytes;

  /// First 8 bytes (hex) of SHA-256(raw key) — the `key_id` in `.sig` files.
  final String keyId;
}

/// `key_id` for a raw public key; same derivation as `catalog.py key_id`.
String catalogKeyId(List<int> rawPublicKey) =>
    crypto.sha256.convert(rawPublicKey).toString().substring(0, 16);

/// Verifies `catalog.json` + `catalog.json.sig` against pinned keys.
///
/// Order: size caps → signature envelope → pinned key → Ed25519 over the
/// exact bytes → schema → field validation → rollback → min app version.
/// Nothing from the catalog is parsed before the signature is checked.
class CatalogVerifier {
  /// [trustedKeys]: one key, or two during a rotation (old + new).
  CatalogVerifier({required List<CatalogPublicKey> trustedKeys})
    : _keys = {for (final k in trustedKeys) k.keyId: k} {
    if (trustedKeys.isEmpty || trustedKeys.length > 2) {
      throw ArgumentError('pin one or two catalog keys');
    }
  }

  final Map<String, CatalogPublicKey> _keys;

  // Pure-Dart implementation: identical behaviour on iOS, Android and host.
  static final _ed25519 = DartEd25519();

  /// Returns the parsed catalog or a [CatalogFailure].
  ///
  /// [rollbackFloor]: `issued_at` of the newest catalog already accepted
  /// (bundled or previously fetched); an older catalog is rejected.
  Future<Result<ModelCatalog>> verify({
    required List<int> catalogBytes,
    required List<int> signatureBytes,
    required SemVer appVersion,
    DateTime? rollbackFloor,
  }) async {
    if (catalogBytes.length > kMaxCatalogBytes ||
        signatureBytes.length > _kMaxSignatureFileBytes) {
      return _err(CatalogRejection.tooLarge);
    }
    final envelope = _parseEnvelope(signatureBytes);
    if (envelope == null) return _err(CatalogRejection.malformedSignature);
    final key = _keys[envelope.keyId];
    if (key == null) return _err(CatalogRejection.unknownKey);

    final ok = await _ed25519.verify(
      catalogBytes,
      signature: Signature(
        envelope.signature,
        publicKey: SimplePublicKey(key.bytes, type: KeyPairType.ed25519),
      ),
    );
    if (!ok) return _err(CatalogRejection.badSignature);

    final parsed = ModelCatalog.parse(catalogBytes);
    final catalog = parsed.valueOrNull;
    if (catalog == null) return parsed;
    if (rollbackFloor != null && catalog.issuedAt.isBefore(rollbackFloor)) {
      return _err(CatalogRejection.rollback);
    }
    if (catalog.minAppVersion.compareTo(appVersion) > 0) {
      return _err(CatalogRejection.appTooOld);
    }
    return Ok(catalog);
  }

  static Err<ModelCatalog> _err(CatalogRejection r) => Err(CatalogFailure(r));

  static _Envelope? _parseEnvelope(List<int> bytes) {
    try {
      final doc = jsonDecode(utf8.decode(bytes));
      if (doc is! Map<String, Object?> || doc['alg'] != 'ed25519') return null;
      final keyId = doc['key_id'];
      final sig = doc['sig'];
      if (keyId is! String || sig is! String) return null;
      final raw = base64Decode(sig);
      if (raw.length != 64) return null;
      return _Envelope(keyId, raw);
    } on FormatException {
      return null;
    }
  }
}

class _Envelope {
  const _Envelope(this.keyId, this.signature);
  final String keyId;
  final Uint8List signature;
}
