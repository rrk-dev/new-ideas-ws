#!/usr/bin/env bash
# SEC-02 package audit gate: every package compiled into the app is scanned
# for network / telemetry code; packages with hits must be reviewed in
# tools/ci/package_audit.json (and docs/privacy-audit.md → "Package audit").
# Needs `flutter pub get` first (tools/ci/setup.sh).
# Usage: check_packages.sh [--markdown]
source "$(dirname "$0")/lib.sh"
cd "$APP"
DEPS="$(mktemp)"
trap 'rm -f "$DEPS"' EXIT
"${FLUTTER[@]}" pub deps --json > "$DEPS"
python3 "$ROOT/tools/ci/audit_packages.py" --deps "$DEPS" \
  --package-config "$APP/.dart_tool/package_config.json" --check "$@"
