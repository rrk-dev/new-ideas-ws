/// Hosts the `NetworkGateway` may contact: model catalog + model files only
/// (MDL-01). Every URL in the signed catalog and in `CatalogEndpoints` must
/// use one of these hosts (enforced by tests).
///
/// PRODUCT-DECISION: `models.vaultvoice.example` is a placeholder for our own
/// object storage + CDN (ADR-MDL-01). `.example` never resolves, so until the
/// owner provisions the CDN the app falls back to the bundled catalog and the
/// Hugging Face mirror URLs.
library;

const kModelCdnHost = 'models.vaultvoice.example';

/// Mirror for model files (pinned-revision URLs in the catalog).
const kModelMirrorHosts = {'huggingface.co'};

const Set<String> kModelHosts = {kModelCdnHost, ...kModelMirrorHosts};
