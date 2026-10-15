/// Hosts the `NetworkGateway` may contact: model catalog + model files only
/// (MDL-01). Every URL in the signed catalog and in `kCatalogBaseUris` must
/// use one of these hosts (enforced by tests).
///
/// Product owner decision 2026-10-14 (ADR-MDL-01, Accepted): models are
/// hosted on **Hugging Face only** — pinned-revision `resolve/<rev>/<file>`
/// URLs. There is no own CDN; integrity comes from the Ed25519-signed
/// catalog, not from the host.
library;

/// The only host the gateway contacts directly.
const kModelHuggingFaceHost = 'huggingface.co';

/// Every directly contacted host (Hugging Face only).
const Set<String> kModelHosts = {kModelHuggingFaceHost};

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

/// Settings key (`settings` table): when true the gateway refuses every
/// request — user "offline mode" or enterprise managed config
/// `network_disabled` (LIC-04 writes/overrides it). Models are then
/// provisioned by offline import only (MDL-04).
const kNetworkDisabledKey = 'network_disabled';
