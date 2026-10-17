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

Enterprise licensing (LIC-03 / LIC-04) is out of scope for v1.
