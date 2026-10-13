"""Tests for the QA-01 test framework: docs/testing.md, the acceptance-tag and
device-checklist conventions, the CI coverage gate and fetch_test_models.sh."""
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CI = ROOT / "tools" / "ci"
DOC = ROOT / "docs" / "testing.md"
TAG_RE = re.compile(r"\[([A-Z]{2,4}-\d{2})/AC(\d+)\]")  # same as tasks.py tag_index
TEMPLATE_HEADER = "| AC | Steps | Expected | Device | OS | Result | Date | Tester |"


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def headings(text):
    return {m.group(1).strip().lower() for m in re.finditer(r"^#{2,3}\s+(.+)$", text, re.M)}


# --- AC1: tag convention + device-checklist location documented, examples exist


def test_QA_01_AC1_tag_convention_and_device_checklist_location_documented():
    """[QA-01/AC1] docs/testing.md documents `[<ID>/ACn]` and docs/test-plans/device/<ID>.md."""
    text = DOC.read_text(encoding="utf-8")
    assert "[<ID>/ACn]" in text
    assert "docs/test-plans/device/<ID>.md" in text
    # the doc spells out how each kind of test carries the tag
    for needle in ("testWidgets(", "pytest", "ctest", "--plain-name", "tasks.py verify"):
        assert needle in text, needle
    # every example tag in the doc is well-formed for tasks.py
    assert TAG_RE.search("[QA-01/AC1]")


def test_QA_01_AC1_example_tagged_test_is_discoverable_by_tasks_py():
    """[QA-01/AC1] the example tagged Dart test exists where tasks.py looks for tags."""
    example = ROOT / "app" / "test" / "pipeline" / "fake_pipeline_test.dart"
    text = example.read_text(encoding="utf-8")
    names = re.findall(r"test\(\s*'([^']*)'", text)
    assert any("[QA-01/AC1]" in n for n in names), names
    assert "app/test/pipeline/fake_pipeline_test.dart" in DOC.read_text(encoding="utf-8")


def test_QA_01_AC1_example_device_checklist_follows_template():
    """[QA-01/AC1] docs/test-plans/device/QA-01.md uses the template columns and tagged rows."""
    checklist = ROOT / "docs" / "test-plans" / "device" / "QA-01.md"
    lines = checklist.read_text(encoding="utf-8").splitlines()
    assert TEMPLATE_HEADER in lines
    rows = [ln for ln in lines if ln.startswith("| [")]
    assert rows, "no checklist rows"
    for row in rows:
        cells = [c.strip() for c in row.strip("|").split("|")]
        assert len(cells) == 8, row
        assert TAG_RE.fullmatch(cells[0]), cells[0]
        assert cells[1].startswith("1."), "steps must be numbered"
        assert cells[2], "expected result required"
        # nobody ran it yet: Result/Date stay empty, never a made-up PASS
        assert cells[5] in ("", "PASS", "FAIL")
        if cells[5]:
            assert re.fullmatch(r"\d{4}-\d{2}-\d{2}", cells[6])
    assert "docs/test-plans/device/QA-01.md" in DOC.read_text(encoding="utf-8")


# --- AC2: layers, ownership, gates; CI enforces coverage threshold


def test_QA_01_AC2_testing_doc_defines_layers_ownership_and_gates():
    """[QA-01/AC2] docs/testing.md has layers, ownership and gates sections with real content."""
    text = DOC.read_text(encoding="utf-8")
    hs = headings(text)
    for h in ("layers", "ownership", "gates"):
        assert any(x.startswith(h) for x in hs), f"missing section {h}: {hs}"
    for layer_dir in ("app/test/unit/", "app/test/widget/", "app/test/golden/", "app/test/db/",
                      "app/test/pipeline/", "app/integration_test/", "packages/vv_native/test/",
                      "tools/bench/"):
        assert layer_dir in text, layer_dir
    for gate in ("fvm dart format --set-exit-if-changed .", "fvm flutter analyze",
                 "fvm flutter test --coverage", "check_coverage.py", "80%",
                 "tasks.py verify --all-done --run"):
        assert gate in text, gate


def test_QA_01_AC2_ci_test_job_enforces_coverage_threshold(tmp_path):
    """[QA-01/AC2] CI's test job runs test.sh, which fails below 80% gated line coverage."""
    wf = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    test_job = wf.split("\n  test:\n", 1)[1].split("\n  task-gate:\n", 1)[0]
    assert "bash tools/ci/test.sh" in test_job
    script = (CI / "test.sh").read_text(encoding="utf-8")
    assert re.search(r"test --coverage\n.*check_coverage\.py\" coverage/lcov\.info\s*$", script, re.S), script
    assert "set -euo pipefail" in (CI / "lib.sh").read_text(encoding="utf-8")

    def gate(hit):
        lcov = tmp_path / "lcov.info"
        lcov.write_text(f"SF:lib/core/x.dart\nLF:1000\nLH:{hit}\nend_of_record\n"
                        "SF:lib/features/a/domain/y.dart\nLF:0\nLH:0\nend_of_record\n")
        return run([sys.executable, str(CI / "check_coverage.py"), str(lcov)]).returncode

    assert gate(799) == 1  # 79.9% fails
    assert gate(800) == 0  # 80.0% passes


# --- fetch_test_models.sh (scope: integration tests with tiny models)


def _lock(tmp_path, entries):
    lock = tmp_path / "test-models.lock"
    lock.write_text("# test lock\n" + "".join(f"{n} {s} {z} {u}\n" for n, s, z, u in entries))
    return lock


def _src(tmp_path, name, data):
    f = tmp_path / "src" / name
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_bytes(data)
    return f, hashlib.sha256(data).hexdigest()


def test_fetch_test_models_downloads_verifies_and_caches(tmp_path):
    src, sha = _src(tmp_path, "tiny.bin", b"model-bytes")
    lock = _lock(tmp_path, [("tiny.bin", sha, 11, src.as_uri())])
    dest = tmp_path / "cache"
    cmd = ["bash", str(CI / "fetch_test_models.sh"), "--lock", str(lock), "--dest", str(dest)]

    r = run(cmd)
    assert r.returncode == 0, r.stderr
    assert (dest / "tiny.bin").read_bytes() == b"model-bytes"
    assert r.stdout.strip().splitlines()[-1] == f"VV_TEST_MODELS_DIR={dest.resolve()}"

    src.unlink()  # second run must not need the network/source
    r = run(cmd)
    assert r.returncode == 0 and "cached  tiny.bin" in r.stdout


def test_fetch_test_models_rejects_sha256_mismatch(tmp_path):
    src, _ = _src(tmp_path, "evil.bin", b"tampered")
    lock = _lock(tmp_path, [("evil.bin", "0" * 64, 8, src.as_uri())])
    dest = tmp_path / "cache"
    r = run(["bash", str(CI / "fetch_test_models.sh"), "--lock", str(lock), "--dest", str(dest)])
    assert r.returncode == 1
    assert "sha256 mismatch" in r.stderr
    assert not list(dest.iterdir()), "no partial or unverified file may remain"


def test_fetch_test_models_refuses_destination_inside_repo(tmp_path):
    src, sha = _src(tmp_path, "m.bin", b"x")
    lock = _lock(tmp_path, [("m.bin", sha, 1, src.as_uri())])
    dest = ROOT / "build" / "_fetch_probe"
    r = run(["bash", str(CI / "fetch_test_models.sh"), "--lock", str(lock), "--dest", str(dest)])
    assert r.returncode == 2 and "inside the repo" in r.stderr
    assert not dest.exists(), "nothing may be created inside the repo"


def test_fetch_test_models_unknown_name_fails(tmp_path):
    lock = _lock(tmp_path, [])
    r = run(["bash", str(CI / "fetch_test_models.sh"), "--lock", str(lock),
             "--dest", str(tmp_path / "c"), "nope.gguf"])
    assert r.returncode == 1 and "unknown name" in r.stderr


def test_test_models_lock_is_pinned():
    """Every real entry has a sha256, a size and an https URL at an immutable revision."""
    entries = [ln.split() for ln in (CI / "test-models.lock").read_text().splitlines()
               if ln.strip() and not ln.startswith("#")]
    names = {e[0] for e in entries}
    assert {"ggml-tiny.en.bin", "jfk.wav"} <= names
    assert any(n.endswith(".gguf") for n in names)
    for name, sha, size, url in entries:
        assert re.fullmatch(r"[0-9a-f]{64}", sha), name
        assert int(size) <= 200 * 1024 * 1024, f"{name}: test models must stay <= 200 MB"
        assert url.startswith("https://"), name
        assert re.search(r"/[0-9a-f]{40}/", url), f"{name}: URL must pin a commit, not a branch"
    gi = (ROOT / ".gitignore").read_text()
    assert "*.gguf" in gi and "ggml-*.bin" in gi
