# Sourced by every CI script. Resolves the repo root and the Flutter/Dart
# launchers (FVM when available, plain flutter/dart otherwise).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT
if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
  DART=(fvm dart)
else
  FLUTTER=(flutter)
  DART=(dart)
fi
APP="$ROOT/app"
