"""FND-01 code standards: the format and analyze gates really run and fail closed.

The tests copy the working tree (tracked + untracked, not ignored) of the Dart
packages and the CI scripts into a temporary mirror, run the real
`tools/ci/format.sh` / `tools/ci/analyze.sh` there, and then inject violations
into the mirror only — the repository itself is never modified.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
MIRRORED = [
    ".fvmrc",
    "app",
    "packages/vv_native",
    "tools/ci/lib.sh",
    "tools/ci/format.sh",
    "tools/ci/analyze.sh",
]


def _require_flutter():
    if not (shutil.which("fvm") or shutil.which("flutter")):
        pytest.fail("[FND-01/AC1] needs fvm or flutter on PATH (run tools/ci/setup.sh)")


def _mirror(dst: Path) -> Path:
    files = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", *MIRRORED],
        cwd=ROOT, capture_output=True, check=True,
    ).stdout.decode().split("\0")
    for rel in filter(None, files):
        src = ROOT / rel
        if not src.is_file():  # deleted in the working tree, or a submodule gitlink
            continue
        out = dst / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, out)
    return dst


def _gate(root: Path, script: str):
    return subprocess.run(["bash", str(root / "tools" / "ci" / script)],
                          cwd=root, capture_output=True, text=True)


@pytest.fixture(scope="module")
def mirror(tmp_path_factory):
    _require_flutter()
    return _mirror(tmp_path_factory.mktemp("fnd01") / "repo")


def test_FND_01_AC1_format_gate_passes_on_tree_and_fails_on_unformatted_code(mirror):
    """[FND-01/AC1] `dart format --set-exit-if-changed` (tools/ci/format.sh) is clean on
    the current tree and fails when a file is not formatted."""
    r = _gate(mirror, "format.sh")
    assert r.returncode == 0, f"format gate fails on the current tree:\n{r.stdout}{r.stderr}"

    bad = mirror / "app" / "lib" / "fnd01_unformatted_probe.dart"
    bad.write_text("int  probe( ){return 1;}\n")
    try:
        r = _gate(mirror, "format.sh")
        assert r.returncode != 0, "format gate passed although a file is unformatted"
        assert "fnd01_unformatted_probe.dart" in r.stdout + r.stderr
    finally:
        bad.unlink()


def test_FND_01_AC1_analyze_gate_passes_on_tree_and_fails_on_print(mirror):
    """[FND-01/AC1] `flutter analyze` (tools/ci/analyze.sh) reports zero issues on the
    current tree and fails on a lint violation such as `print('x')`."""
    r = _gate(mirror, "analyze.sh")
    assert r.returncode == 0, f"analyze gate fails on the current tree:\n{r.stdout}{r.stderr}"

    bad = mirror / "app" / "lib" / "fnd01_print_probe.dart"
    bad.write_text("void probe() {\n  print('x');\n}\n")
    try:
        r = _gate(mirror, "analyze.sh")
        assert r.returncode != 0, "analyze gate passed although lib/ contains print('x')"
        assert "avoid_print" in r.stdout + r.stderr
    finally:
        bad.unlink()
