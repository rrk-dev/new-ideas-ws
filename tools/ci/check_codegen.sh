#!/usr/bin/env bash
# Generated files (*.g.dart) are committed; they must match a fresh build.
source "$(dirname "$0")/lib.sh"
cd "$APP"
"${DART[@]}" run build_runner build --delete-conflicting-outputs
cd "$ROOT"
if [ -n "$(git status --porcelain -- app)" ]; then
  echo "Generated code is stale. Run build_runner and commit:" >&2
  git status --porcelain -- app >&2
  exit 1
fi
python3 "$ROOT/tools/ci/check_bindings.py"
