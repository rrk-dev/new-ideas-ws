#!/usr/bin/env python3
"""REL-03 app size gate.

Compares measured sizes with tools/ci/size-budget.json:
  * fails when a measurement exceeds its absolute budget;
  * fails when it grew by more than `max_regression_pct` (10 %) over its
    recorded baseline;
  * fails when an artifact (or app/assets) contains model weights — models are
    delivered post-install (MDL-01/02); only a VAD model up to
    `max_bundled_model_mb` may ship.

Measurements (any subset; missing ones are reported as "not measured"):
  --android-aab FILE   download size via `bundletool get-size total` for the
                       arm64-v8a device spec when bundletool is on PATH (or
                       $BUNDLETOOL jar), else the compressed AAB size (upper
                       bound); also scanned for model files
  --android-apk FILE   per-ABI release APK: file size (download ≈ APK size)
  --ios-ipa FILE       thinned IPA (App Store Connect / `-exportArchive` with
                       thinning): compressed size; scanned for model files
  --ios-app DIR        unpacked .app: install size (sum of files)
  --host-lib FILE      host bridge library (stripped copy measured; keyed by host OS)
  --update-baseline    write the measurements as the new baseline
  --json               print measurements as JSON
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUDGET = ROOT / "tools" / "ci" / "size-budget.json"
MODEL_SUFFIXES = (".gguf", ".ggml", ".onnx", ".tflite", ".mlmodel", ".pte", ".safetensors")
MB = 1024 * 1024


def is_model(name: str) -> bool:
    n = name.lower()
    base = n.rsplit("/", 1)[-1]
    return (n.endswith(MODEL_SUFFIXES) or ".mlmodelc/" in n or n.endswith(".mlmodelc")
            or (base.startswith("ggml-") and base.endswith(".bin")))


def scan_zip(path: Path) -> list[tuple[str, int]]:
    with zipfile.ZipFile(path) as z:
        return [(i.filename, i.file_size) for i in z.infolist() if is_model(i.filename)]


def scan_dir(path: Path) -> list[tuple[str, int]]:
    out = []
    if path.is_dir():
        for f in path.rglob("*"):
            rel = f.relative_to(path).as_posix()
            if f.is_file() and is_model(rel):
                out.append((rel, f.stat().st_size))
    return out


def bundletool_size(aab: Path) -> int | None:
    jar = os.environ.get("BUNDLETOOL")
    cmd = (["java", "-jar", jar] if jar else ["bundletool"]) if (jar or shutil.which("bundletool")) else None
    if cmd is None:
        return None
    with tempfile.TemporaryDirectory() as tmp:
        spec = Path(tmp) / "device.json"
        spec.write_text(json.dumps({"supportedAbis": ["arm64-v8a"], "supportedLocales": ["en"],
                                    "screenDensity": 440, "sdkVersion": 34}))
        apks = Path(tmp) / "app.apks"
        subprocess.run(cmd + ["build-apks", f"--bundle={aab}", f"--output={apks}",
                              f"--device-spec={spec}"], check=True, capture_output=True)
        out = subprocess.run(cmd + ["get-size", "total", f"--apks={apks}"], check=True,
                             capture_output=True, text=True).stdout
    # CSV: MIN,MAX
    return int(out.strip().splitlines()[-1].split(",")[-1])


def stripped_size(lib: Path) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        copy = Path(tmp) / lib.name
        shutil.copy2(lib, copy)
        strip = shutil.which("llvm-strip") or shutil.which("strip")
        if strip:
            flag = "-x" if sys.platform == "darwin" and strip.endswith("/strip") else "--strip-unneeded"
            subprocess.run([strip, flag, str(copy)], check=True, capture_output=True)
        return copy.stat().st_size


def measure(a) -> tuple[dict, list[tuple[str, int]]]:
    m, models = {}, []
    if a.android_aab:
        size = bundletool_size(a.android_aab)
        m["android_download_mb"] = round((size or a.android_aab.stat().st_size) / MB, 2)
        if size is None:
            m["android_download_note"] = "AAB file size (bundletool not available: upper bound)"
        models += [(f"{a.android_aab.name}:{n}", z) for n, z in scan_zip(a.android_aab)]
    if a.android_apk:
        m["android_download_mb"] = round(a.android_apk.stat().st_size / MB, 2)
        models += [(f"{a.android_apk.name}:{n}", z) for n, z in scan_zip(a.android_apk)]
    if a.ios_ipa:
        m["ios_download_mb"] = round(a.ios_ipa.stat().st_size / MB, 2)
        models += [(f"{a.ios_ipa.name}:{n}", z) for n, z in scan_zip(a.ios_ipa)]
    if a.ios_app:
        m["ios_install_mb"] = round(sum(f.stat().st_size for f in a.ios_app.rglob("*")
                                        if f.is_file()) / MB, 2)
        models += [(f"{a.ios_app.name}/{n}", z) for n, z in scan_dir(a.ios_app)]
    if a.host_lib:
        # Per host OS: a macOS dylib (Metal embedded) and a Linux .so differ.
        os_name = "darwin" if sys.platform == "darwin" else "linux"
        m[f"host_native_lib_{os_name}_mb"] = round(stripped_size(a.host_lib) / MB, 2)
    return m, models


def check(measured: dict, models: list[tuple[str, int]], budget: dict) -> list[str]:
    errors = []
    limit = budget["max_bundled_model_mb"]
    for name, size in models:
        # Only the optional tiny VAD model may ship in the binary.
        if "silero" not in name.lower() or size > limit * MB:
            errors.append(f"model weights in the app binary: {name} ({size / MB:.1f} MB)")
    pct = budget["max_regression_pct"]
    for key, value in measured.items():
        if not key.endswith("_mb"):
            continue
        cap = budget["budgets"].get(key)
        if cap is not None and value > cap:
            errors.append(f"{key} {value} MB exceeds the budget {cap} MB")
        base = budget.get("baseline", {}).get(key)
        if base:
            growth = (value - base) / base * 100
            if growth > pct:
                errors.append(f"{key} {value} MB is {growth:.1f} % above the baseline {base} MB "
                              f"(max {pct} %)")
    return errors


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    for opt in ("--android-aab", "--android-apk", "--ios-ipa", "--ios-app", "--host-lib"):
        ap.add_argument(opt, type=Path)
    ap.add_argument("--budget", type=Path, default=BUDGET)
    ap.add_argument("--assets", type=Path, default=ROOT / "app" / "assets")
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    budget = json.loads(a.budget.read_text())
    measured, artifact_models = measure(a)
    asset_models = scan_dir(a.assets)
    errors = check(measured, [*asset_models, *artifact_models], budget)
    if a.json:
        print(json.dumps(measured, indent=2))
    for key in budget["budgets"]:
        shown = measured.get(key, "not measured")
        print(f"{key}: {shown} (budget {budget['budgets'][key]}, baseline "
              f"{budget.get('baseline', {}).get(key)})")
    if a.update_baseline and not errors:
        budget.setdefault("baseline", {}).update(
            {k: v for k, v in measured.items() if k.endswith("_mb")})
        a.budget.write_text(json.dumps(budget, indent=2) + "\n")
        print(f"baseline updated in {a.budget}")
    for e in errors:
        print(f"SIZE: {e}", file=sys.stderr)
    if errors:
        print("size_check: FAILED", file=sys.stderr)
        return 1
    print("size_check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
