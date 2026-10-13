import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';

/// Throwaway Ed25519 signer for tests (fixed seed => deterministic). Never
/// used for the shipped catalog.
class TestCatalogSigner {
  TestCatalogSigner._(this._pair, this.publicKey);

  static Future<TestCatalogSigner> fromSeed(int seedByte) async {
    final pair = await DartEd25519().newKeyPairFromSeed(
      List<int>.filled(32, seedByte),
    );
    final pub = await pair.extractPublicKey();
    return TestCatalogSigner._(pair, CatalogPublicKey(pub.bytes));
  }

  final SimpleKeyPair _pair;
  final CatalogPublicKey publicKey;

  /// `catalog.json.sig` bytes over [catalog]; [keyId] overrides the id.
  Future<Uint8List> sign(List<int> catalog, {String? keyId}) async {
    final sig = await DartEd25519().sign(catalog, keyPair: _pair);
    return utf8.encode(
      jsonEncode({
        'alg': 'ed25519',
        'key_id': keyId ?? publicKey.keyId,
        'sig': base64Encode(sig.bytes),
      }),
    );
  }
}

/// A valid schema-1 model entry; override fields via [patch].
Map<String, Object?> testModel({
  String id = 'whisper-tiny.en',
  Map<String, Object?> patch = const {},
}) => {
  'id': id,
  'type': 'stt',
  'version': '1',
  'display_name': 'Whisper Tiny (English)',
  'tier': 'free',
  'file': 'ggml-tiny.en.bin',
  'size': 11,
  'sha256': 'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
  'min_ram_mb': 2048,
  'recommended_device_tiers': ['low', 'mid', 'high'],
  'license': 'MIT',
  'license_url': 'https://github.com/openai/whisper/blob/main/LICENSE',
  'attribution': null,
  'urls': ['https://models.vaultvoice.example/stt/ggml-tiny.en.bin'],
  'companions': <String>[],
  ...patch,
};

/// Catalog JSON bytes; override top-level fields via [patch].
Uint8List testCatalogBytes({
  String issuedAt = '2026-10-12T00:00:00Z',
  List<Map<String, Object?>>? models,
  Map<String, Object?> patch = const {},
}) => utf8.encode(
  const JsonEncoder.withIndent('  ').convert({
    'schema': 1,
    'issued_at': issuedAt,
    'min_app_version': '1.0.0',
    'models': models ?? [testModel()],
    ...patch,
  }),
);
