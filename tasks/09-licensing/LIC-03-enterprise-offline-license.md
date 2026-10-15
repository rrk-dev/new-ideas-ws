# LIC-03 — Enterprise Offline License Keys & Seat Management

**Workstream:** Licensing | **Phase:** 4+ | **Size:** L | **Depends on:** LIC-01 | **Source:** §7 (Centralized local license management without cloud analytics)
**Status:** in-progress
**Skills:** vv-task-workflow, vv-licensing-iap, vv-decision-records, vv-privacy-security, vv-testing

## Goal
Enterprises license N seats without a usage-tracking cloud.

## Scope
- [ ] Design doc first (no design exists in master plan): signed license file (Ed25519) containing org id, seat count, expiry, feature set, org public key for signed profile packs (PRF-08).
- [ ] Activation offline: license file delivered via MDM managed config (LIC-04) or file import.
- [ ] Seat model: honor-system + periodic admin true-up vs local license server on customer network — decide and document.
- [ ] Admin tool (CLI) to generate/sign licenses (internal).
- [ ] Expiry warnings and grace period.

## Acceptance Criteria
- Design reviewed and approved; app accepts valid, rejects tampered/expired licenses in tests.
