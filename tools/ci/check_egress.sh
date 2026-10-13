#!/usr/bin/env bash
# Minimal egress guard (FND-03; SEC-02 extends it). Fails when a network API
# or telemetry dependency appears outside the allowlisted directories.
# Usage: check_egress.sh [repo-root]
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Directories (relative to repo root) that may use network APIs.
ALLOW=(
  "app/lib/core/network/"
  "app/lib/features/models/data/"   # model downloader (MDL-02)
  # MDL-02 iOS background download session for model files only: hosts were
  # validated by the Dart NetworkGateway first and are re-checked natively
  # (docs/adr/ADR-MDL-02-model-downloader.md, docs/privacy-audit.md).
  "app/ios/Runner/ModelDownload/"
)
# Only first-party sources: tests, generated code and vendored native code
# are out of scope.
SCAN=(app/lib app/android/app/src app/ios/Runner)
PATTERN='package:http/|package:dio/|package:web_socket|HttpClient\(|Socket\.connect|WebSocket|URLSession|OkHttp|HttpURLConnection|NSURLConnection'

fail=0
for d in "${SCAN[@]}"; do
  [ -d "$ROOT/$d" ] || continue
  while IFS= read -r hit; do
    file="${hit%%:*}"; rel="${file#"$ROOT"/}"
    allowed=0
    for a in "${ALLOW[@]}"; do [[ "$rel" == "$a"* ]] && allowed=1; done
    if [ "$allowed" -eq 0 ]; then
      echo "EGRESS: $hit" >&2
      fail=1
    fi
  done < <(grep -rEn --include='*.dart' --include='*.kt' --include='*.java' \
            --include='*.swift' --include='*.m' --include='*.h' \
            "$PATTERN" "$ROOT/$d" || true)
done

# Telemetry / ads / crash SDKs are forbidden as dependencies.
BAD_DEPS='firebase|crashlytics|sentry|analytics|amplitude|mixpanel|appsflyer|adjust_sdk|google_mobile_ads|facebook_'
if [ -f "$ROOT/app/pubspec.yaml" ]; then
  while IFS= read -r hit; do
    echo "FORBIDDEN DEPENDENCY: $hit" >&2
    fail=1
  done < <(grep -En "^[[:space:]]+($BAD_DEPS)[a-z_]*:" "$ROOT/app/pubspec.yaml" || true)
fi

if [ "$fail" -ne 0 ]; then
  echo "check_egress: FAILED (route network use through lib/core/network)" >&2
  exit 1
fi
echo "check_egress: OK"
