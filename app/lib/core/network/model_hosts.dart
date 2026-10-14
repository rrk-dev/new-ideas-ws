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

/// Hugging Face file CDN hosts that `huggingface.co/<repo>/resolve/<rev>/…`
/// URLs redirect to (MDL-02). Redirect targets only: the gateway never
/// contacts them directly, only right after a redirect from an allowlisted
/// host. Any other redirect target fails closed (download falls through to
/// the next catalog URL).
///
/// Checked 2026-10-13 (`curl -I` on both pinned seed-model URLs, repeated):
/// every redirect went to `us.aws.cdn.hf.co` (Xet bridge, signed query).
/// Other HF CDN names (`cas-bridge.xethub.hf.co`, `cdn-lfs*.hf.co`,
/// regional `*.aws.cdn.hf.co`) were NOT observed and are deliberately not
/// listed — add one only after observing it the same way and documenting it
/// in docs/privacy-audit.md → "Redirect targets".
const kModelRedirectHosts = {'us.aws.cdn.hf.co'};
