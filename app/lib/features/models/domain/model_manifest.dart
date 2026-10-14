import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Verifies a signed **single-model manifest** for offline import (MDL-04).
///
/// Format: a schema-1 catalog document (`catalog.json` format, same pinned
/// Ed25519 keys, same `.sig` envelope) whose `models` list has exactly one
/// entry — produced by `tools/model-catalog/catalog.py build --only <id>`.
/// So the signature, schema, field and app-version checks are *identical*
/// to the online catalog path. No rollback floor applies: an air-gapped
/// device may legitimately import a manifest older than its bundled catalog
/// (the model file is still pinned by size + SHA-256).
Future<Result<CatalogModel>> verifySingleModelManifest(
  CatalogVerifier verifier, {
  required List<int> manifestBytes,
  required List<int> signatureBytes,
  required SemVer appVersion,
}) async {
  final verified = await verifier.verify(
    catalogBytes: manifestBytes,
    signatureBytes: signatureBytes,
    appVersion: appVersion,
  );
  return switch (verified) {
    Err(:final failure) => Err(failure),
    Ok(:final value) when value.models.length != 1 => Err(
      ModelImportFailure(ModelImportRejection.notSingleModel),
    ),
    Ok(:final value) => Ok(value.models.single),
  };
}
