# ADR-QA-05 — Physical device lab, no cloud farm

- **Status:** Proposed
- **Date:** 2026-10-12
- **Task:** QA-05
- **Deciders:** Cursor (recommendation). Human accepts or rejects before any farm account is opened.
- **Supersedes:** —

## Context

QA-05 has to decide whether Firebase Test Lab or BrowserStack runs non-content smoke
tests. The app does not exist yet (FND-01 is still `todo`), and the lab has no phones.

Constraints that are already fixed:

- No user content leaves the device. Fixture and synthetic audio may be discussed for
  a farm; real recordings may not (`vv-testing`, `vv-benchmark-eval`).
- No analytics, crash, or ads SDK in the app.
- Network calls go through `lib/core/network/` only. A farm client in the app would
  be a new egress path.
- iOS 16+, Android API 26+, arm64-v8a only. ggml results on an emulator or a
  translated ABI do not count.
- The named matrix (4 GB through flagship, Samsung battery management, Mali and
  Adreno, one iPad) is the hardware phase gates run on.

## Options

1. **Physical lab only** — the eight units in `docs/device-matrix.md`. CI stays on
   host scripts (FND-03). On-device `integration_test` runs on those phones
   (`tools/ci/device_suite.sh` when the lab exists).
2. **Firebase Test Lab** — upload an APK/IPA and test assets to Google; Android
   instrumentation and iOS XCTest. No Firebase SDK is required to upload a binary,
   but the binary and any bundled fixtures still leave our machines.
3. **Google Cloud Developer Device Platform** — the replacement Google is pointing
   Test Lab users at. Same upload boundary. Preview, Pre-GA terms.
4. **BrowserStack (or a similar third-party farm)** — upload the binary and test
   assets to that vendor. Useful catalog breadth, another company in the path.

"Do nothing" is option 1: the phase gates already require the physical matrix.

## Criteria (weights fixed before scoring)

| Criterion | Weight |
|---|---|
| Privacy: user content stays on device; no new SDK; smallest upload boundary | 40% |
| Covers the named SoCs, RAM sizes, and Samsung battery behavior | 20% |
| Longevity through a 2027 launch window | 15% |
| Integration effort on top of FND-03 | 15% |
| Cost and who operates it | 10% |

Scores are 1–5. They are judgments from the documents below, not measurements.
There is no app binary to upload and no phone to time.

## Evidence

Checked 2026-10-12.

| Source | What it establishes |
|---|---|
| [Firebase Test Lab](https://firebase.google.com/docs/test-lab) | Hosted Android and iOS devices in a Google data center. Tests run by uploading the app (instrumentation, Robo, XCTest, Game Loop). |
| [Firebase Test Lab deprecation FAQ](https://firebase.google.com/docs/test-lab/migrate-faq) | Test Lab shuts down on **2027-09-30**. Successor is Developer Device Platform. The FAQ text was read from Google's published deprecation notice. |
| [Migrate to Developer Device Platform](https://docs.cloud.google.com/developer-device-platform/device-run/migrate) | `gcloud beta device-run` is Preview / Pre-GA. Android instrumentation and iOS XCTest are in that preview. The binary still runs on Google's devices. |
| `vv-testing` / `vv-benchmark-eval` | Farms, if used, are fixture smoke only. Battery, thermal, and WER numbers come from the physical matrix. |
| `vv-native-build` | Simulator has no Metal performance parity. Android baseline is `armv8-a` on the oldest matrix device. |

No spike under `tools/spikes/`. Building one would mean creating an app (FND-01) and
uploading it. That does not change the privacy or deprecation facts above.

| Criterion | Physical lab | Firebase Test Lab | Developer Device Platform | Third-party farm |
|---|---|---|---|---|
| Privacy (40%) | 5 — binaries and audio stay in the lab | 2 — app and fixtures uploaded; SDK must still be forbidden | 2 — same upload | 2 — same upload, extra vendor |
| Named-hardware coverage (20%) | 4 — we buy the exact roles; weak on "every OS version" | 2 — catalog will not include our 4 GB MediaTek unit or Samsung's battery killer | 2 — preview catalog, same gap | 3 — wide catalog, still not our shelf units' OEM firmware |
| Longevity (15%) | 5 | 1 — shutdown 2027-09-30 | 3 — preview, Pre-GA | 4 — vendor business risk only |
| Integration (15%) | 4 — no new CI vendor; nightly lab job comes later | 3 — gcloud, and a dead end | 2 — new CLI, Cloud billing account | 3 — vendor plugin |
| Cost (10%) | 3 — eight devices, owned | 3 — usage fees until shutdown | 2 — commercial minutes | 2 — subscription |
| **Weighted** | **4.45** | **2.10** | **2.15** | **2.65** |

Weighted sums: physical `0.4*5 + 0.2*4 + 0.15*5 + 0.15*4 + 0.1*3 = 4.45`.
Test Lab `0.4*2 + 0.2*2 + 0.15*1 + 0.15*3 + 0.1*3 = 2.10`.
DDP `0.4*2 + 0.2*2 + 0.15*3 + 0.15*2 + 0.1*2 = 2.15`.
Third-party `0.4*2 + 0.2*3 + 0.15*4 + 0.15*3 + 0.1*2 = 2.65`.

## Decision

**Recommendation: option 1, physical lab only.** Do not open a Firebase Test Lab,
Developer Device Platform, or BrowserStack project for VaultVoice.

Status stays **Proposed** until a person accepts it. The scores were not measured on
a device, and buying the eight units is a spend the team has to approve. Phase-gate
evidence does not wait on that acceptance: it always comes from the physical matrix.

Rejected for now:

- Firebase Test Lab, because Google has dated its shutdown (2027-09-30) and because
  the upload crosses the privacy boundary for little coverage we do not already
  require on our own phones.
- Developer Device Platform, because it is the same upload in a Pre-GA product.
- A third-party farm, because it adds a vendor who receives the binary without
  covering Samsung battery policy or our exact 4 GB unit.

## Consequences

- Positive: smoke, content, battery, and thermal results all come from hardware we
  control. FND-03 does not gain a cloud-farm job or a Google/BrowserStack credential.
- Negative: we will not see the long tail of Android OEM builds. Mitigation: VV-AND-PIX
  (stock Pixel), VV-AND-FLG (Samsung flagship), and VV-AND-4G (budget Samsung or
  other MediaTek) are three OEMs on purpose. OS-version breadth is "current public
  OS" plus the iOS 16 / API 26 floors in code, not a farm matrix.
- The app must not gain a Firebase, Test Lab, or device-farm SDK.
- If this ADR is later rejected, a replacement ADR has to keep these rules: fixture
  or synthetic audio only, no user recordings, no model weights unless the run
  cannot work without a tiny test model, no farm SDK linked into the shipping app,
  and no farm result accepted as a battery, thermal, WER, or call-guard result.
- Follow-up: FND-03 (no farm job), FND-06 (read the dotprod column before a
  `+dotprod`-only build), REL-04 (sign `docs/parity.md` before external beta).
