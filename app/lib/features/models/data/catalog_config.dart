import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// App version the catalog `min_app_version` is compared with. Kept equal to
/// `version:` in pubspec.yaml by a test (no package_info dependency needed).
const kCatalogAppVersion = SemVer(1, 0, 0);

/// Where `catalog.json` + `catalog.json.sig` are fetched from, in order.
/// Each base must end with `/` and use a host in [kModelHosts] (Hugging
/// Face only, ADR-MDL-01).
///
/// PRODUCT-DECISION: the Hugging Face repository that will publish the signed
/// catalog (e.g. `https://huggingface.co/<org>/<repo>/resolve/main/catalog/v1/`)
/// has not been named yet. Until it is, the app uses the signed bundled
/// catalog only and makes no catalog request (an unclaimed placeholder repo
/// name could be registered by anyone). Add the base here once it exists.
final List<Uri> kCatalogBaseUris = [];

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
