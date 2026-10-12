#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$APP"
"${DART[@]}" format --set-exit-if-changed .
