#!/usr/bin/env python3
"""VaultVoice model catalog CLI (MDL-01): build, sign, verify, hash, keygen.

Dependency: the `cryptography` package (pyca, Apache-2.0/BSD) for Ed25519 —
`python3 -m pip install cryptography==46.0.3`. Everything else is stdlib.

The private signing key NEVER lives in the repository or in CI logs. It is
read from (in order): `--key-file PATH`, `$VV_CATALOG_SIGNING_KEY_FILE`
(a path) or `$VV_CATALOG_SIGNING_KEY` (the key itself — PEM or base64 seed,
for a CI secret). `keygen` refuses to write a key inside a git work tree.

Formats (mirrored by app/lib/features/models/domain/*.dart):
  catalog.json      UTF-8 JSON, schema 1 (tools/model-catalog/catalog.schema.json).
                    The signature covers these exact bytes.
  catalog.json.sig  {"alg": "ed25519", "key_id": "<16 hex>", "sig": "<base64>"}
                    key_id = first 8 bytes (hex) of SHA-256(raw 32-byte public key).

Usage:
  catalog.py keygen  --out ~/secure/vv-catalog.pem
  catalog.py pubkey  [--key-file K]
  catalog.py hash    FILE...
  catalog.py build   --models models.json --out catalog.json [--issued-at T]
  catalog.py sign    --catalog catalog.json [--key-file K] [--out catalog.json.sig]
  catalog.py verify  --catalog catalog.json --sig catalog.json.sig --pubkey B64
                     [--pubkey B64] [--not-before T]
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.ed25519 import (
        Ed25519PrivateKey,
        Ed25519PublicKey,
    )
except ImportError:  # pragma: no cover - environment problem
    sys.exit("catalog.py needs the 'cryptography' package: "
             "python3 -m pip install cryptography==46.0.3")

SUPPORTED_SCHEMAS = {1}
MAX_CATALOG_BYTES = 1024 * 1024  # same cap as the app (CatalogVerifier)
MODEL_TYPES = {"stt", "llm", "vad", "diarization-seg", "diarization-emb", "coreml-encoder"}
TIERS = {"free", "pro", "enterprise"}
DEVICE_TIERS = {"low", "mid", "high"}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
FILE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
TIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
ENV_KEY = "VV_CATALOG_SIGNING_KEY"
ENV_KEY_FILE = "VV_CATALOG_SIGNING_KEY_FILE"

# Output key order (stable bytes => reviewable diffs).
MODEL_KEYS = ("id", "type", "version", "display_name", "tier", "file", "size", "sha256",
              "min_ram_mb", "recommended_device_tiers", "license", "license_url",
              "attribution", "min_app_version", "urls", "companions")


class CatalogError(Exception):
    """Catalog or signature rejected; message is the reason."""


# ---------------------------------------------------------------- validation
def _https_url(u: object) -> bool:
    if not isinstance(u, str):
        return False
    p = urlsplit(u)
    return (p.scheme == "https" and bool(p.hostname) and not p.username
            and not p.password and not p.query and not p.fragment and p.port is None)


def parse_time(s: str) -> datetime:
    if not isinstance(s, str) or not TIME_RE.match(s):
        raise CatalogError(f"timestamp must be YYYY-MM-DDTHH:MM:SSZ: {s!r}")
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def validate_catalog(doc: object) -> None:
    """Raise CatalogError unless `doc` is a valid schema-1 catalog."""
    if not isinstance(doc, dict):
        raise CatalogError("catalog must be a JSON object")
    schema = doc.get("schema")
    if type(schema) is not int or schema not in SUPPORTED_SCHEMAS:
        raise CatalogError(f"unknown schema: {schema!r}")
    parse_time(doc.get("issued_at"))
    if not isinstance(doc.get("min_app_version"), str) or not SEMVER_RE.match(doc["min_app_version"]):
        raise CatalogError("min_app_version must be x.y.z")
    models = doc.get("models")
    if not isinstance(models, list) or not models:
        raise CatalogError("models must be a non-empty list")
    ids = set()
    for m in models:
        _validate_model(m)
        if m["id"] in ids:
            raise CatalogError(f"duplicate model id {m['id']}")
        ids.add(m["id"])
    for m in models:
        for c in m["companions"]:
            if c not in ids or c == m["id"]:
                raise CatalogError(f"{m['id']}: unknown companion {c!r}")


def _validate_model(m: object) -> None:
    if not isinstance(m, dict):
        raise CatalogError("model entry must be an object")
    mid = m.get("id")
    if not isinstance(mid, str) or not ID_RE.match(mid):
        raise CatalogError(f"bad model id {mid!r}")

    def need(cond: bool, what: str) -> None:
        if not cond:
            raise CatalogError(f"{mid}: {what}")

    def nonempty_str(k: str) -> bool:
        return isinstance(m.get(k), str) and m[k].strip() != ""

    need(m.get("type") in MODEL_TYPES, "type")
    need(nonempty_str("version"), "version")
    need(nonempty_str("display_name"), "display_name")
    need(m.get("tier") in TIERS, "tier")
    need(isinstance(m.get("file"), str) and bool(FILE_RE.match(m["file"])), "file (plain file name only)")
    need(type(m.get("size")) is int and m["size"] > 0, "size")
    need(isinstance(m.get("sha256"), str) and bool(SHA_RE.match(m["sha256"])), "sha256 (64 lowercase hex)")
    need(type(m.get("min_ram_mb")) is int and m["min_ram_mb"] >= 0, "min_ram_mb")
    tiers = m.get("recommended_device_tiers")
    need(isinstance(tiers, list) and bool(tiers) and all(t in DEVICE_TIERS for t in tiers)
         and len(set(tiers)) == len(tiers), "recommended_device_tiers")
    need(nonempty_str("license"), "license")
    need(_https_url(m.get("license_url")), "license_url (https, no query)")
    need("attribution" in m and (m["attribution"] is None or nonempty_str("attribution")),
         "attribution (string or null)")
    need(m.get("min_app_version") is None
         or (isinstance(m["min_app_version"], str) and bool(SEMVER_RE.match(m["min_app_version"]))),
         "min_app_version")
    urls = m.get("urls")
    need(isinstance(urls, list) and bool(urls) and all(_https_url(u) for u in urls)
         and len(set(urls)) == len(urls), "urls (https, no query/fragment/credentials)")
    comps = m.get("companions")
    need(isinstance(comps, list) and all(isinstance(c, str) for c in comps), "companions")


# ---------------------------------------------------------------- keys
def key_id(pub: Ed25519PublicKey) -> str:
    raw = pub.public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    return hashlib.sha256(raw).hexdigest()[:16]


def pub_b64(pub: Ed25519PublicKey) -> str:
    raw = pub.public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    return base64.b64encode(raw).decode()


def load_private_key(text: str) -> Ed25519PrivateKey:
    text = text.strip()
    if text.startswith("-----BEGIN"):
        key = serialization.load_pem_private_key(text.encode(), password=None)
        if not isinstance(key, Ed25519PrivateKey):
            raise CatalogError("key is not Ed25519")
        return key
    try:
        seed = base64.b64decode(text, validate=True)
    except ValueError as e:
        raise CatalogError("key must be PEM or base64 32-byte seed") from e
    if len(seed) != 32:
        raise CatalogError("key must be PEM or base64 32-byte seed")
    return Ed25519PrivateKey.from_private_bytes(seed)


def resolve_private_key(key_file: str | None) -> Ed25519PrivateKey:
    path = key_file or os.environ.get(ENV_KEY_FILE)
    if path:
        return load_private_key(Path(path).expanduser().read_text())
    if os.environ.get(ENV_KEY):
        return load_private_key(os.environ[ENV_KEY])
    raise CatalogError(f"no signing key: pass --key-file or set {ENV_KEY_FILE} / {ENV_KEY}")


def load_public_key(b64: str) -> Ed25519PublicKey:
    raw = base64.b64decode(b64, validate=True)
    if len(raw) != 32:
        raise CatalogError("public key must be 32 bytes (base64)")
    return Ed25519PublicKey.from_public_bytes(raw)


def _inside_git_worktree(path: Path) -> bool:
    d = path.parent
    while not d.exists():
        d = d.parent
    r = subprocess.run(["git", "-C", str(d), "rev-parse", "--is-inside-work-tree"],
                       capture_output=True, text=True)
    return r.returncode == 0 and r.stdout.strip() == "true"


def keygen(out: Path, allow_in_repo: bool = False) -> Ed25519PrivateKey:
    out = out.expanduser().resolve()
    if not allow_in_repo and _inside_git_worktree(out):
        raise CatalogError(f"refusing to write a private key inside a git work tree: {out}")
    if out.exists():
        raise CatalogError(f"{out} exists; not overwriting a key")
    key = Ed25519PrivateKey.generate()
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption())
    out.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(pem)
    return key


# ---------------------------------------------------------------- build / sign / verify
def canonical_bytes(doc: dict) -> bytes:
    return (json.dumps(doc, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def build(source: dict, issued_at: str | None = None, only: str | None = None) -> bytes:
    """Turn the models source file into catalog.json bytes (validated).

    only: build a signed single-model manifest (`<id>.json`) for offline
    import (MDL-04): the same schema-1 document with exactly that model.
    """
    issued = issued_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    models = []
    for m in source.get("models", []):
        if only is not None and m.get("id") != only:
            continue
        # Only schema fields are copied: provenance notes stay in the source.
        entry = {k: m.get(k) for k in MODEL_KEYS}
        entry["companions"] = m.get("companions") or []
        if entry["min_app_version"] is None:
            del entry["min_app_version"]
        models.append(entry)
    if only is not None:
        if not models:
            raise CatalogError(f"no model with id {only!r}")
        # A single-model manifest cannot reference companions it does not carry.
        models[0]["companions"] = []
    doc = {
        "schema": source.get("schema", 1),
        "issued_at": issued,
        "min_app_version": source.get("min_app_version", "1.0.0"),
        "models": models,
    }
    validate_catalog(doc)
    return canonical_bytes(doc)


def sign(catalog_bytes: bytes, key: Ed25519PrivateKey) -> bytes:
    validate_catalog(_load_json(catalog_bytes))
    sig = key.sign(catalog_bytes)
    env = {"alg": "ed25519", "key_id": key_id(key.public_key()),
           "sig": base64.b64encode(sig).decode()}
    return (json.dumps(env) + "\n").encode()


def _load_json(b: bytes) -> object:
    if len(b) > MAX_CATALOG_BYTES:
        raise CatalogError("catalog too large")
    try:
        return json.loads(b.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        raise CatalogError("catalog is not UTF-8 JSON") from e


def verify(catalog_bytes: bytes, sig_bytes: bytes, pubkeys: list[Ed25519PublicKey],
           not_before: str | None = None) -> dict:
    """Same order of checks as the app's CatalogVerifier. Returns the catalog."""
    if not 1 <= len(pubkeys) <= 2:
        raise CatalogError("pin one or two public keys")
    if len(catalog_bytes) > MAX_CATALOG_BYTES:
        raise CatalogError("catalog too large")
    try:
        env = json.loads(sig_bytes.decode("utf-8"))
        assert isinstance(env, dict) and env.get("alg") == "ed25519"
        sig = base64.b64decode(env["sig"], validate=True)
        assert len(sig) == 64 and isinstance(env["key_id"], str)
    except (AssertionError, KeyError, TypeError, ValueError, UnicodeDecodeError) as e:
        raise CatalogError("malformed signature file") from e
    keys = {key_id(k): k for k in pubkeys}
    if env["key_id"] not in keys:
        raise CatalogError("signature key is not pinned")
    try:
        keys[env["key_id"]].verify(sig, catalog_bytes)
    except InvalidSignature as e:
        raise CatalogError("bad signature") from e
    doc = _load_json(catalog_bytes)
    validate_catalog(doc)
    if not_before and parse_time(doc["issued_at"]) < parse_time(not_before):
        raise CatalogError("rollback: issued_at is older than the accepted catalog")
    return doc


def file_digest(path: Path) -> tuple[int, str]:
    h, n = hashlib.sha256(), 0
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
            n += len(chunk)
    return n, h.hexdigest()


# ---------------------------------------------------------------- CLI
def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="catalog.py", description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("keygen", help="generate an Ed25519 signing key (PEM, mode 0600)")
    g.add_argument("--out", required=True)
    g.add_argument("--allow-in-repo", action="store_true", help=argparse.SUPPRESS)
    k = sub.add_parser("pubkey", help="print public key (base64) and key id")
    k.add_argument("--key-file")
    h = sub.add_parser("hash", help="print size and sha256 of model files")
    h.add_argument("files", nargs="+")
    b = sub.add_parser("build", help="models source -> catalog.json")
    b.add_argument("--models", required=True)
    b.add_argument("--out", required=True)
    b.add_argument("--issued-at")
    b.add_argument("--only", metavar="ID",
                   help="single-model manifest for offline import (MDL-04)")
    s = sub.add_parser("sign", help="catalog.json -> catalog.json.sig")
    s.add_argument("--catalog", required=True)
    s.add_argument("--key-file")
    s.add_argument("--out")
    v = sub.add_parser("verify", help="verify catalog + signature against pinned keys")
    v.add_argument("--catalog", required=True)
    v.add_argument("--sig", required=True)
    v.add_argument("--pubkey", action="append", required=True)
    v.add_argument("--not-before", help="rollback floor (issued_at of the accepted catalog)")
    a = p.parse_args(argv)
    try:
        if a.cmd == "keygen":
            key = keygen(Path(a.out), a.allow_in_repo)
            print(f"wrote {a.out}\npublic_key {pub_b64(key.public_key())}\nkey_id {key_id(key.public_key())}")
        elif a.cmd == "pubkey":
            key = resolve_private_key(a.key_file)
            print(f"public_key {pub_b64(key.public_key())}\nkey_id {key_id(key.public_key())}")
        elif a.cmd == "hash":
            for f in a.files:
                n, d = file_digest(Path(f))
                print(f"{d}  {n}  {f}")
        elif a.cmd == "build":
            src = json.loads(Path(a.models).read_text(encoding="utf-8"))
            Path(a.out).write_bytes(build(src, a.issued_at, a.only))
            print(f"wrote {a.out}")
        elif a.cmd == "sign":
            out = a.out or a.catalog + ".sig"
            Path(out).write_bytes(sign(Path(a.catalog).read_bytes(), resolve_private_key(a.key_file)))
            print(f"wrote {out}")
        elif a.cmd == "verify":
            doc = verify(Path(a.catalog).read_bytes(), Path(a.sig).read_bytes(),
                         [load_public_key(x) for x in a.pubkey], a.not_before)
            print(f"OK schema={doc['schema']} issued_at={doc['issued_at']} models={len(doc['models'])}")
    except CatalogError as e:
        print(f"REJECTED: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
