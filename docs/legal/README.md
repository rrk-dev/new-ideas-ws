# Legal documents (LEG-01)

> **DRAFT — requires review by a qualified lawyer before release**

These documents were written by engineers to match what the app does. They are
**not legal advice** and have not been reviewed by a lawyer. They try to limit
the publisher's liability and to make the user responsible for their own use
as far as the law allows. They do not try to waive rights that the law says
cannot be waived, and they must stay true to the app: a privacy policy that
misstates data handling is itself a legal risk.

## What is where

| File | What it is |
|---|---|
| `app/assets/legal/terms_of_use.md` | Terms of Use shown in the app (Settings → About) and at first run |
| `app/assets/legal/privacy_policy.md` | Privacy Policy shown in the app |
| `docs/legal/disclaimers.md` | The exact short disclaimer strings used in the app |
| `app/lib/features/legal/` | Version constant, release flag, acceptance gate and Terms screen |
| `docs/store/pre-submission-checklist.md` | Release checklist (includes the legal items below) |

Both documents carry one version string (`Version: YYYY-MM-DD`) that must equal
`kLegalVersion` in `app/lib/features/legal/domain/legal_documents.dart` (a test
checks this). Bump both when either document changes in a way users must
accept again: every user is then asked to accept once more.

## The draft banner

Each document starts with a marked comment line and a banner line
(`LEGAL-DRAFT-BANNER`). Once a qualified lawyer has approved the text, do
**one** of these (both is fine):

1. Set `kLegalReleaseApproved = true` in `legal_documents.dart` (the app then
   hides the banner), and/or
2. Delete the two banner lines (the `LEGAL-DRAFT-BANNER` line and the
   `DRAFT` line) at the top of `app/assets/legal/terms_of_use.md` and
   `privacy_policy.md`. The copies under `docs/legal/` are only for your
   own use.

This is a release-checklist item in `docs/store/pre-submission-checklist.md`.

## Facts used (from the owner, 2026-10-18)

- Publisher: **Lumen LLC**. Contact: lumen@lumensupport.org.
- Governing law and courts: India. Court city is the placeholder
  `[CITY, INDIA]` in the Terms. No arbitration.
- Minimum age: 21. Targets: iOS, macOS, Android. Everything is free; no Pro
  tier is enforced.

## Owner TODO before publishing

- [ ] **The publishing entity must exist.** "Lumen LLC" must be a real,
      registered entity before the app is published under that name.
- [ ] **"LLC" is not an Indian company form.** In India the forms are, for
      example, a Limited Liability Partnership (LLP) or a Private Limited
      company. An LLC exists in other countries (for example the US).
      Decide where the entity is formed and change the name in all documents
      and store listings to match.
- [ ] **Check your employment and IP agreements** (notice, moonlighting and
      invention-assignment clauses) before you publish anything. Your
      employer may have rights in work you do.
- [ ] Replace `[CITY, INDIA]` in the Terms (section 23) with the real city.
- [ ] Replace the placeholder model host `models.vaultvoice.example` when the
      CDN exists (`kModelCdnHost`). The privacy policy lists the hosts from
      `kModelHosts`; the test `[LEG-01/AC6]` fails until the policy matches.
- [ ] Host both documents at public URLs (stores require a privacy policy URL;
      the Terms URL is recommended). Put them in App Store Connect and Play
      Console, and in `docs/store/listing.md`.
- [ ] Set up the lumen@lumensupport.org mailbox and a process for requests.
- [ ] Have a lawyer review, then clear the draft banner (above).

## Lawyer checklist

- **Entity and name:** correct legal form, registered office, whether
  "Lumen" conflicts with an existing trademark.
- **Employer IP:** whether the owner's employment agreement affects ownership
  or the right to publish.
- **India DPDP Act 2023:** the data fiduciary or processor position given that
  all processing is on the user's device and the publisher receives no personal
  data except what a model host sees (IP address on download). Whether the
  Act applies to the publisher at all, whether a notice or grievance officer is
  needed, and whether the policy wording on rights is correct.
- **Other regimes:** GDPR and UK GDPR, California CCPA/CPRA, other US states:
  whether "to the extent applicable" statements are enough; whether an EU/UK
  representative is needed.
- **Recording laws:** whether the consent wording and the responsibility
  allocation are adequate for the markets served (all-party consent states,
  workplace, healthcare, legal, children) and the 21+ limit.
- **Liability limits:** the cap (greater of 12 months' fees or INR 1,000 / USD
  10), the carve-outs (fraud, death or personal injury caused by negligence
  where applicable, non-waivable consumer rights), the indemnity, and the
  Indian Contract Act, Consumer Protection Act 2019 and unfair-terms limits.
- **Courts:** exclusive jurisdiction of the courts at the chosen city, and
  the carve-out for mandatory consumer law of the user's place.
- **Stores:** Apple's minimum EULA terms (third-party beneficiary clause),
  Apple standard EULA versus custom terms, Google Play Developer Distribution
  Agreement, App Store Connect and Play Console required fields (privacy URL,
  support URL, App Privacy "Data Not Collected", Data Safety), age rating
  consistency (the 21+ limit versus the store's age rating options; the stores
  may not offer 21), export compliance answers.
- **Model licences:** Llama 3.2 Community License and its Acceptable Use
  Policy pass-through and "Built with Llama" (`docs/licenses.md`).
- **Taxes and consumer rules if charging later:** GST registration and
  invoicing, store tax handling, consumer-law refund and cooling-off rules,
  and whether the Terms and policy need to change when a paid tier launches.
- **Consistency:** every statement in the policy matches
  `docs/privacy-audit.md`, `docs/store/privacy-manifest.md` and
  `docs/threat-model.md`.
