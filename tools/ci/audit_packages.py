#!/usr/bin/env python3
"""SEC-02 package audit: scan every package compiled into the app for network
and telemetry code.

Inputs (from `app/` after `flutter pub get`):
  * `flutter pub deps --json` output (``--deps``) — the runtime dependency
    closure is computed from the root's *direct* (non-dev) dependencies;
  * `.dart_tool/package_config.json` (``--package-config``) — where each
    package's sources live (pub cache, Flutter SDK, local path).

Each package's Dart `lib/` and native plugin sources (`android/`, `ios/`,
`darwin/`, `macos/` excluded) are grepped for network APIs and telemetry SDKs.
A package with hits must be listed in ``tools/ci/package_audit.json`` with a
reviewed reason; ``--check`` fails otherwise. ``--markdown`` prints the table
that is pasted into ``docs/privacy-audit.md`` → "Package audit".

Usage:
  audit_packages.py --deps deps.json --package-config app/.dart_tool/package_config.json \
      [--allowlist tools/ci/package_audit.json] [--check] [--markdown]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[2]

NETWORK = re.compile(
    r"package:http/|package:dio/|package:web_socket|package:http2/|package:grpc/|"
    r"\bHttpClient\b|\bRawSocket\b|\bSecureSocket\b|Socket\.connect|\bWebSocket\b|"
    r"URLSession|NSURLConnection|NWConnection|HttpURLConnection|HttpsURLConnection|"
    r"okhttp3|\bOkHttp|java\.net\.URL\b|java\.net\.Socket|WKWebView|android\.webkit\.WebView")
TELEMETRY = re.compile(
    r"firebase|crashlytics|package:sentry|io\.sentry|sentry_flutter|firebase_analytics|"
    r"google_analytics|com\.google\.android\.gms\.analytics|package:amplitude|com\.amplitude|"
    r"mixpanel|appsflyer|bugsnag|datadog|instabug|newrelic|\btelemetry\b",
    re.IGNORECASE)
SOURCE_SUFFIXES = {".dart", ".kt", ".java", ".swift", ".m", ".mm", ".h", ".c", ".cc", ".cpp",
                   ".gradle", ".kts", ".podspec"}
SCAN_DIRS = ("lib", "android", "ios", "darwin")
COMMENT = re.compile(r"^\s*(//|\*|/\*|#)")


def runtime_closure(deps: dict) -> list[dict]:
    by_name = {p["name"]: p for p in deps["packages"]}
    root = by_name[deps["root"]]
    seen: dict[str, dict] = {}
    todo = list(root.get("directDependencies", []))
    while todo:
        name = todo.pop()
        if name in seen or name not in by_name:
            continue
        pkg = by_name[name]
        seen[name] = pkg
        todo.extend(pkg.get("dependencies", []))
    return sorted(seen.values(), key=lambda p: p["name"])


def package_roots(config_path: Path) -> dict[str, Path]:
    cfg = json.loads(config_path.read_text())
    out = {}
    for p in cfg["packages"]:
        uri = p["rootUri"]
        if uri.startswith("file:"):
            path = Path(unquote(urlparse(uri).path))
        else:  # relative to .dart_tool/
            path = (config_path.parent / uri).resolve()
        out[p["name"]] = path
    return out


def scan(root: Path) -> tuple[list[str], list[str]]:
    """Returns (network hits, telemetry hits) as 'relpath:line' strings."""
    net, tel = [], []
    for sub in SCAN_DIRS:
        base = root / sub
        if not base.is_dir():
            continue
        for f in sorted(base.rglob("*")):
            if not f.is_file() or f.suffix not in SOURCE_SUFFIXES:
                continue
            if "/test/" in f.as_posix() or "/example/" in f.as_posix():
                continue
            try:
                lines = f.read_text(errors="ignore").splitlines()
            except OSError:
                continue
            for i, line in enumerate(lines, 1):
                if COMMENT.match(line):
                    continue
                where = f"{f.relative_to(root).as_posix()}:{i}"
                if NETWORK.search(line):
                    net.append(where)
                if TELEMETRY.search(line):
                    tel.append(where)
    return net, tel


def audit(deps: dict, roots: dict[str, Path], allow: dict) -> tuple[list[dict], list[str]]:
    rows, problems = [], []
    for pkg in runtime_closure(deps):
        name = pkg["name"]
        root = roots.get(name)
        if pkg.get("source") == "sdk" or root is None:
            net, tel = [], []
            scanned = "Flutter SDK (trusted)" if pkg.get("source") == "sdk" else "not found"
        else:
            net, tel = scan(root)
            scanned = "scanned"
        entry = allow.get(name)
        if (net or tel) and entry is None:
            problems.append(f"{name} {pkg.get('version')}: unreviewed "
                            f"network={len(net)} telemetry={len(tel)} "
                            f"(first: {(net + tel)[0]})")
        if entry is not None and entry.get("telemetry") is False and tel:
            problems.append(f"{name}: reviewed as telemetry-free but has telemetry hits ({tel[0]})")
        rows.append({
            "name": name,
            "version": pkg.get("version", ""),
            "source": pkg.get("source", ""),
            "scanned": scanned,
            "network": len(net),
            "telemetry": len(tel),
            "decision": (entry or {}).get("reason", "no network / telemetry code"),
        })
    return rows, problems


def markdown(rows: list[dict]) -> str:
    out = ["| Package | Version | Source | Network hits | Telemetry hits | Review |",
           "|---|---|---|---|---|---|"]
    for r in rows:
        out.append(f"| `{r['name']}` | {r['version']} | {r['source']} | {r['network']} | "
                   f"{r['telemetry']} | {r['decision']} |")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--deps", required=True, type=Path)
    ap.add_argument("--package-config", required=True, type=Path)
    ap.add_argument("--allowlist", type=Path, default=ROOT / "tools" / "ci" / "package_audit.json")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--markdown", action="store_true")
    a = ap.parse_args(argv)
    deps = json.loads(a.deps.read_text())
    allow = json.loads(a.allowlist.read_text()) if a.allowlist.exists() else {}
    rows, problems = audit(deps, package_roots(a.package_config), allow)
    if a.markdown:
        print(markdown(rows))
    for p in problems:
        print(f"PACKAGE AUDIT: {p}", file=sys.stderr)
    if a.check and problems:
        print("audit_packages: FAILED — review the package and add it to "
              "tools/ci/package_audit.json + docs/privacy-audit.md", file=sys.stderr)
        return 1
    if not a.markdown:
        print(f"audit_packages: OK ({len(rows)} runtime packages, "
              f"{sum(1 for r in rows if r['network'] or r['telemetry'])} reviewed with hits)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
