"""Tests for the Android CI job scripts (check_apk_native.sh)."""
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CHECK = ROOT / "tools" / "ci" / "check_apk_native.sh"


def _apk(path: Path, libs, n_assets=0):
    with zipfile.ZipFile(path, "w") as z:
        for lib in libs:
            z.writestr(lib, b"\x7fELF")
        # A real debug APK lists thousands of entries (> 64 KiB of `unzip -l`).
        for i in range(n_assets):
            z.writestr(f"assets/flutter_assets/packages/some_plugin/assets/file_{i:05d}.bin", b"")
    return path


def _check(apk):
    return subprocess.run(["bash", str(CHECK), str(apk)], capture_output=True, text=True)


def test_check_apk_native_accepts_large_arm64_apk(tmp_path):
    """A big APK whose libvv_native.so is listed first must pass (no SIGPIPE under pipefail)."""
    apk = _apk(tmp_path / "big.apk", ["lib/arm64-v8a/libvv_native.so"], n_assets=4000)
    r = _check(apk)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "lib/arm64-v8a/libvv_native.so" in r.stdout


def test_app_gradle_enables_resvalues_when_flavors_use_them():
    """AGP 9 disables resValues by default; flavors using resValue(...) then fail
    configuration ("contains custom resource values, but the feature is disabled")."""
    import re
    gradle = (ROOT / "app" / "android" / "app" / "build.gradle.kts").read_text()
    if "resValue(" in gradle:
        assert re.search(r"buildFeatures\s*\{[^}]*\bresValues\s*=\s*true", gradle), \
            "app/android/app/build.gradle.kts uses resValue(...) without buildFeatures { resValues = true }"


def test_check_apk_native_rejects_missing_lib_and_other_abis(tmp_path):
    r = _check(_apk(tmp_path / "none.apk", ["lib/arm64-v8a/libflutter.so"], n_assets=10))
    assert r.returncode == 1 and "does not contain" in r.stderr
    r = _check(_apk(tmp_path / "x86.apk", ["lib/arm64-v8a/libvv_native.so",
                                           "lib/x86_64/libvv_native.so"]))
    assert r.returncode == 1 and "non-arm64" in r.stderr
    assert "lib/x86_64/libvv_native.so" in r.stderr, "the offending entries are listed"


def test_app_gradle_replaces_flutter_default_abi_filters():
    """The Flutter Gradle plugin pre-fills ndk.abiFilters with armeabi-v7a,
    arm64-v8a and x86_64 before the app's android {} block runs, so
    `abiFilters += ...` keeps every ABI (main run 38582822564: "contains
    non-arm64 native libs"). The app must clear the set first."""
    import re
    gradle = (ROOT / "app" / "android" / "app" / "build.gradle.kts").read_text()
    ndk = re.search(r"ndk\s*\{(.*?)\n\s*\}", gradle, re.S)
    assert ndk, "app/android/app/build.gradle.kts has no ndk { } block"
    body = "\n".join(l.split("//")[0] for l in ndk.group(1).splitlines())
    assert re.search(r"abiFilters\.clear\(\)", body), "ndk { } must call abiFilters.clear()"
    assert body.index("abiFilters.clear()") < body.index('"arm64-v8a"')
    assert not re.search(r"armeabi|x86", body)
