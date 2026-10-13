#!/usr/bin/env bash
# [LLM-01] Build llama-bench + llm_spike from the pinned submodule (host only).
# Output: native/build/spike-llm01/ (gitignored). Usage: build.sh [cmake args]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${SPIKE_OUT:-$ROOT/native/build/spike-llm01}"
[ -f "$ROOT/native/llama.cpp/CMakeLists.txt" ] || {
  echo "run: git submodule update --init --recursive" >&2; exit 2; }
cmake -S "$HERE" -B "$OUT" -G Ninja -DCMAKE_BUILD_TYPE=Release -Wno-dev "$@"
cmake --build "$OUT" -j "$(getconf _NPROCESSORS_ONLN)" --target llm_spike llama-bench
echo "llm_spike:   $OUT/llm_spike"
echo "llama-bench: $(find "$OUT" -name llama-bench -type f -perm -u+x | head -1)"
