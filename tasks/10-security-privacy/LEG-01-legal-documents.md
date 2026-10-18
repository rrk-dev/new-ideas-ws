# LEG-01 — Terms of Use, Privacy Policy and in-app legal acceptance

**Workstream:** Security & Privacy | **Phase:** 5 | **Size:** M | **Depends on:** SEC-06, SEC-09, SEC-11 | **Source:** User decision 2026-10-18 (owner request); Gap (no Terms of Use, no explicit acceptance, placeholder privacy policy)
**Status:** review
**Skills:** vv-task-workflow, vv-privacy-security, vv-flutter-architecture, vv-testing

## Goal
The app ships truthful, offline-readable Terms of Use and Privacy Policy that place responsibility for lawful use on the user and limit the publisher's liability as far as the governing law allows, and the user explicitly accepts them (age 21+) before using the app. Every document is a draft until a qualified lawyer reviews it; nothing here is legal advice.

## Scope
- [x] `app/assets/legal/terms_of_use.md` and a rewritten `app/assets/legal/privacy_policy.md`, each with a plain-language summary and a draft banner line that the owner removes (or the release flag hides) once a lawyer has approved.
- [x] `docs/legal/README.md` (what each document is, owner TODOs, lawyer checklist) and `docs/legal/disclaimers.md` (the exact short in-app strings).
- [x] In-app Terms of Use screen, reachable from Settings → About next to the privacy policy; offline asset; no browser, no network.
- [x] First-run acceptance (age 21+, Terms and Privacy "I agree" by explicit tap), stored locally with the document version and timestamp; re-prompt when the bundled version changes; usable offline; existing users prompted once; OS consent dialogs untouched.
- [x] "AI output can be wrong" footnote under Ask answers and under extraction results (summary tab and review screen), from l10n strings equal to `docs/legal/disclaimers.md`.
- [x] Store/legal consistency: `docs/store/pre-submission-checklist.md`, `docs/store/listing.md`, `docs/privacy-audit.md` only where facts change.
- [x] Tests `[LEG-01/ACn]` and `docs/test-plans/device/LEG-01.md`.

## Acceptance Criteria
- Both documents load from the bundle and contain the required sections: liability, indemnity, governing law India, contact, 21+, user-responsible recording law, AI output warning, draft banner (until released).
- First-run acceptance blocks the app until the user taps agree (with the age confirmation), and persists the document version and timestamp; the app stays usable offline.
- A change of the bundled version string prompts again; an unchanged version does not.
- Settings → About opens the Terms of Use screen and the Privacy policy screen from the bundled assets.
- The AI-output disclaimer shows under Ask answers and under extraction output, and its text equals `docs/legal/disclaimers.md`.
- The privacy policy states no analytics, advertising or crash reporting and lists every host in `kModelHosts` and `kModelRedirectHosts`; the draft banner can be hidden by the release flag.
- Device and human rows (lawyer review, store URLs, first-run on a device) exist in `docs/test-plans/device/LEG-01.md`.

## Open Decisions
- Publisher entity ("Lumen LLC") must exist; "LLC" is not an Indian company form. Owner to confirm the legal form and city for the courts placeholder `[CITY, INDIA]`.
- Owner to check employment/IP agreements before publishing.
- Public URLs for both documents are required by the stores (owner TODO).

## Completion Notes
- **Agent:** Copilot CLI · **Branch:** task/LEG-01-legal-documents · **Date:** 2026-10-18
- **Summary:** Added `app/assets/legal/terms_of_use.md`, rewrote `privacy_policy.md` (version 2026-10-18, draft banner until a lawyer approves), `docs/legal/README.md` and `disclaimers.md`. In-app: Terms screen in Settings → About, first-run acceptance gate (age 21+, explicit agree, version and timestamp in the local settings store, re-prompt on version change, offline, no browser), and an "AI output can be wrong" footnote under Ask answers, the summary tab and the review screen. Store docs, audit and checklist updated; two recording-detail goldens regenerated on Linux. Not legal advice; owner and lawyer TODOs are in `docs/legal/README.md`.
- **Not verified here:** first run on devices, lawyer review, public URLs, store fields, banner removal: ⏳ rows in `docs/test-plans/device/LEG-01.md`.
- **Acceptance evidence:**
  - AC1: ✅ test: [LEG-01/AC1]
  - AC2: ✅ test: [LEG-01/AC2]
  - AC3: ✅ test: [LEG-01/AC3]
  - AC4: ✅ test: [LEG-01/AC4]
  - AC5: ✅ test: [LEG-01/AC5]
  - AC6: ✅ test: [LEG-01/AC6]
  - AC7: ⏳ device: docs/test-plans/device/LEG-01.md
