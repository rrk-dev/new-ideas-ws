"""Tests proving the CI gates fail when they should (FND-03)."""
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CI = ROOT / "tools" / "ci"
TASKS_PY = Path(".agents/skills/vv-task-workflow/scripts/tasks.py")


def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def _tree(tmp_path, files):
    for rel, body in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body)
    return tmp_path


def test_FND_03_AC2_egress_guard_blocks_network_use_outside_gateway(tmp_path):
    """[FND-03/AC2] a PR adding package:http outside the gateway fails CI."""
    bad = _tree(tmp_path / "bad", {
        "app/lib/features/library/data/x.dart": "import 'package:http/http.dart';\n",
    })
    r = run(["bash", str(CI / "check_egress.sh"), str(bad)])
    assert r.returncode == 1, r.stdout + r.stderr
    assert "EGRESS" in r.stderr

    dep = _tree(tmp_path / "dep", {
        "app/pubspec.yaml": "dependencies:\n  firebase_core: ^1.0.0\n",
    })
    r = run(["bash", str(CI / "check_egress.sh"), str(dep)])
    assert r.returncode == 1 and "FORBIDDEN DEPENDENCY" in r.stderr

    ok = _tree(tmp_path / "ok", {
        "app/lib/core/network/g.dart": "import 'package:http/http.dart';\n",
        "app/lib/features/library/data/y.dart": "import 'dart:io';\n",
    })
    assert run(["bash", str(CI / "check_egress.sh"), str(ok)]).returncode == 0


def test_FND_03_AC2_coverage_gate_blocks_low_coverage(tmp_path):
    """[FND-03/AC2] coverage below the 80% gate fails the test job."""
    lcov = tmp_path / "lcov.info"
    lcov.write_text("SF:lib/core/a.dart\nLF:10\nLH:7\nend_of_record\n"
                    "SF:lib/ui/ignored.dart\nLF:10\nLH:0\nend_of_record\n"
                    "SF:lib/core/a.g.dart\nLF:10\nLH:0\nend_of_record\n")
    r = run([sys.executable, str(CI / "check_coverage.py"), str(lcov)])
    assert r.returncode == 1 and "70.0%" in r.stdout
    lcov.write_text("SF:lib/core/a.dart\nLF:10\nLH:8\nend_of_record\n")
    assert run([sys.executable, str(CI / "check_coverage.py"), str(lcov)]).returncode == 0


def test_FND_03_AC2_failing_script_exit_code_propagates(tmp_path):
    """[FND-03/AC2] run_slot executes an existing script and keeps its exit code."""
    slot = CI / "_probe_slot.sh"
    slot.write_text("exit 3\n")
    try:
        assert run(["bash", str(CI / "run_slot.sh"), "_probe_slot.sh", "X-00"]).returncode == 3
    finally:
        slot.unlink()
    r = run(["bash", str(CI / "run_slot.sh"), "_missing.sh", "X-00"])
    assert r.returncode == 0 and "did NOT run" in r.stdout


def test_FND_03_AC3_done_without_evidence_fails_verify_gate(tmp_path):
    """[FND-03/AC3] setting a task to done without evidence/report fails verify."""
    sandbox = tmp_path / "repo"
    shutil.copytree(ROOT / "tasks", sandbox / "tasks")
    shutil.copytree(ROOT / ".agents", sandbox / ".agents",
                    ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copytree(ROOT / "docs", sandbox / "docs")
    shutil.copytree(ROOT / "app" / "test", sandbox / "app" / "test")
    task = next((sandbox / "tasks").glob("*/FND-02-*.md"))
    text = task.read_text()
    text = re.sub(r"\*\*Status:\*\*\s*\S+", "**Status:** done", text, count=1)
    text = text.split("## Verification Report")[0]  # no report, as on a sloppy PR
    task.write_text(text)

    r = run([sys.executable, str(sandbox / TASKS_PY), "verify", "--all-done", "--run"], cwd=sandbox)
    assert r.returncode == 1, r.stdout + r.stderr
    # evidence is present in the sandbox, so the failures are the gate's own:
    assert "missing '## Verification Report'" in r.stdout
    assert "dependency FND-01 is not done" in r.stdout
    assert "no test containing" not in r.stdout

    # and a task with no tagged test for an AC fails too
    task.write_text(re.sub(r"\[FND-02/AC\d\]", "[FND-02/ACX]", task.read_text()))
    r = run([sys.executable, str(sandbox / TASKS_PY), "verify", "FND-02"], cwd=sandbox)
    assert r.returncode == 1 and "test evidence must be the tag [FND-02/AC1]" in r.stdout
