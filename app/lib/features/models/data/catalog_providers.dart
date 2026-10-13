import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/models/data/catalog_repository.dart';
import 'package:vaultvoice/features/models/domain/catalog_keys.dart';
import 'package:vaultvoice/features/models/domain/catalog_state_store.dart';
import 'package:vaultvoice/features/models/domain/catalog_verifier.dart';

part 'catalog_providers.g.dart';

@Riverpod(keepAlive: true)
CatalogVerifier catalogVerifier(Ref ref) =>
    CatalogVerifier(trustedKeys: pinnedCatalogKeys());

/// In-memory until FND-04 lands a persistent store (follow-up MDL-05).
@Riverpod(keepAlive: true)
CatalogStateStore catalogStateStore(Ref ref) => InMemoryCatalogStateStore();

@Riverpod(keepAlive: true)
CatalogRepository catalogRepository(Ref ref) => CatalogRepository(
  gateway: ref.watch(networkGatewayProvider),
  verifier: ref.watch(catalogVerifierProvider),
  stateStore: ref.watch(catalogStateStoreProvider),
  loadAsset: (key) async => (await rootBundle.load(key)).buffer.asUint8List(),
);
