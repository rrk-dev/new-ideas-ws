"""Tests for the model catalog CLI (MDL-01). Needs `cryptography` (see README)."""
import base64
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "catalog.py"
ROOT = HERE.parents[2]
ASSET = ROOT / "app" / "assets" / "catalog" / "catalog.json"
KEYS_DART = ROOT / "app" / "lib" / "features" / "models" / "domain" / "catalog_keys.dart"

_spec = importlib.util.spec_from_file_location("vv_catalog", TOOL)
cat = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cat)


def run(*args, env=None):
    return subprocess.run([sys.executable, str(TOOL), *args], capture_output=True, text=True,
                          env=env)


@pytest.fixture()
def key(tmp_path):
    """Throwaway signing key, outside the repository."""
    path = tmp_path / "keys" / "test.pem"
    k = cat.keygen(path)
    return path, k, cat.pub_b64(k.public_key())


@pytest.fixture()
def signed(tmp_path, key):
    path, _, pub = key
    out = tmp_path / "catalog.json"
    r = run("build", "--models", str(HERE.parent / "models.json"), "--out", str(out),
            "--issued-at", "2026-10-12T00:00:00Z")
    assert r.returncode == 0, r.stderr
    r = run("sign", "--catalog", str(out), "--key-file", str(path))
    assert r.returncode == 0, r.stderr
    return out, Path(str(out) + ".sig"), pub


def verify(c, s, *pubs, extra=()):
    args = ["verify", "--catalog", str(c), "--sig", str(s), *extra]
    for p in pubs:
        args += ["--pubkey", p]
    return run(*args)


def test_roundtrip_build_sign_verify(signed):
    c, s, pub = signed
    r = verify(c, s, pub)
    assert r.returncode == 0, r.stderr
    assert "models=2" in r.stdout
    env = json.loads(s.read_text())
    assert env["alg"] == "ed25519" and len(base64.b64decode(env["sig"])) == 64


def test_MDL_01_AC1_tampered_catalog_rejected(signed, tmp_path):
    """[MDL-01/AC1] one changed byte or swapped model hash fails verification."""
    c, s, pub = signed
    raw = c.read_bytes()
    t = tmp_path / "tampered.json"
    t.write_bytes(raw.replace(b"921e4cf8", b"deadbeef", 1))
    r = verify(t, s, pub)
    assert r.returncode == 1 and "bad signature" in r.stderr
    t.write_bytes(raw + b" ")
    assert verify(t, s, pub).returncode == 1


def test_MDL_01_AC1_bad_or_foreign_signature_rejected(signed, tmp_path):
    """[MDL-01/AC1] forged signature, unpinned key and malformed .sig are rejected."""
    c, s, pub = signed
    env = json.loads(s.read_text())
    forged = tmp_path / "forged.sig"
    forged.write_text(json.dumps({**env, "sig": base64.b64encode(bytes(64)).decode()}))
    r = verify(c, forged, pub)
    assert r.returncode == 1 and "bad signature" in r.stderr

    other = cat.keygen(tmp_path / "other.pem")
    r = verify(c, s, cat.pub_b64(other.public_key()))
    assert r.returncode == 1 and "not pinned" in r.stderr
    # Rotation: verifying with old + new pinned keys still accepts.
    assert verify(c, s, cat.pub_b64(other.public_key()), pub).returncode == 0

    junk = tmp_path / "junk.sig"
    junk.write_text("not a signature")
    r = verify(c, junk, pub)
    assert r.returncode == 1 and "malformed signature" in r.stderr


def test_MDL_01_AC1_rollback_rejected(signed):
    """[MDL-01/AC1] a catalog older than the accepted one is rejected."""
    c, s, pub = signed
    r = verify(c, s, pub, extra=["--not-before", "2026-10-13T00:00:00Z"])
    assert r.returncode == 1 and "rollback" in r.stderr
    assert verify(c, s, pub, extra=["--not-before", "2026-10-12T00:00:00Z"]).returncode == 0


def test_MDL_01_AC1_unknown_schema_rejected(key, tmp_path):
    """[MDL-01/AC1] a validly signed catalog with an unknown schema is rejected."""
    _, k, pub = key
    doc = json.loads(ASSET.read_text())
    doc["schema"] = 2
    raw = cat.canonical_bytes(doc)
    c = tmp_path / "c.json"
    c.write_bytes(raw)
    s = tmp_path / "c.json.sig"
    env = {"alg": "ed25519", "key_id": cat.key_id(k.public_key()),
           "sig": base64.b64encode(k.sign(raw)).decode()}
    s.write_text(json.dumps(env))
    r = verify(c, s, pub)
    assert r.returncode == 1 and "unknown schema" in r.stderr
    with pytest.raises(cat.CatalogError, match="unknown schema"):
        cat.sign(raw, k)  # the signer refuses too


@pytest.mark.parametrize("patch", [
    {"file": "../evil.bin"},
    {"urls": ["http://models.vaultvoice.example/a.bin"]},
    {"urls": ["https://models.vaultvoice.example/a.bin?uid=1"]},
    {"sha256": "ABC"},
    {"size": 0},
    {"type": "tts"},
    {"companions": ["missing"]},
])
def test_MDL_01_AC1_build_rejects_invalid_entries(patch):
    """[MDL-01/AC1] the tool never signs an entry the app would reject."""
    src = json.loads((HERE.parent / "models.json").read_text())
    src["models"][0].update(patch)
    with pytest.raises(cat.CatalogError):
        cat.build(src, "2026-10-12T00:00:00Z")


def test_single_model_manifest_for_offline_import(key, tmp_path):
    """[MDL-04] `build --only <id>` → signed one-model manifest the app verifies."""
    path, _, pub = key
    out = tmp_path / "whisper-tiny.en.json"
    r = run("build", "--models", str(HERE.parent / "models.json"), "--out", str(out),
            "--issued-at", "2026-10-12T00:00:00Z", "--only", "whisper-tiny.en")
    assert r.returncode == 0, r.stderr
    doc = json.loads(out.read_text())
    assert [m["id"] for m in doc["models"]] == ["whisper-tiny.en"]
    assert doc["schema"] == 1
    assert run("sign", "--catalog", str(out), "--key-file", str(path)).returncode == 0
    assert verify(out, Path(str(out) + ".sig"), pub).returncode == 0
    bad = run("build", "--models", str(HERE.parent / "models.json"), "--out",
              str(tmp_path / "x.json"), "--only", "nope")
    assert bad.returncode != 0


def test_key_from_env_var(tmp_path, key, signed):
    path, k, pub = key
    c, _, _ = signed
    seed = k.private_bytes_raw()
    env = {"PATH": "/usr/bin:/bin", "VV_CATALOG_SIGNING_KEY": base64.b64encode(seed).decode()}
    out = tmp_path / "env.sig"
    r = run("sign", "--catalog", str(c), "--out", str(out), env=env)
    assert r.returncode == 0, r.stderr
    assert verify(c, out, pub).returncode == 0
    r = run("sign", "--catalog", str(c), "--out", str(out), env={"PATH": "/usr/bin:/bin"})
    assert r.returncode == 1 and "no signing key" in r.stderr


def test_keygen_refuses_inside_repo_and_existing_file(key):
    target = ROOT / "tools" / "model-catalog" / "must-not-exist.pem"
    with pytest.raises(cat.CatalogError, match="inside a git work tree"):
        cat.keygen(target)
    assert not target.exists()
    path, _, _ = key
    assert oct(path.stat().st_mode & 0o777) == "0o600"
    with pytest.raises(cat.CatalogError, match="exists"):
        cat.keygen(path)


def test_bundled_catalog_matches_source_and_pinned_key():
    """The shipped asset = build(models.json) and verifies with the app's pinned key."""
    doc = json.loads(ASSET.read_text())
    src = json.loads((HERE.parent / "models.json").read_text())
    assert cat.build(src, doc["issued_at"]) == ASSET.read_bytes()
    pubs = re.findall(r"'([A-Za-z0-9+/]{43}=)'", KEYS_DART.read_text())
    assert 1 <= len(pubs) <= 2
    sig = Path(str(ASSET) + ".sig").read_bytes()
    out = cat.verify(ASSET.read_bytes(), sig, [cat.load_public_key(p) for p in pubs])
    ids = {m["id"]: m for m in out["models"]}
    assert ids["whisper-tiny.en"]["sha256"] == \
        "921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f"
    assert any(m["type"] == "llm" and m["file"].endswith(".gguf") for m in out["models"])


def test_no_private_key_committed():
    needle = b"BEGIN " + b"PRIVATE KEY"  # split so this file does not match
    files = subprocess.run(["git", "-C", str(ROOT), "ls-files"], capture_output=True,
                           text=True, check=True).stdout.split()
    for f in files:
        p = ROOT / f
        assert p.suffix not in {".pem", ".key"}, f"key-like file tracked: {f}"
        if p.is_file() and p.stat().st_size < 2_000_000:
            assert needle not in p.read_bytes(), f"private key material in {f}"
