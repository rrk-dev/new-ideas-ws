# LIC-03 — Enterprise Offline License Keys & Seat Management

**Workstream:** Licensing | **Phase:** 4+ | **Size:** L | **Depends on:** LIC-01 | **Source:** §7 (Centralized local license management without cloud analytics)
**Status:** review
**Skills:** vv-task-workflow, vv-licensing-iap, vv-decision-records, vv-privacy-security, vv-testing

## Goal
Enterprises license N seats without a usage-tracking cloud.

## Scope
- [x] Design doc first (no design exists in master plan): signed license file (Ed25519) containing org id, seat count, expiry, feature set, org public key for signed profile packs (PRF-08).
- [x] Activation offline: license file delivered via MDM managed config (LIC-04) or file import.
- [x] Seat model: honor-system + periodic admin true-up vs local license server on customer network — decide and document.
- [x] Admin tool (CLI) to generate/sign licenses (internal).
- [x] Expiry warnings and grace period.

## Acceptance Criteria
- Design reviewed and approved; app accepts valid, rejects tampered/expired licenses in tests.

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/LIC-03-enterprise-license-keys · **Date:** 2026-10-15
- **Summary:** Design `docs/enterprise-licensing.md` + `ADR-LIC-03` (honor-system seats, annual true-up, owner-chosen). `domain/enterprise_license.dart` verifies `.vvlicense` (Ed25519, pinned keys, tamper/expiry/future-issue/size checks, T-30d warning, 30-day grace); `EntitlementLicensePort.installEnterpriseLicense` accepts file JSON or base64 (MDM `license`, wired by LIC-04) and updates the entitlement. `tools/licensing/license.py` CLI (keygen/pubkey/sign/inspect/verify). `kEnterpriseLicenseKeys` is empty until the production key is pinned, so every licence is rejected (fail closed).
- **Acceptance evidence:**
  - AC1: ✅ test: [LIC-03/AC1]; artifact: docs/enterprise-licensing.md
- **Decisions:** ADR-LIC-03-enterprise-seat-model (Proposed)
- **Follow-ups:** production signing key + pinning (owner); LIC-04 MDM delivery

