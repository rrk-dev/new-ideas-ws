#!/usr/bin/env bash
# `flutter analyze` does not print riverpod_lint plugin diagnostics
# (ADR-FND-02), so both analyzers run.
source "$(dirname "$0")/lib.sh"
cd "$APP"
"${FLUTTER[@]}" analyze
"${DART[@]}" analyze --fatal-infos
