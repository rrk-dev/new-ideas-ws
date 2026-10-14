#!/usr/bin/env bash
# Lints the rendered Markdown goldens (EXP-01) with markdownlint-cli2 and the
# shared config docs/markdownlint.json. The goldens are produced by
# app/test/unit/templates/builtin_templates_golden_test.dart.
#
# Usage: markdownlint.sh [glob…]   (default: the template goldens)
# Needs Node.js (npx); the linter version is pinned below and fetched by npx
# (dev tooling only — the app never runs it).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="0.23.3"   # markdownlint-cli2, released 2026-09-20
CONFIG="$ROOT/docs/markdownlint.json"
GLOBS=("$@")
[ ${#GLOBS[@]} -eq 0 ] && GLOBS=("app/test/fixtures/markdown/golden/**/*.md")

command -v npx >/dev/null 2>&1 || {
  echo "markdownlint: npx (Node.js) is required" >&2
  exit 1
}
cd "$ROOT"
exec npx --yes "markdownlint-cli2@$VERSION" --config "$CONFIG" "${GLOBS[@]}"
