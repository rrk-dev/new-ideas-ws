#!/usr/bin/env bash
# Downloads the test-only models/audio listed in tools/ci/test-models.lock into a
# cache directory, verifying each file's sha256 (vv-testing → on-device
# integration test; vv-ci-release → fetch_test_models). Models are never
# committed: the destination must be outside the repository.
#
# Usage: fetch_test_models.sh [--dest DIR] [--lock FILE] [NAME...]
#   DIR   default $VV_TEST_MODELS_DIR, else ${XDG_CACHE_HOME:-~/.cache}/vaultvoice/test-models
#   NAME  only these entries (default: all)
# Already-cached files with the right hash are not downloaded again. The last
# line printed is `VV_TEST_MODELS_DIR=<dir>` (CI: append it to $GITHUB_ENV).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/tools/ci/test-models.lock"
DEST="${VV_TEST_MODELS_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/vaultvoice/test-models}"
ONLY=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) DEST="$2"; shift 2 ;;
    --lock) LOCK="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) ONLY+=("$1"); shift ;;
  esac
done

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# Physical absolute path of $1, which need not exist yet.
abspath() {
  local p="$1" rest=""
  [ "${p#/}" = "$p" ] && p="$PWD/$p"
  while [ ! -d "$p" ]; do rest="/$(basename "$p")$rest"; p="$(dirname "$p")"; done
  echo "$(cd "$p" && pwd -P)$rest"
}

DEST="$(abspath "$DEST")"
case "$DEST/" in
  "$(cd "$ROOT" && pwd -P)/"*)
    echo "fetch_test_models: refusing to write models inside the repo ($DEST)" >&2
    exit 2 ;;
esac
mkdir -p "$DEST"

wanted() {
  [ ${#ONLY[@]} -eq 0 ] && return 0
  local n
  for n in "${ONLY[@]}"; do [ "$n" = "$1" ] && return 0; done
  return 1
}

status=0
found=0
while read -r name sum size url; do
  case "$name" in ''|'#'*) continue ;; esac
  wanted "$name" || continue
  found=$((found + 1))
  out="$DEST/$name"
  if [ -f "$out" ] && [ "$(sha256 "$out")" = "$sum" ]; then
    echo "cached  $name"
    continue
  fi
  echo "fetch   $name ($size bytes)"
  part="$out.part"
  rm -f "$part"
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$part" "$url"; then
    echo "fetch_test_models: download failed: $name ($url)" >&2
    rm -f "$part"; status=1; continue
  fi
  got="$(sha256 "$part")"
  if [ "$got" != "$sum" ]; then
    echo "fetch_test_models: sha256 mismatch for $name: expected $sum, got $got" >&2
    rm -f "$part"; status=1; continue
  fi
  mv -f "$part" "$out"
  echo "ok      $name"
done < "$LOCK"

if [ ${#ONLY[@]} -gt 0 ] && [ "$found" -ne ${#ONLY[@]} ]; then
  echo "fetch_test_models: unknown name(s) in: ${ONLY[*]} (see $LOCK)" >&2
  status=1
fi
echo "VV_TEST_MODELS_DIR=$DEST"
exit $status
