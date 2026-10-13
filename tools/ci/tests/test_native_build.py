"""Tests for the native build entry point and pins (FND-06)."""
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
BUILD = ROOT / "native" / "build.sh"


def run(args, env=None):
    e = {**os.environ, **(env or {})}
    return subprocess.run(["bash", str(BUILD), *args], capture_output=True, text=True, env=e)


def _have_xcode():
    return subprocess.run(["xcodebuild", "-version"], capture_output=True).returncode == 0 \
        if shutil.which("xcodebuild") else False


def test_FND_06_AC1_one_command_per_target_and_clear_toolchain_errors(tmp_path):
    """[FND-06/AC1] build.sh offers host/android/ios and fails clearly without a toolchain."""
    r = run(["bogus"])
    assert r.returncode == 64 and "host|android|ios|all" in r.stderr

    empty_sdk = {"ANDROID_HOME": str(tmp_path), "ANDROID_SDK_ROOT": str(tmp_path),
                 "ANDROID_NDK_HOME": "", "ANDROID_NDK_ROOT": ""}
    r = run(["android"], env=empty_sdk)
    assert r.returncode == 2 and "NDK r28+" in r.stderr

    if not _have_xcode():
        r = run(["ios"])
        assert r.returncode == 2 and "Xcode" in r.stderr


def test_FND_06_AC1_submodule_pins_match_versions_doc():
    """[FND-06/AC1] native/VERSIONS.md documents the exact pinned submodule commits."""
    versions = (ROOT / "native" / "VERSIONS.md").read_text()
    out = subprocess.run(["git", "ls-files", "-s", "native/whisper.cpp", "native/llama.cpp"],
                         cwd=ROOT, capture_output=True, text=True, check=True).stdout
    pins = re.findall(r"160000 ([0-9a-f]{40}) 0\t(native/[\w.]+)", out)
    assert {p for _, p in pins} == {"native/whisper.cpp", "native/llama.cpp"}
    for sha, path in pins:
        assert sha in versions, f"{path} pin {sha} missing from native/VERSIONS.md"
    gm = (ROOT / ".gitmodules").read_text()
    assert "ggml-org/whisper.cpp" in gm and "ggml-org/llama.cpp" in gm


@pytest.mark.skipif(not (ROOT / "native/llama.cpp/ggml").exists()
                    or not (ROOT / "native/whisper.cpp/ggml").exists(),
                    reason="submodules not checked out")
def test_FND_06_AC1_single_shared_ggml_trees_match():
    """[FND-06/AC1] both pins carry the same ggml tree (single shared ggml is safe)."""
    r = subprocess.run(["diff", "-rq", "native/llama.cpp/ggml", "native/whisper.cpp/ggml"],
                       cwd=ROOT, capture_output=True, text=True)
    differing = [l for l in r.stdout.splitlines() if l.strip()]
    assert all(l.endswith(".gitignore differ") for l in differing), differing
