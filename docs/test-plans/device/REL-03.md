# Device / CI verification — REL-03 App Binary Size

Host evidence: `[REL-03/AC1]` in `tools/ci/tests/test_size_check.py`; measurements in
`tools/bench/results/2026-10-14-rel03-size.md`. Store download sizes need signed release builds
(macOS + Xcode, Android SDK) — run in the release workflow (REL-01).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [REL-03/AC1] | Android: `tools/release/build_release.sh android`, then `BUNDLETOOL=<bundletool-all.jar> bash tools/ci/size_check.sh --update-baseline` (first run) / `bash tools/ci/size_check.sh` (later runs). Cross-check Play Console → App bundle explorer → download size for an arm64 phone. | `android_download_mb` ≤ 40; no "model weights" error; Play Console download size within ±10 % of the measured value. | CI release runner + Pixel 7 (Play internal track) | Android 14 | ⏳ | | |
| [REL-03/AC1] | iOS: `tools/release/build_release.sh ios <export-options.plist>` with App Thinning ("thinning" = `iPhone15,2` or "all variants" + `App Thinning Size Report.txt`), then `bash tools/ci/size_check.sh`; cross-check App Store Connect → TestFlight build → App Store file size. | `ios_download_mb` ≤ 40 (thinned, compressed); report lists no model files; ASC download size within ±10 %. | CI release runner + iPhone 13 (TestFlight) | iOS 17/18 | ⏳ | | |
| [REL-03/AC1] | Regression gate in CI: add the step `- run: bash tools/ci/size_check.sh` after the build in the `android` and `ios` jobs of `.github/workflows/release.yml` (and `native-host` in ci.yml for the host library); open a PR that adds a 6 MB dummy asset. | The job fails with `SIZE: … above the baseline … (max 10 %)`. | CI | — | ⏳ | | |

## Notes / evidence
Attach `bundletool get-size total` output and the App Thinning Size Report under
`docs/test-plans/device/evidence/REL-03/`.
