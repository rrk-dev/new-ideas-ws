#!/usr/bin/env bash
# SEC-08: dependency vulnerability scan with OSV-Scanner over the pub lockfiles
# (app/pubspec.lock, packages/*/pubspec.lock), Gradle and Podfile lockfiles when
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
osv-scanner scan source --config osv-scanner.toml --recursive .
