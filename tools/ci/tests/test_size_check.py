"""REL-03: app size gate (tools/ci/size_check.py, size-budget.json)."""
import json
import os
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "size_check.py"
MB = 1024 * 1024


def _budget(tmp_path, baseline=None, cap=40):
    b = {"max_regression_pct": 10, "max_bundled_model_mb": 5,
         "budgets": {"android_download_mb": cap, "ios_download_mb": cap},
         "baseline": baseline or {}}
    p = tmp_path / "budget.json"
    p.write_text(json.dumps(b))
    return p


def _aab(tmp_path, mb, extra=None):
    p = tmp_path / f"app-{mb}.aab"
    with zipfile.ZipFile(p, "w", zipfile.ZIP_STORED) as z:
        z.writestr("base/lib/arm64-v8a/libapp.so", os.urandom(int(mb * MB)))
        for name, size in (extra or {}).items():
            z.writestr(name, os.urandom(size))
    return p


def _run(tmp_path, *args):
    env = {**os.environ, "PATH": "/usr/bin:/bin"}  # no bundletool: file size
    empty = tmp_path / "assets"
    empty.mkdir(exist_ok=True)
    return subprocess.run([sys.executable, str(SCRIPT), "--assets", str(empty), *args],
                          capture_output=True, text=True, env=env)


def test_REL_03_AC1_ci_fails_on_more_than_10_percent_regression(tmp_path):
    """[REL-03/AC1] growth > 10 % over the baseline fails; ≤ 10 % passes."""
    budget = _budget(tmp_path, baseline={"android_download_mb": 10.0})
    ok = _run(tmp_path, "--budget", str(budget), "--android-aab", str(_aab(tmp_path, 10.9)))
    assert ok.returncode == 0, ok.stderr
    bad = _run(tmp_path, "--budget", str(budget), "--android-aab", str(_aab(tmp_path, 11.2)))
    assert bad.returncode == 1
    assert "above the baseline" in bad.stderr


def test_REL_03_AC1_absolute_budget_and_baseline_update(tmp_path):
    """[REL-03/AC1] over the 40 MB-style budget fails; --update-baseline records."""
    budget = _budget(tmp_path, cap=5)
    r = _run(tmp_path, "--budget", str(budget), "--ios-ipa", str(_aab(tmp_path, 6)))
    assert r.returncode == 1 and "exceeds the budget" in r.stderr
    budget = _budget(tmp_path)
    r = _run(tmp_path, "--budget", str(budget), "--android-aab", str(_aab(tmp_path, 3)),
             "--update-baseline")
    assert r.returncode == 0, r.stderr
    assert json.loads(budget.read_text())["baseline"]["android_download_mb"] == 3.0


def test_REL_03_AC1_model_weights_in_the_binary_fail(tmp_path):
    """[REL-03/AC1] no model weights ship in the binary (only a small VAD model)."""
    budget = _budget(tmp_path)
    for name in ("base/assets/flutter_assets/models/ggml-tiny.en.bin",
                 "base/assets/llm.gguf", "base/assets/enc.mlmodelc/weights/weight.bin"):
        r = _run(tmp_path, "--budget", str(budget),
                 "--android-aab", str(_aab(tmp_path, 1, {name: 1024})))
        assert r.returncode == 1 and "model weights" in r.stderr, name
    vad = _aab(tmp_path, 1, {"base/assets/ggml-silero-v6.2.0.bin": 900 * 1024})
    assert _run(tmp_path, "--budget", str(budget), "--android-aab", str(vad)).returncode == 0
    big_vad = _aab(tmp_path, 1, {"base/assets/ggml-silero-big.bin": 6 * MB})
    assert _run(tmp_path, "--budget", str(budget), "--android-aab", str(big_vad)).returncode == 1


def test_REL_03_AC1_repository_ships_no_models_and_has_a_budget():
    """[REL-03/AC1] app/assets holds no model weights; the budget file is sane."""
    r = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    b = json.loads((ROOT / "tools" / "ci" / "size-budget.json").read_text())
    assert b["max_regression_pct"] == 10
    assert b["budgets"]["android_download_mb"] <= 40
    assert b["budgets"]["ios_download_mb"] <= 40


def test_REL_03_build_settings_shrink_and_strip():
    """Android arm64-only + R8 + resource shrinking; iOS dead-code stripping +
    strip; native framework stripped with a private dSYM."""
    gradle = (ROOT / "app/android/app/build.gradle.kts").read_text()
    assert 'abiFilters += "arm64-v8a"' in gradle and "abiFilters.clear()" in gradle
    assert "isMinifyEnabled = true" in gradle and "isShrinkResources = true" in gradle
    assert "keepDebugSymbols +=" not in gradle and "keepDebugSymbols.add" not in gradle
    pbx = (ROOT / "app/ios/Runner.xcodeproj/project.pbxproj").read_text()
    assert pbx.count("DEAD_CODE_STRIPPING = YES;") == 4
    assert pbx.count("STRIP_INSTALLED_PRODUCT = YES;") == 4
    assert "ENABLE_BITCODE = YES" not in pbx
    build = (ROOT / "native/build.sh").read_text()
    for attr in ("DEPLOYMENT_POSTPROCESSING=YES", "STRIP_STYLE=non-global",
                 "DEBUG_INFORMATION_FORMAT=dwarf-with-dsym", "llvm-strip"):
        assert attr in build, attr
