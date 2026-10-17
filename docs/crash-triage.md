# Crash triage (REL-02)

Lumen has **no crash SDK and no upload endpoint**. Crash data reaches us in two ways:

1. **Baseline — OS / store reports.** Users who opted in at OS level ("Share with App
   Developers" on iOS, "Usage & diagnostics" on Android) produce reports in
   App Store Connect / Xcode Organizer → Crashes and Play Console → Android vitals → Crashes &
   ANRs. Our native handler chains to the OS handler, so these keep working.
   Symbols are not uploaded to Apple/Google by default (REL-01: `uploadSymbols=false`, no
   native debug symbols in Play) — symbolicate store reports locally with the same private
   symbols (below).
2. **User-shared reports.** The app writes a local report when it crashes; on the next launch it
   asks "Lumen closed unexpectedly — review report?", shows the complete file, and only on
   **Share** hands a `.txt` copy to the OS share sheet (email, Files, AirDrop …). Saved
   reports are also listed under Settings → Crash reports. Design: `docs/adr/ADR-REL-02-crash-capture.md`.

## What a report contains (and never contains)
| File (in `<appSupport>/vv/crash/`) | Written by | Contains |
|---|---|---|
| `native-current.vvcrash` | signal handler (`native/bridge/vv_crash.c`), pre-opened each launch; empty = no crash | — |
| `native-<UTC>.vvcrash` | harvested from the live file at next launch | signal, `si_code`, fault address, backtrace (module-relative pc + module basename + build id), module load addresses, app build, OS release, ABI, time |
| `dart-<UTC>.vvdart` | Dart error boundary (`FlutterError.onError`, `PlatformDispatcher.onError`) | error **type**, source, stack trace (obfuscated in release), app build, OS version, time |

Never: error messages, memory contents, file paths, transcripts, prompts, LLM output, audio or
vault names. At most 10 reports are kept; at most 3 Dart reports per session; a shared report is
deleted from the device.

## Where the symbols are
Every tagged release (REL-01, `.github/workflows/release.yml`) uploads **private** workflow
artifacts `symbols-<platform>-<version>-<build>` = `app/build/release-symbols/<platform>/`:

| File | Use |
|---|---|
| `app.android-arm64.symbols` / `app.ios-arm64.symbols` | Dart split debug info → `flutter symbolize -d` |
| `obfuscation_map.json` | Dart identifier map (obfuscated type names in `error_type`) |
| `native/libvv_native.so` (unstripped) | Android native frames → `ndk-stack` / `llvm-symbolizer` |
| `native/dSYMs/*.dSYM` | iOS native frames → `atos` / `symbolicatecrash` |
| `SHA256SUMS` | integrity of binary + symbols |

Match the report to its build with the `app:` line (`<version>+<build> <flavor>`) and the
`BuildId` of each frame (ELF GNU build id / Mach-O LC_UUID). Download the artifact with
`gh run download <run-id> -n symbols-android-1.2.0-345`. Never attach symbols to a public
GitHub Release or upload them to a third-party crash service.

## Symbolicate a native report
One command for both platforms (stdlib Python, picks the right tool per module):
```bash
python3 tools/crash/symbolize.py native-20261013T101500123Z.vvcrash --symbols ./symbols-android-1.2.0-345
```
Each frame gets `-> function (file:line)`. Frames in system libraries stay unresolved unless you
add the device's OS symbols to `--symbols`.

Manual equivalents:
- **Android — `ndk-stack`** (the report uses the tombstone format):
  `$ANDROID_NDK_HOME/ndk-stack -sym ./symbols-android-1.2.0-345/native -i native-….vvcrash`
- **Android/Linux — `llvm-symbolizer`** with the module-relative pc of a frame:
  `$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/*/bin/llvm-symbolizer --obj=libvv_native.so 0x1f40`
- **iOS — `atos`**: absolute address = `load` address of the module (from `modules:`) + frame pc:
  `atos -arch arm64 -o vv_native.framework.dSYM/Contents/Resources/DWARF/vv_native -l 0x102b40000 0x102b41f40`
- **iOS store reports (.ips/.crash)**: Xcode Organizer with the dSYMs on disk, or
  `symbolicatecrash` / `atos` as above.

## Symbolicate a Dart report
Release builds are obfuscated (`--obfuscate --split-debug-info`), so the stack looks like
`#00 abs 000000727d0d9a4b virt 00000000002a9a4b _kDartIsolateSnapshotInstructions+0x1d1a4b`.
```bash
python3 tools/crash/symbolize.py dart-20261013T101500123Z.vvdart \
    --dart-symbols ./symbols-android-1.2.0-345/app.android-arm64.symbols
# equivalent: extract the lines after "stack:" into stack.txt, then
fvm flutter symbolize -i stack.txt -d ./symbols-android-1.2.0-345/app.android-arm64.symbols
```
Use the `.symbols` file for the device's architecture (arm64 for every supported device).
Obfuscated `error_type` names can be looked up in `obfuscation_map.json`.

## Triage
1. Identify build (`app:`), platform (`os:`, `ABI:`), signal / error type.
2. Symbolicate; find the first frame in our code (`libvv_native`, `vaultvoice` packages).
3. Reproduce on the device matrix (`docs/device-matrix.md`); file an issue with the
   symbolicated trace only — never paste a user's raw report into a public tracker.
4. Severity: S1 crash / data loss blocks the release (`vv-ci-release` → Beta).

## Verifying the pipeline
- Host: `native/build.sh host` (ctest `vv_crash`), `python3 -m pytest tools/crash/tests -q`,
  `cd app && fvm flutter test test/unit/crash` (`[REL-02/AC1]` end-to-end).
- Device: `docs/test-plans/device/REL-02.md` (dev flavor → Settings → *Force native crash
  (dev)* → relaunch → share → symbolicate).
