"""SEC-08: threat model doc, fuzz harness and dependency scan wiring."""
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT / "docs" / "threat-model.md"


def task_ids():
    return {p.name.split("-")[0] + "-" + p.name.split("-")[1]
            for p in (ROOT / "tasks").glob("*/*.md") if p.name != "README.md"}


def table_rows(section):
    text = DOC.read_text()
    body = text.split(f"## {section}", 1)[1].split("\n## ", 1)[0]
    return [[c.strip() for c in line.strip().strip("|").split("|")]
            for line in body.splitlines()
            if line.startswith("|") and not re.match(r"\|[-| ]+\|$", line)][1:]


def test_SEC_08_AC1_every_threat_maps_to_existing_tasks():
    """[SEC-08/AC1] Each STRIDE row lists mitigations mapped to real tasks."""
    ids = task_ids()
    rows = table_rows("STRIDE analysis")
    assert len(rows) >= 12
    required = ["model", "manifest", "profile", "injection", "covert",
                "call", "stolen", "audio", "licence"]
    text = " ".join(r[1].lower() for r in rows)
    for word in required:
        assert word in text, f"threat missing: {word}"
    for row in rows:
        refs = set(re.findall(r"\b[A-Z]{3}-\d\d\b", row[5]))
        assert refs, f"{row[0]} has no mapped task"
        assert refs <= ids, f"{row[0]} references unknown tasks {refs - ids}"


def test_SEC_08_AC1_no_open_high_or_critical_findings():
    """[SEC-08/AC1] The findings register has no High/Critical that is open."""
    for fid, sev, _text, status, _owner in table_rows("Findings"):
        if sev.lower() in {"high", "critical"}:
            assert not status.lower().startswith("open"), fid


def test_SEC_08_AC1_sec09_bypass_vectors_are_reviewed():
    """[SEC-08/AC1] Settings, MDM, intents, deep links and widgets are covered."""
    vectors = " ".join(r[0].lower() for r in table_rows("SEC-09 bypass review"))
    for v in ("settings", "mdm", "intents", "deep links", "widgets"):
        assert v in vectors


def test_SEC_08_AC1_fuzz_targets_and_seeds_exist():
    """[SEC-08/AC1] WAV and GGUF fuzz targets with seed corpora."""
    for f in ("fuzz_wav.cpp", "fuzz_gguf.cpp", "fuzz_driver.cpp", "build_fuzz.sh"):
        assert (ROOT / "native" / "fuzz" / f).exists()
    assert list((ROOT / "native" / "fuzz" / "corpus" / "wav").glob("*.wav"))
    assert list((ROOT / "native" / "fuzz" / "corpus" / "gguf").glob("*.gguf"))


@pytest.mark.skipif(shutil.which("c++") is None, reason="needs a C++ compiler")
def test_SEC_08_AC1_wav_parser_survives_mutated_inputs(tmp_path):
    """[SEC-08/AC1] ASan/UBSan mutation run of the WAV parser finds no crash."""
    fuzz = ROOT / "native" / "fuzz"
    exe = tmp_path / "fuzz_wav"
    build = subprocess.run(
        ["c++", "-std=c++17", "-O1", "-g", "-fsanitize=address,undefined",
         str(fuzz / "fuzz_wav.cpp"), str(fuzz / "fuzz_driver.cpp"), "-o", str(exe)],
        capture_output=True, text=True)
    if build.returncode != 0 and "sanitize" in build.stderr:
        pytest.skip("sanitizers unavailable")
    assert build.returncode == 0, build.stderr
    run = subprocess.run([str(exe), str(fuzz / "corpus" / "wav"), "--rounds", "100"],
                         capture_output=True, text=True,
                         env={"UBSAN_OPTIONS": "halt_on_error=1"})
    assert run.returncode == 0, run.stdout + run.stderr
    assert "no crash" in run.stdout


def test_SEC_08_AC1_osv_scan_is_wired_into_ci():
    """[SEC-08/AC1] Workflow and script scan pub lockfiles and submodules."""
    wf = (ROOT / ".github" / "workflows" / "osv.yml").read_text()
    assert "tools/ci/osv_scan.sh" in wf and "schedule:" in wf
    assert "sha256sum -c" in wf
    script = (ROOT / "tools" / "ci" / "osv_scan.sh").read_text()
    assert "osv-scanner scan source" in script and "--config osv-scanner.toml" in script
    assert (ROOT / "osv-scanner.toml").exists()
    r = subprocess.run(["bash", str(ROOT / "tools/ci/osv_scan.sh"), "--offline-check"],
                       capture_output=True, text=True)
    assert r.returncode in (0, 2)  # 2 = scanner not installed locally
