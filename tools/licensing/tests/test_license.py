import base64
import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import license as lic  # noqa: E402


@pytest.fixture
def key(tmp_path):
    # tmp_path is outside any git work tree
    path = tmp_path / "k.pem"
    assert lic.main(["keygen", "--out", str(path)]) == 0
    return path


def pubkey(key):
    return lic.load_private(str(key)).public_key()


def sign(key, tmp_path, *extra):
    out = tmp_path / "a.vvlicense"
    args = ["sign", "--key", str(key), "--org-id", "acme", "--org-name", "Acme",
            "--seats", "5", "--days", "30", "--out", str(out), *extra]
    assert lic.main(args) == 0
    return out


def b64pub(key):
    return base64.b64encode(lic.raw_pub(pubkey(key))).decode()


def test_sign_verify_roundtrip(key, tmp_path):
    out = sign(key, tmp_path, "--feature", "managedProfiles")
    payload = lic.verify_license(lic.read_license(str(out)), b64pub(key))
    assert payload["seats"] == 5 and payload["features"] == ["managedProfiles"]


def test_tampered_payload_rejected(key, tmp_path):
    doc = lic.read_license(str(sign(key, tmp_path)))
    body = json.loads(base64.b64decode(doc["payload"]))
    body["seats"] = 5000
    doc["payload"] = base64.b64encode(json.dumps(body).encode()).decode()
    with pytest.raises(lic.LicenseError, match="bad signature"):
        lic.verify_license(doc, b64pub(key))


def test_wrong_key_rejected(key, tmp_path):
    other = tmp_path / "o.pem"
    assert lic.main(["keygen", "--out", str(other)]) == 0
    doc = lic.read_license(str(sign(key, tmp_path)))
    with pytest.raises(lic.LicenseError, match="unknown key"):
        lic.verify_license(doc, b64pub(other))


def test_unknown_feature_and_bad_seats(key, tmp_path):
    out = tmp_path / "x"
    base = ["sign", "--key", str(key), "--org-id", "a", "--org-name", "A", "--days", "1",
            "--out", str(out)]
    assert lic.main([*base, "--seats", "1", "--feature", "nope"]) == 1
    assert lic.main([*base, "--seats", "0"]) == 1


def test_keygen_refuses_git_worktree():
    repo = Path(__file__).resolve().parents[3]
    r = subprocess.run([sys.executable, str(Path(lic.__file__)), "keygen", "--out",
                        str(repo / "should-not-exist.pem")], capture_output=True, text=True)
    assert r.returncode == 1 and "git work tree" in r.stderr
    assert not (repo / "should-not-exist.pem").exists()
