#!/usr/bin/env bash
# The APK must ship libvv_native.so for arm64-v8a (and nothing for other ABIs).
# Usage: check_apk_native.sh <apk>
set -euo pipefail
apk="${1:?usage: check_apk_native.sh <apk>}"
listing="$(unzip -l "$apk")"
echo "$listing" | grep -q 'lib/arm64-v8a/libvv_native.so' || {
  echo "FAIL: $apk does not contain lib/arm64-v8a/libvv_native.so" >&2; exit 1; }
if echo "$listing" | grep -E 'lib/(armeabi-v7a|x86|x86_64)/' >/dev/null; then
  echo "FAIL: $apk contains non-arm64 native libs" >&2; exit 1
fi
unzip -l "$apk" | grep 'libvv_native.so'
