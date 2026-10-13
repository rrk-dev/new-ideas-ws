#!/usr/bin/env bash
# ASan + UBSan host build of the bridge and its ctests (vv-ffi-bridge → Tests).
#   native/tests/sanitize.sh            GPU (Metal on macOS) + CPU-only runs
# Needs VV_TEST_MODELS_DIR (tools/ci/fetch_test_models.sh) for the STT tests;
# without it they are skipped. Output: native/build/host-asan (gitignored).
set -euo pipefail
NATIVE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$NATIVE/build/host-asan"
SAN="-fsanitize=address,undefined -fno-omit-frame-pointer"
cmake -S "$NATIVE" -B "$OUT" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -Wno-dev \
  -DCMAKE_C_FLAGS="$SAN" -DCMAKE_CXX_FLAGS="$SAN" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" \
  -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address,undefined" >/dev/null
cmake --build "$OUT" -j "${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
export UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1"
# Timing budgets do not apply to ~10x slower sanitizer builds (memory safety only).
export VV_CANCEL_BUDGET_MS=10000
ctest --test-dir "$OUT" --output-on-failure -R 'vv_smoke|vv_stt|vv_backends'
VV_STT_GPU=0 ctest --test-dir "$OUT" --output-on-failure -R 'vv_stt'
