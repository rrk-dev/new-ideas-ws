# Device matrix and lab

Lab inventory for Lumen. Maintained by QA-05. Performance, battery, thermal, and
phase-gate runs use only rows whose **Status** is `In lab`.

Cloud device farms are not part of this lab. See
[ADR-QA-05](adr/ADR-QA-05-device-lab.md) (Proposed).

**As of 2026-10-12 every required phone and the iPad are still to procure.** Nothing
below has been measured on hardware. GPU and CPU-feature cells stay `untested` until
a unit is in hand.

## Roles

Eight units cover the QA-05 scope. Overlapping requirements share one phone.

| ID | Role | Required hardware | Also covers | Tier (LLM-07) |
|---|---|---|---|---|
| VV-IOS-11 | Oldest iPhone | iPhone 11, A13, 4 GB | GATE-01 oldest iPhone; Low-tier RAM; oldest Metal GPU | Low |
| VV-IOS-14 | 6 GB iPhone | iPhone 14, A15, 6 GB | Mid tier. See substitutes below | Mid |
| VV-IOS-16 | Newest iPhone | iPhone 16, A18, 8 GB | GATE-01 newest iPhone; High tier; A17 Pro/A18 class | High |
| VV-IOS-PAD | iPad | iPad (10th generation, 2022), A14, 4 GB | Tablet layout, different thermal envelope | Low |
| VV-AND-PIX | Reference Android | Pixel 8, Pixel 8a, or Pixel 9 (Tensor, Mali) | Stock Android, Mali Vulkan on a Google OEM | Mid or High (record the SKU's RAM) |
| VV-AND-FLG | Flagship + Samsung battery | Galaxy S24 or S25 **Snapdragon** variant, ≥ 8 GB | Snapdragon 8 Gen 3 / 8 Elite class; Samsung OEM battery limits | High |
| VV-AND-7 | Mid-range | Any phone with a Snapdragon 7-series SoC and ≥ 6 GB RAM | QA-03 budget-Android target | Mid |
| VV-AND-4G | 4 GB + MediaTek/Mali | A 4 GB phone with a MediaTek SoC and a Mali GPU | Low tier; Mali on a non-Google OEM. A Galaxy A-series unit also adds a second Samsung battery profile | Low |

### Substitutes

Buy the named SKU when you can. These substitutes still fill the role; anything else
does not.

| Role | Acceptable substitute | Does not count |
|---|---|---|
| VV-IOS-14 | iPhone 13 Pro, 13 Pro Max, 14 Plus, 14 Pro, 14 Pro Max (all 6 GB) | iPhone 13 and 13 mini (4 GB). They duplicate VV-IOS-11's RAM class |
| VV-IOS-16 | iPhone 15 Pro, 15 Pro Max, 16 Plus, 16 Pro, 16 Pro Max (8 GB, A17 Pro or A18) | iPhone 15 and 15 Plus (6 GB, A16) |
| VV-IOS-PAD | Any iPad with ≥ 4 GB RAM that runs iOS 16 or later | iPad (9th generation): A13, 3 GB |
| VV-AND-FLG | A non-Samsung Snapdragon 8 Gen 3 or 8 Elite phone **only if** a different Samsung (for example the 4 GB Galaxy) is already in the lab for OEM battery tests | Exynos Galaxy models. Confirm Settings shows Qualcomm |
| VV-AND-7 | Snapdragon 7 Gen 3, 7+ Gen 2, 7s Gen 2, or 7s Gen 3 | Tensor, Dimensity, Helio, Exynos |
| VV-AND-4G | Any other 4 GB MediaTek + Mali phone | A 6 GB or 8 GB variant of the same model. A 4 GB Snapdragon (no Mali / not MediaTek) |

Qualcomm dropped the "8 Gen 4" name. The chip that followed Snapdragon 8 Gen 3 shipped
as **Snapdragon 8 Elite**. Either that part or Snapdragon 8 Gen 3 fills VV-AND-FLG. A
newer 8 Elite generation also fills it; write the exact marketing name in the inventory.

Apple does not publish RAM on the tech-spec pages. The RAM figures above are the
QA-05 scope plus public teardowns (iPhone 11 and iPhone 16: GSMArena comparison;
iPhone 13 base vs 13 Pro / iPhone 14: same public teardown class). When a unit
arrives, record what the OS reports, not the sticker, in the inventory.

## Inventory

Fill **Owner**, **Location**, **OS**, and **Serial** when the unit is on the shelf.
Leave **GPU** and **Dotprod** as `untested` until the checks below have been run.
Status values: `To procure` · `Ordered` · `In lab` · `Retired`.

| ID | Device (actual SKU) | SoC | RAM | OS installed | GPU backend | Dotprod | Owner | Location | Status |
|---|---|---|---|---|---|---|---|---|---|
| VV-IOS-11 | iPhone 11 (buy) | A13 | 4 GB | — | untested (expect Metal) | untested (expect yes) | — | — | To procure |
| VV-IOS-14 | iPhone 14 (buy) | A15 | 6 GB | — | untested (expect Metal) | untested (expect yes) | — | — | To procure |
| VV-IOS-16 | iPhone 16 (buy) | A18 | 8 GB | — | untested (expect Metal) | untested (expect yes) | — | — | To procure |
| VV-IOS-PAD | iPad 10th gen (buy) | A14 | 4 GB | — | untested (expect Metal) | untested (expect yes) | — | — | To procure |
| VV-AND-PIX | Pixel 8 / 8a / 9 (buy) | Tensor (record generation) | record | — | untested (expect Vulkan; OpenCL often absent) | untested | — | — | To procure |
| VV-AND-FLG | Galaxy S24 or S25 Snapdragon (buy) | 8 Gen 3 or 8 Elite | ≥ 8 GB | — | untested (expect Vulkan, OpenCL possible) | untested (expect yes) | — | — | To procure |
| VV-AND-7 | Snapdragon 7-series (buy) | record exact 7-series part | ≥ 6 GB | — | untested (expect Vulkan) | untested | — | — | To procure |
| VV-AND-4G | 4 GB MediaTek + Mali (buy) | record Helio or Dimensity part | 4 GB | — | untested (expect Vulkan; OpenCL often absent) | untested — required before FND-06 picks `+dotprod` | — | — | To procure |

Serial numbers stay in this file only if the team is comfortable with them in git.
A lab notebook is fine; this table then keeps the last four digits.

## What to record when a device arrives

1. Set **Status** to `In lab`, and fill owner, location, and the OS version from Settings.
2. Android CPU features (needed by FND-06):

   ```bash
   adb shell grep -m1 Features /proc/cpuinfo
   ```

   `asimddp` means FEAT_DotProd is present. Write `yes` or `no` in **Dotprod**.
3. iOS dotprod is expected on every row here: A13 implements A64 ARMv8.4-A
   ([Apple A13](https://en.wikipedia.org/wiki/Apple_A13), checked 2026-10-12) and
   FEAT_DotProd is mandatory from Armv8.4 (Arm ARM, `UDOT`). FND-06 still confirms
   with a device probe before a dotprod-only binary is allowed. Write the probe
   result into **Dotprod**.
4. GPU: after STT-01/02 and LLM-02/03, record which backend initialized (Metal,
   Vulkan, OpenCL, or CPU fallback) and whether init failed over to CPU. NNAPI is
   out of scope.
5. Re-copy the OS version at each phase gate (GATE-01 … GATE-04).

OS policy:

- Floor is iOS 16 and Android 8 (API 26). The lab does not include a dedicated
  API 26 phone; see Follow-ups on QA-05.
- Keep VV-IOS-16 and VV-AND-PIX on the current public OS. They are the "newest"
  devices for GATE-01 and the 16 KB page-size check (Android 15+).
- VV-IOS-11 and VV-AND-4G stay on current OS too unless a bug is suspected on the
  floor. Old silicon is the point of those rows, not an old OS image.
- The iOS simulator is not a matrix device. It has no Metal performance parity.

## Lab rules

- Synthetic or consented audio only. No personal recordings in the repo, in CI
  artifacts, or on a farm. Consented audio, if any, stays outside the repo.
- Call tests (SEC-09, QA-04) check that capture stops and does not resume. They
  are not a way to record a call.
- No analytics, crash, or ads SDK on these devices' builds. Diagnostics leave the
  phone only when a person shares them (FND-07).
- Model files are test models from `tools/ci/fetch_test_models.sh` or a sideload.
  Do not put real user vaults on lab phones.

## Cloud farms

Do not send builds or audio to Firebase Test Lab, Google Cloud Developer Device
Platform, or BrowserStack. Rationale and the conditions under which that could be
reopened: [ADR-QA-05](adr/ADR-QA-05-device-lab.md).

## Known gaps

- No phone pinned to Android 8.0. Emulators are not valid stand-ins for ggml.
- No Android tablet. Tablet layout is exercised on the iPad only.
- Units are not in the lab yet. Phase 1 exit needs every row at `In lab`. The
  check is `docs/test-plans/device/QA-05.md`.
