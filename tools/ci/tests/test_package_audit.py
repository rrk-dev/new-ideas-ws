"""SEC-02: package audit (tools/ci/audit_packages.py)."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "audit_packages.py"


def _fixture(tmp_path, allow):
    pkgs = {
        "clean": {"lib/a.dart": "int x = 1;\n"},
        "netpkg": {"lib/n.dart": "final c = HttpClient();\n"},
        "spy": {"android/src/main/kotlin/S.kt": "import com.google.firebase.analytics.X\n"},
        "devonly": {"lib/d.dart": "final c = HttpClient();\n"},
        "commented": {"lib/c.dart": "// uses HttpClient( in docs only\n"},
    }
    entries = []
    for name, files in pkgs.items():
        for rel, body in files.items():
            p = tmp_path / "cache" / name / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(body)
        entries.append({"name": name, "rootUri": (tmp_path / "cache" / name).as_uri()})
    (tmp_path / "package_config.json").write_text(json.dumps({"packages": entries}))
    deps = {"root": "app", "packages": [
        {"name": "app", "kind": "root", "source": "root",
         "directDependencies": ["clean", "netpkg", "spy", "commented", "flutter"],
         "dependencies": ["clean", "netpkg", "spy", "commented", "flutter", "devonly"]},
        {"name": "clean", "version": "1.0.0", "source": "hosted", "dependencies": []},
        {"name": "netpkg", "version": "2.0.0", "source": "hosted", "dependencies": []},
        {"name": "spy", "version": "3.0.0", "source": "hosted", "dependencies": []},
        {"name": "commented", "version": "1.0.0", "source": "hosted", "dependencies": []},
        {"name": "devonly", "version": "1.0.0", "source": "hosted", "dependencies": []},
        {"name": "flutter", "version": "0.0.0", "source": "sdk", "dependencies": []},
    ]}
    (tmp_path / "deps.json").write_text(json.dumps(deps))
    (tmp_path / "allow.json").write_text(json.dumps(allow))
    return [sys.executable, str(SCRIPT), "--deps", str(tmp_path / "deps.json"),
            "--package-config", str(tmp_path / "package_config.json"),
            "--allowlist", str(tmp_path / "allow.json"), "--check"]


def test_SEC_02_AC1_unreviewed_network_or_telemetry_package_fails(tmp_path):
    """[SEC-02/AC1] a runtime package with network/telemetry code must be reviewed."""
    r = subprocess.run(_fixture(tmp_path, {}), capture_output=True, text=True)
    assert r.returncode == 1
    assert "netpkg 2.0.0: unreviewed network=1" in r.stderr
    assert "spy 3.0.0: unreviewed network=0 telemetry=1" in r.stderr
    # dev-only deps, SDK packages and comment-only mentions are out of scope.
    assert "devonly" not in r.stderr and "commented" not in r.stderr
    assert "flutter" not in r.stderr


def test_SEC_02_AC1_reviewed_packages_pass_and_render_the_table(tmp_path):
    """[SEC-02/AC1] reviewed packages pass; --markdown renders the audit table."""
    allow = {"netpkg": {"reason": "gateway client", "telemetry": False},
             "spy": {"reason": "reviewed", "telemetry": "false-positive"}}
    cmd = _fixture(tmp_path, allow)
    r = subprocess.run(cmd, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    md = subprocess.run(cmd + ["--markdown"], capture_output=True, text=True).stdout
    assert "| `netpkg` | 2.0.0 | hosted | 1 | 0 | gateway client |" in md
    assert "| `flutter` | 0.0.0 | sdk | 0 | 0 |" in md
    # Telemetry-free review contradicted by telemetry code fails.
    allow["spy"]["telemetry"] = False
    r = subprocess.run(_fixture(tmp_path / "again", allow), capture_output=True, text=True)
    assert r.returncode == 1 and "reviewed as telemetry-free" in r.stderr


def test_SEC_02_AC1_real_allowlist_is_well_formed():
    """[SEC-02/AC1] every reviewed package has a reason."""
    allow = json.loads((ROOT / "tools" / "ci" / "package_audit.json").read_text())
    assert allow and all(v.get("reason") for v in allow.values())
