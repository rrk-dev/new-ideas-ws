# Device verification — REL-02 Privacy-Preserving Crash Reporting

Host coverage (`[REL-02/AC1]`): the real handler crashes a process, the report is harvested,
shared and symbolicated (`app/test/unit/crash/native_crash_e2e_test.dart`,
`tools/crash/tests/test_crash_symbolize.py`, ctest `vv_crash`). These rows confirm the same on
devices, which could not be run when this was authored (no Xcode / Android SDK / devices).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [REL-02/AC1] | 1. Build + install the dev flavor (`cd app && fvm flutter run --flavor dev -t lib/main_dev.dart`, then stop the debugger: run from the home screen, not attached). 2. Settings → *Force native crash (dev)* → Crash. 3. Relaunch the app. 4. In the prompt tap *Review report*, check the preview, tap *Share* → Mail / Save to Files / AirDrop to a Mac. 5. On the Mac: `python3 tools/crash/symbolize.py <shared .txt> --symbols <dir with vv_native.framework.dSYM (dsymutil on the built framework)>`. | App dies (not frozen). Prompt appears once on relaunch; preview shows `signal 11 (SIGSEGV)`, frames with `vv_native`/`BuildId`, no file paths or user content. Nothing is sent before a share target is chosen. Step 5 prints `vv_crash_force_segv (vv_crash.c:<line>)` for frame #00. Xcode Organizer / device *Analytics Data* also shows a system crash report (chaining works). | iPhone (oldest + newest in matrix) | iOS 16+ | | | |
| [REL-02/AC1] | Same steps on Android; step 5 with the unstripped `libvv_native.so` from `app/build/app/intermediates/merged_native_libs/devDebug/**/arm64-v8a/` (or the release `symbols-android-*` artifact): `python3 tools/crash/symbolize.py <file> --symbols <dir>` and `ndk-stack -sym <dir> -i <file>`. Also run `adb logcat -b crash` after step 2. | Same report checks; both tools resolve frame #00 to `vv_crash_force_segv (vv_crash.c:<line>)`. `logcat -b crash` shows the normal debuggerd tombstone (chaining to debuggerd works). | arm64 Android phone (oldest + newest) | API 26+ | | | |
| [REL-02/AC1] | ART coexistence: on Android with the dev build, use the app normally for 5 min (switch tabs, record + stop, import, open Settings), then relaunch. | No crash prompt and no `native-*.vvcrash` in `adb shell run-as com.vaultvoice.vaultvoice.dev ls files/vv/crash` (ART's internal SIGSEGV null checks are claimed by libsigchain first, never reported as crashes). | arm64 Android phone | API 26+ | | | |
| [REL-02/AC1] | Dart error: dev build → Settings → *Throw uncaught Dart error (dev)* → relaunch. Then repeat with an obfuscated release build (`tools/release/build_release.sh`) and a temporary trigger, and run `python3 tools/crash/symbolize.py <dart .txt> --dart-symbols app.<platform>-arm64.symbols`. | Prompt "hit an unexpected error"; report has `error_type: StateError`, a stack, no message text (`dev crash test` must NOT appear). Release stack symbolizes to Dart file:line. | any | any | | | |

## Notes / evidence
Attach shared reports and symbolized output under `docs/test-plans/device/evidence/REL-02/`.
