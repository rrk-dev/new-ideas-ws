# Device verification — SEC-02 Network Egress Guarantee

Host evidence: `[SEC-02/AC1]` (`app/test/unit/network/egress_capture_test.dart`,
`tools/ci/tests/test_egress_guard.py`, `tools/ci/tests/test_package_audit.py`); audit in
`docs/privacy-audit.md` → "Egress guarantee". These rows repeat the capture on real devices.

Setup: mitmproxy 11 (`mitmweb --set flow_detail=0 -w flows.mitm`) on a laptop; phone Wi-Fi proxy
→ laptop:8080; install the mitmproxy CA (Android: user CA — trusted by **debug** builds only via
`debug-overrides`; iOS: install profile + Settings → General → About → Certificate Trust).
Use the dev debug build. Export hosts with
`mitmdump -nr flows.mitm --set flow_detail=1 | grep -oE 'https://[^/ ]+' | sort -u`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [SEC-02/AC1] | Android: 1. Fresh install, start capture. 2. Onboarding → download the default STT + LLM models. 3. Record 2 min with speech, let it process to a vault note. 4. Open Settings, Library, Profiles. 5. Stop capture, export hosts. | Hosts ⊆ {`models.vaultvoice.example` (or the provisioned CDN), `huggingface.co`, `us.aws.cdn.hf.co`} plus OS traffic not from our UID (verify per-UID with `adb shell dumpsys netstats detail` or PCAPdroid filtered on the app). No request during steps 3–4. Settings → Network activity lists exactly the captured app requests. | Pixel 7 | Android 14 | ⏳ | | |
| [SEC-02/AC1] | iOS: same steps; also leave the app backgrounded 10 min during a model download. | Same host set (background `URLSession` traffic included); nothing else from the app. | iPhone 13 | iOS 17/18 | ⏳ | | |
| [SEC-02/AC1] | Offline mode: Settings → Privacy → Offline mode **on**; repeat steps 3–4 and try to start a model download. | Zero requests from the app in the capture; the download is refused with the offline message; Network activity shows "Blocked before sending" rows only. | Pixel 7 + iPhone 13 | Android 14 / iOS 17/18 | ⏳ | | |
| [SEC-02/AC1] | Release build (signed, REL-01) with the mitmproxy **user** CA installed on Android. | TLS to our hosts fails (release builds do not trust user CAs) — confirms `debug-overrides` never apply to release. | Pixel 7 | Android 14 | ⏳ | | |

## Notes / evidence
Save `flows.mitm` exports (hosts only) under `docs/test-plans/device/evidence/SEC-02/`.
