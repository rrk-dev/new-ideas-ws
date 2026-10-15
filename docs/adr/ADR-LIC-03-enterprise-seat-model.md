# ADR-LIC-03 — Enterprise licence seats: honor system + annual true-up

- **Status:** Proposed (owner chose this model 2026-10-15; the production signing key and the
  independent review of `docs/enterprise-licensing.md` are still open)
- **Date:** 2026-10-15
- **Task:** LIC-03
- **Deciders:** product owner (seat model); Copilot CLI (implementer)

## Context
Enterprises license N seats without a usage-tracking cloud (`AGENTS.md`: no user content or
telemetry leaves the device; network only through the allowlisted gateway).

## Options
| Option | Privacy | Ops cost | Enforcement |
|---|---|---|---|
| A. Honor system + annual admin true-up (signed licence file carries `seats`) | no network, no identifiers | none | contractual |
| B. Customer-hosted licence server | needs an allowlisted per-org host | high (customer runs a server) | technical |

## Decision
**A.** The signed `.vvlicense` states `seats`; the app never counts or reports installs. The
admin reports actual usage at the annual true-up (MDM inventory is the customer's own record).
Enforcement is contractual. B stays a possible later option behind a new ADR; it is not built.

## Consequences
- No new network egress; `check_egress.sh` is unaffected.
- A leaked licence file can be installed on more devices than `seats`; mitigated by expiry and
  by `license_id` revocation at the next issue, not by the app.
- The signing key is offline; the app pins 1–2 public keys (rotation = ship old + new).

## Open
- Production Ed25519 key generation and pinning (`kEnterpriseLicenseKeys` is empty until then, so
  every licence is rejected — fail closed).
- Independent review of `docs/enterprise-licensing.md` (LIC-03 AC1).
