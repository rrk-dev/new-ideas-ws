import 'dart:typed_data';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/network/network_gateway.dart';
import 'package:vaultvoice/features/models/data/catalog_config.dart';
import 'package:vaultvoice/features/models/domain/catalog_state_store.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Loads raw asset bytes (production: `rootBundle`; tests: files).
typedef AssetBytesLoader = Future<Uint8List> Function(String key);

/// Owns the active model catalog: the signed bundled fallback, replaced by a
/// newer signed catalog fetched through the [NetworkGateway].
///
/// A rejected or unreachable remote catalog never replaces the active one.
class CatalogRepository {
  CatalogRepository({
    required this._gateway,
    required this._verifier,
    required this._loadAsset,
    required CatalogStateStore stateStore,
    List<Uri>? baseUris,
    this._appVersion = kCatalogAppVersion,
  }) : _state = stateStore,
       _bases = baseUris ?? kCatalogBaseUris;

  final NetworkGateway _gateway;
  final CatalogVerifier _verifier;
  final AssetBytesLoader _loadAsset;
  final CatalogStateStore _state;
  final List<Uri> _bases;
  final SemVer _appVersion;

  ModelCatalog? _current;

  /// The active catalog, or null before [loadBundled] succeeded.
  ModelCatalog? get current => _current;

  /// Verifies the bundled catalog (first launch / offline) and makes it
  /// active if nothing newer is active yet.
  Future<Result<ModelCatalog>> loadBundled() async {
    final Uint8List bytes;
    final Uint8List sig;
    try {
      bytes = await _loadAsset(kBundledCatalogAsset);
      sig = await _loadAsset(kBundledCatalogSigAsset);
    } on Exception catch (e) {
      return Err(
        StorageFailure('bundled catalog unreadable: ${e.runtimeType}'),
      );
    }
    final result = await _verifier.verify(
      catalogBytes: bytes,
      signatureBytes: sig,
      appVersion: _appVersion,
    );
    final catalog = result.valueOrNull;
    if (catalog != null &&
        (_current == null || catalog.issuedAt.isAfter(_current!.issuedAt))) {
      _current = catalog;
    }
    return result;
  }

  /// Fetches `catalog.json` + `.sig` from each base URL in order until one
  /// verifies and is not older than the active / last accepted catalog.
  /// When none succeeds the active catalog stays and the first verification
  /// rejection (tampered, rollback, …) is returned, else the last
  /// network/HTTP failure.
  Future<Result<ModelCatalog>> refresh() async {
    if (_current == null) {
      final bundled = await loadBundled();
      if (!bundled.isOk) return bundled;
    }
    final stored = await _state.lastAcceptedIssuedAt();
    var floor = _current!.issuedAt;
    if (stored != null && stored.isAfter(floor)) floor = stored;

    Failure last = const NetworkFailure('no catalog endpoint configured');
    Failure? rejected;
    for (final base in _bases) {
      final catalogRes = await _fetch(base.resolve('catalog.json'));
      final catalogBytes = catalogRes.valueOrNull;
      if (catalogBytes == null) {
        last = catalogRes.failureOrNull!;
        continue;
      }
      final sigRes = await _fetch(base.resolve('catalog.json.sig'));
      final sigBytes = sigRes.valueOrNull;
      if (sigBytes == null) {
        last = sigRes.failureOrNull!;
        continue;
      }
      final verified = await _verifier.verify(
        catalogBytes: catalogBytes,
        signatureBytes: sigBytes,
        appVersion: _appVersion,
        rollbackFloor: floor,
      );
      final catalog = verified.valueOrNull;
      if (catalog == null) {
        rejected ??= verified.failureOrNull;
        continue;
      }
      _current = catalog;
      await _state.saveAcceptedIssuedAt(catalog.issuedAt);
      return verified;
    }
    return Err(rejected ?? last);
  }

  Future<Result<Uint8List>> _fetch(Uri uri) async {
    final res = await _gateway.get(uri, headers: kAnonymousRequestHeaders);
    return switch (res) {
      Err(:final failure) => Err(failure),
      Ok(value: final r) when r.statusCode != 200 => Err(
        CatalogFailure(CatalogRejection.httpStatus),
      ),
      Ok(value: final r) when r.bodyBytes.length > kMaxCatalogBytes => Err(
        CatalogFailure(CatalogRejection.tooLarge),
      ),
      Ok(value: final r) => Ok(r.bodyBytes),
    };
  }
}
