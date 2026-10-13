#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
for d in "$APP" "$ROOT/packages/vv_native"; do
  (cd "$d" && "${DART[@]}" format --set-exit-if-changed .)
done
