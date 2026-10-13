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


def test_check_apk_native_rejects_missing_lib_and_other_abis(tmp_path):
    r = _check(_apk(tmp_path / "none.apk", ["lib/arm64-v8a/libflutter.so"], n_assets=10))
    assert r.returncode == 1 and "does not contain" in r.stderr
    r = _check(_apk(tmp_path / "x86.apk", ["lib/arm64-v8a/libvv_native.so",
                                           "lib/x86_64/libvv_native.so"]))
    assert r.returncode == 1 and "non-arm64" in r.stderr
