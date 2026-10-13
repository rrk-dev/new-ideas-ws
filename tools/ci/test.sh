#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$APP"
"${FLUTTER[@]}" test --coverage
python3 "$ROOT/tools/ci/check_coverage.py" coverage/lcov.info
