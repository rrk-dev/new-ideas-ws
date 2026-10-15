#!/usr/bin/env python3
"""VaultVoice enterprise licence CLI (LIC-03): keygen, pubkey, sign, inspect, verify.

Internal tool. Format: docs/enterprise-licensing.md. Dependency: `cryptography` (pyca).
`keygen` refuses to write inside a git work tree. Never commit a signing key.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)

MAX_BYTES = 64 * 1024
FEATURES = {
    "smallStt", "highAccuracyStt", "largeLlm", "customTemplates", "customProfiles",
    "multiTarget", "routingRules", "builtinWarranty", "builtinEngineering",
    "managedProfiles", "sideloadCustomModel",
}


class LicenseError(Exception):
    pass


def raw_pub(pub: Ed25519PublicKey) -> bytes:
    return pub.public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def key_id(pub: Ed25519PublicKey) -> str:
    return hashlib.sha256(raw_pub(pub)).hexdigest()[:16]


def load_private(path: str) -> Ed25519PrivateKey:
    key = serialization.load_pem_private_key(Path(path).expanduser().read_bytes(), password=None)
    if not isinstance(key, Ed25519PrivateKey):
        raise LicenseError("key is not Ed25519")
    return key


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_payload(args: argparse.Namespace, now: datetime) -> dict:
    if args.seats < 1:
        raise LicenseError("seats must be >= 1")
    if args.days < 1:
        raise LicenseError("days must be >= 1")
    unknown = set(args.feature) - FEATURES
    if unknown:
        raise LicenseError(f"unknown feature(s): {sorted(unknown)}")
    payload = {
        "license_id": args.license_id or hashlib.sha256(f"{args.org_id}{now}".encode()).hexdigest()[:16],
        "org_id": args.org_id,
        "org_name": args.org_name,
        "seats": args.seats,
        "issued_at": iso(now),
        "expires_at": iso(now + timedelta(days=args.days)),
        "features": sorted(set(args.feature)),
        "managed_config_defaults": {},
    }
    if args.org_profile_pubkey:
        if len(base64.b64decode(args.org_profile_pubkey, validate=True)) != 32:
            raise LicenseError("org profile public key must be 32 bytes (base64)")
        payload["org_profile_pubkey"] = args.org_profile_pubkey
    return payload


def sign_payload(payload: dict, key: Ed25519PrivateKey) -> dict:
    body = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return {
        "format": 1,
        "alg": "ed25519",
        "key_id": key_id(key.public_key()),
        "payload": base64.b64encode(body).decode(),
        "sig": base64.b64encode(key.sign(body)).decode(),
    }


def read_license(path: str) -> dict:
    data = Path(path).read_bytes()
    if len(data) > MAX_BYTES:
        raise LicenseError("licence file too large")
    return json.loads(data)


def verify_license(doc: dict, pubkey_b64: str) -> dict:
    pub = Ed25519PublicKey.from_public_bytes(base64.b64decode(pubkey_b64, validate=True))
    if doc.get("format") != 1 or doc.get("alg") != "ed25519":
        raise LicenseError("unsupported format")
    if doc.get("key_id") != key_id(pub):
        raise LicenseError("unknown key")
    body = base64.b64decode(doc["payload"], validate=True)
    try:
        pub.verify(base64.b64decode(doc["sig"], validate=True), body)
    except InvalidSignature as e:
        raise LicenseError("bad signature") from e
    return json.loads(body)


def in_git_worktree(path: Path) -> bool:
    d = path.resolve().parent
    while not d.exists():
        d = d.parent
    r = subprocess.run(["git", "-C", str(d), "rev-parse", "--is-inside-work-tree"],
                       capture_output=True, text=True)
    return r.returncode == 0 and r.stdout.strip() == "true"


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("keygen").add_argument("--out", required=True)
    sub.add_parser("pubkey").add_argument("--key", required=True)
    s = sub.add_parser("sign")
    s.add_argument("--key", required=True)
    s.add_argument("--org-id", required=True)
    s.add_argument("--org-name", required=True)
    s.add_argument("--seats", type=int, required=True)
    s.add_argument("--days", type=int, required=True)
    s.add_argument("--feature", action="append", default=[])
    s.add_argument("--license-id")
    s.add_argument("--org-profile-pubkey")
    s.add_argument("--out", required=True)
    sub.add_parser("inspect").add_argument("file")
    v = sub.add_parser("verify")
    v.add_argument("file")
    v.add_argument("--pubkey", required=True, help="base64 raw Ed25519 public key")
    return p


def main(argv: list[str] | None = None) -> int:
    a = parser().parse_args(argv)
    try:
        if a.cmd == "keygen":
            out = Path(a.out).expanduser()
            if in_git_worktree(out):
                raise LicenseError("refusing to write a signing key inside a git work tree")
            if out.exists():
                raise LicenseError(f"{out} exists")
            key = Ed25519PrivateKey.generate()
            out.write_bytes(key.private_bytes(
                serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                serialization.NoEncryption()))
            out.chmod(0o600)
            print(f"key_id {key_id(key.public_key())}")
        elif a.cmd == "pubkey":
            pub = load_private(a.key).public_key()
            print(f"{base64.b64encode(raw_pub(pub)).decode()} {key_id(pub)}")
        elif a.cmd == "sign":
            doc = sign_payload(build_payload(a, datetime.now(timezone.utc)), load_private(a.key))
            Path(a.out).write_text(json.dumps(doc, indent=2) + "\n")
        elif a.cmd == "inspect":
            doc = read_license(a.file)
            print(json.dumps(json.loads(base64.b64decode(doc["payload"])), indent=2))
        elif a.cmd == "verify":
            payload = verify_license(read_license(a.file), a.pubkey)
            print(f"OK {payload['org_id']} seats={payload['seats']} expires={payload['expires_at']}")
    except (LicenseError, KeyError, ValueError, json.JSONDecodeError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
