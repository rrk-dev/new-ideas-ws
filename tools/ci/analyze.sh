#!/usr/bin/env bash
# `flutter analyze` does not print riverpod_lint plugin diagnostics
# (ADR-FND-02), so both analyzers run.
source "$(dirname "$0")/lib.sh"
for d in "$APP" "$ROOT/packages/vv_native"; do
  (cd "$d" && "${FLUTTER[@]}" pub get >/dev/null && "${FLUTTER[@]}" analyze && "${DART[@]}" analyze --fatal-infos)
done
