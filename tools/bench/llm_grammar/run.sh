#!/usr/bin/env bash
# [LLM-05] Build + run the grammar overhead benchmark against the host bridge.
# Usage: tools/bench/llm_grammar/run.sh <model.gguf> [runs=3] [gpu=1]
# Needs `native/build.sh host` first. Prints JSON lines (one per run).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
LIB="$ROOT/native/build/host"
OUT="$LIB/grammar_bench"
cc -O2 -I"$ROOT/native/bridge" "$HERE/grammar_bench.c" -L"$LIB" -lvv_native \
  -Wl,-rpath,"$LIB" -lpthread -o "$OUT"
"$OUT" "$@"
