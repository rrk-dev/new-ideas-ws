#!/usr/bin/env bash
# CI wrapper of the extraction eval (PRF-09, vv-benchmark-eval): runs
# tools/bench/eval/run.py --gate for every built-in profile when a change
# touches prompts, profiles or the eval itself; otherwise exits 0 (skip).
#
# Usage: tools/ci/eval.sh [--base <git ref>] [--force] [--check-only] [--profile P ...]
#   --base        diff base for change detection (default origin/main; $EVAL_BASE)
#   --force       run even when nothing relevant changed
#   --check-only  only print "run" or "skip" (exit 0) — used by tests
#   $EVAL_CHANGED_FILES  newline-separated file list instead of git diff (tests)
#   $VV_TEST_MODELS_DIR  where tools/ci/fetch_test_models.sh put SmolLM2-135M
#   $EVAL_MODEL          model override (default SmolLM2-135M-Instruct-Q8_0.gguf)
# Needs the host bridge (native/build.sh host). Reports go to
# ${EVAL_OUT_DIR:-$ROOT/build/eval} (upload as a CI artifact).
source "$(dirname "$0")/lib.sh"

BASE="${EVAL_BASE:-origin/main}"
FORCE=0
CHECK_ONLY=0
PROFILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --check-only) CHECK_ONLY=1; shift ;;
    --profile) PROFILES+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "eval.sh: unknown argument $1" >&2; exit 64 ;;
  esac
done
[ ${#PROFILES[@]} -eq 0 ] && PROFILES=(meeting warranty engineering)

# Files whose change can move extraction quality.
RELEVANT='^(app/assets/profiles/|app/lib/features/profiles/domain/(prompt_builder|prompt_inputs|extraction_prompts|schema_prompt_text|profile_schema)\.dart|app/lib/features/extraction/domain/output_schema_validator\.dart|app/tool/render_prompt\.dart|app/tool/src/|tools/bench/eval/|tools/ci/eval\.sh|native/llama\.cpp$|native/bridge/vv_llama)'

if [ -n "${EVAL_CHANGED_FILES+x}" ]; then
  changed="$EVAL_CHANGED_FILES"
else
  changed="$(git -C "$ROOT" diff --name-only "$BASE"...HEAD 2>/dev/null || git -C "$ROOT" diff --name-only HEAD~1 2>/dev/null || true)"
fi
decision=skip
if [ "$FORCE" = 1 ] || printf '%s\n' "$changed" | grep -Eq "$RELEVANT"; then
  decision=run
fi
if [ "$CHECK_ONLY" = 1 ]; then
  echo "$decision"
  exit 0
fi
if [ "$decision" = skip ]; then
  echo "eval.sh: no prompt/profile/eval change vs $BASE — skipped"
  exit 0
fi

MODELS="${VV_TEST_MODELS_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/vaultvoice/test-models}"
MODEL="${EVAL_MODEL:-$MODELS/SmolLM2-135M-Instruct-Q8_0.gguf}"
LIB="${VV_NATIVE_LIB:-$(ls "$ROOT"/native/build/host/libvv_native.* 2>/dev/null | head -1)}"
[ -f "$MODEL" ] || { echo "eval.sh: missing $MODEL (tools/ci/fetch_test_models.sh)" >&2; exit 2; }
[ -n "$LIB" ] && [ -f "$LIB" ] || { echo "eval.sh: missing host bridge (native/build.sh host)" >&2; exit 2; }
OUT="${EVAL_OUT_DIR:-$ROOT/build/eval}"
mkdir -p "$OUT"
(cd "$APP" && "${FLUTTER[@]}" pub get >/dev/null)

# The SmolLM2 baselines were recorded on macOS (Metal); x86 CPU numerics differ and the 135M
# model is noisy (open-questions F1 moved 0.10 with identical prompts), so off-macOS the gate
# tolerates a larger drop. Schema validity is still held to the 99 % floor.
MAX_DROP="${EVAL_MAX_DROP:-$([ "$(uname)" = Darwin ] && echo 0.02 || echo 0.15)}"

status=0
for p in "${PROFILES[@]}"; do
  echo "::group::eval $p"
  python3 "$ROOT/tools/bench/eval/run.py" --profile "$p" --model "$MODEL" --lib "$LIB" \
    --out-dir "$OUT" --gate --max-drop "$MAX_DROP" || status=1
  echo "::endgroup::"
done
exit $status
