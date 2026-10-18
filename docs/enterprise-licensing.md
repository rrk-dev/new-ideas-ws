# Enterprise licensing (LIC-03)

Decision: [ADR-LIC-03](adr/ADR-LIC-03-enterprise-seat-model.md) — honor-system seats, annual
true-up, no phone-home.

## File format (`*.vvlicense`, UTF-8 JSON)
```json
{"format":1,"alg":"ed25519","key_id":"<16 hex>","payload":"<base64>","sig":"<base64 64 B>"}
```
`payload` is the base64 of the exact JSON bytes that were signed (no canonicalisation step):
```json
{"license_id":"…","org_id":"…","org_name":"…","seats":250,
 "issued_at":"2026-10-15T00:00:00Z","expires_at":"2027-10-15T00:00:00Z",
 "features":["managedProfiles"],"org_profile_pubkey":"<base64 32 B, optional>",
 "managed_config_defaults":{}}
```
Max file size 64 KiB. `key_id` = first 8 bytes (hex) of SHA-256 of the raw public key, same as the
model catalog.

## App verification order
size cap → envelope → pinned key (1–2 keys) → Ed25519 over the payload bytes → schema/field
validation → `issued_at` not in the future (24 h skew) → expiry. Nothing in the payload is trusted
before the signature passes.

## Expiry
- Valid until `expires_at`. From T−30 d the status is `expiringSoon` (Settings shows a warning).
- After `expires_at` a 30-day grace keeps Enterprise active (`inGrace`, warning shown).
- After the grace the entitlement is Free (LIC-01 downgrade policy: read-only, nothing deleted).
- An expired licence is rejected at install time unless it is still inside its grace window.

## Delivery
File import (Settings → License → "Install enterprise licence") or MDM managed config key
`license` (base64 of the file; LIC-04, see `docs/mdm-config.md`). Both call `EnterpriseLicenseService.install`.

## Seats
`seats` is informational in the app. No device counting, no identifiers, no network.

## Admin CLI
`tools/licensing/license.py` — `keygen`, `pubkey`, `sign`, `inspect`, `verify`. The private key is
never written inside a git work tree and never committed.
```bash
python3 tools/licensing/license.py keygen --out ~/secure/vv-license.pem
python3 tools/licensing/license.py sign --key ~/secure/vv-license.pem \
  --org-id acme --org-name "Acme" --seats 250 --days 365 --feature managedProfiles --out acme.vvlicense
python3 tools/licensing/license.py inspect acme.vvlicense
```
