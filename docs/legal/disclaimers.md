# In-app disclaimer strings (LEG-01)

> **DRAFT — requires review by a qualified lawyer before release**

The exact short texts the app shows. They live in
`app/lib/core/l10n/arb/app_en.arb` under the key in the first column, and a
test (`[LEG-01/AC5]`) fails if the two differ. Change both together, then bump
`kLegalVersion` if the wording changes the agreement (see `README.md`).

| Key | Where it shows | Text |
|---|---|---|
| `aiOutputDisclaimer` | Under Ask answers, under extraction and summary results, and in the review screen | AI-generated and can be wrong. Check it against the recording before you rely on it. Not medical, legal, financial or professional advice. |
| `legalAgeConfirm` | First-run acceptance screen (checkbox) | I am 21 or older. |
| `legalAgreeConfirm` | First-run acceptance screen (checkbox) | I have read and agree to the Terms of Use and the Privacy Policy. |
| `legalRecordingResponsibility` | First-run acceptance screen (text) | You are responsible for recording laws and for getting consent from the people you record. |
