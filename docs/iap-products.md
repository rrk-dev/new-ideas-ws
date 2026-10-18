# In-app purchase products

Store product identifiers used by LIC-01 / LIC-02. Copy, prices, and
tax categories are product-owned — `[PRODUCT]` placeholders below.

| Product ID | Type | Platforms | Notes |
|---|---|---|---|
| `vv_pro_annual` | Auto-renewable subscription | App Store, Play | Annual Pro. |
| `vv_pro_lifetime` | Non-consumable | App Store, Play | One-time lifetime Pro. |

## App Store Connect

Create both products in the Lumen app record **before** the first
production submission (REL-06).

1. `vv_pro_annual`
   - Type: Auto-Renewable Subscription
   - Subscription group: `[PRODUCT] Lumen Pro`
   - Duration: 1 year
   - Localization: `[PRODUCT] display name and description`
   - Price: `[PRODUCT]`
2. `vv_pro_lifetime`
   - Type: Non-Consumable
   - Localization: `[PRODUCT] display name and description`
   - Price: `[PRODUCT]`

Reviewer notes for IAP: Pro unlocks longer recordings, extra profiles, and
on-device model downloads as described in `docs/licenses.md`. No ads. No
account required. Restore Purchases is on Settings.

## Google Play Console

Create a subscription and a one-time product with the **same product IDs**.

1. `vv_pro_annual` — subscription, 1-year base plan, `[PRODUCT]` price.
2. `vv_pro_lifetime` — one-time (managed product), `[PRODUCT]` price.

Play Billing acknowledgements and entitlement mapping live in LIC-02.

## Code alignment

Dart product IDs must stay `vv_pro_annual` and `vv_pro_lifetime`. Changing
them after first sale is a store-ops incident, not a rename.

## Pro tier suppression (LIC-05)

Decision, 2026-10-17 (product owner): **no Pro tier for now.** Every feature
is available to everyone. The paywall, store products and prices are
untouched; they are just not reachable.

- Switch: `proTierEnforced` (`kProTierEnforced`, dart-define
  `VV_PRO_ENFORCED`, default `false`). Off: the Pro column of
  `kFeatureMatrix` is open to all plans (including the 3B model), no
  paywall is shown and Settings hides the upgrade tile. Enterprise-only
  features (managed profiles) still need an enterprise licence.
- The intended tier of every feature stays in `kFeatureMatrix`
  (`PRODUCT-DECISION` markers): quick capture is Free; the Lecture, Sales
  call and Interview profiles, Ask, mind maps and Reminders export are Pro,
  as are the 3B model and the earlier Pro rows.

Enable Pro later (checklist):

- [ ] Build store releases with `--dart-define=VV_COMMERCIAL=true --dart-define=VV_PRO_ENFORCED=true`.
- [ ] Review the Pro column of `kFeatureMatrix` and change any tier the owner changes.
- [ ] Create the store products above and fill the `[PRODUCT]` fields.
- [ ] Wire `ensureFeature` into Ask (ASK-04) and Reminders export (TSK-02) if not yet done.
- [ ] Run `nice -n 10 fvm flutter test test/unit/licensing test/widget/pro_tier_switch_test.dart`.

Enterprise licensing (LIC-03 / LIC-04) is out of scope for v1.
