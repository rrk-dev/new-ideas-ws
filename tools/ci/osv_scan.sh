#!/usr/bin/env bash
# SEC-08: dependency vulnerability scan with OSV-Scanner over the pub lockfiles
# (app/pubspec.lock, packages/*/pubspec.lock), Gradle lockfiles when
# present, and the vendored native submodules (llama.cpp, whisper.cpp by commit).
# Fails on any finding not ignored in osv-scanner.toml. Dev/CI tooling only: it
# queries osv.dev, the app itself never does.
# Usage: tools/ci/osv_scan.sh [--offline-check]
#   --offline-check  only verify the config and the tool are present (no network)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
command -v osv-scanner >/dev/null 2>&1 || {
  echo "osv_scan: osv-scanner not found (CI pins v2.7.0; see .github/workflows/osv.yml)" >&2
  exit 2
}
[ -f osv-scanner.toml ] || { echo "osv_scan: osv-scanner.toml missing" >&2; exit 1; }
[ "${1:-}" = "--offline-check" ] && { echo "osv_scan: tool and config present"; exit 0; }
# Shipped dependencies only: the submodules also carry Python/Node dev tooling
# (model conversion, examples) that is never built into the app.
LOCKS=()
while IFS= read -r f; do LOCKS+=(--lockfile "$f"); done < <(
  find app packages \( -name pubspec.lock -o -name gradle.lockfile \) \
    -not -path '*/.dart_tool/*' 2>/dev/null | sort)
[ ${#LOCKS[@]} -gt 0 ] || { echo "osv_scan: no lockfiles found" >&2; exit 1; }
osv-scanner scan source --config osv-scanner.toml "${LOCKS[@]}"

# Vendored native code (ggml/llama.cpp, whisper.cpp) is checked by pinned commit.
python3 - <<'PY'
import json, subprocess, sys, urllib.request
bad = 0
for line in subprocess.check_output(["git", "submodule", "status"], text=True).splitlines():
    sha, path = line.strip("-+ U").split()[:2]
    req = urllib.request.Request(
        "https://api.osv.dev/v1/query",
        data=json.dumps({"commit": sha}).encode(),
        headers={"Content-Type": "application/json"})
    vulns = json.load(urllib.request.urlopen(req, timeout=60)).get("vulns", [])
    ids = [v["id"] for v in vulns]
    print(f"{path} @ {sha[:10]}: {len(ids)} advisories {ids[:5]}")
    bad += len(ids)
sys.exit(1 if bad else 0)
PY
