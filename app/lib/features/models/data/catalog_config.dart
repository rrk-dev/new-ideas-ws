import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// App version the catalog `min_app_version` is compared with. Kept equal to
/// `version:` in pubspec.yaml by a test (no package_info dependency needed).
const kCatalogAppVersion = SemVer(1, 0, 0);

/// Where `catalog.json` + `catalog.json.sig` are fetched from, in order
/// (primary, then mirrors). Each base must end with `/`.
///
/// PRODUCT-DECISION: CDN provider + domain (ADR-MDL-01). Add a mirror base
/// here once one is provisioned; its host must be in [kModelHosts].
final List<Uri> kCatalogBaseUris = [
  Uri.parse('https://$kModelCdnHost/catalog/v1/'),
];

const kBundledCatalogAsset = 'assets/catalog/catalog.json';
const kBundledCatalogSigAsset = 'assets/catalog/catalog.json.sig';

/// The only headers sent with catalog and model requests: no cookies, no
/// auth, no device or install identifiers, a generic major-version UA.
/// (dart:io still adds Host, Accept-Encoding and Content-Length; see
/// docs/privacy-audit.md.)
const kAnonymousRequestHeaders = {
  'User-Agent': 'VaultVoice/1',
  'Accept': '*/*',
};
