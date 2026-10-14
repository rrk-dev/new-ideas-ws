#!/usr/bin/env bash
# The APK must ship libvv_native.so for arm64-v8a (and nothing for other ABIs).
# Usage: check_apk_native.sh <apk>
set -euo pipefail
apk="${1:?usage: check_apk_native.sh <apk>}"
listing="$(unzip -l "$apk")"
# grep reads a here-string, not a pipe: with `set -o pipefail`,
# `echo "$listing" | grep -q` fails with SIGPIPE (141) when grep exits on the
# first match before echo has written a large listing (a real debug APK).
grep -q 'lib/arm64-v8a/libvv_native\.so' <<<"$listing" || {
  echo "FAIL: $apk does not contain lib/arm64-v8a/libvv_native.so" >&2; exit 1; }
if grep -qE 'lib/(armeabi-v7a|x86|x86_64)/' <<<"$listing"; then
  echo "FAIL: $apk contains non-arm64 native libs:" >&2
  grep -E 'lib/(armeabi-v7a|x86|x86_64)/' <<<"$listing" | awk '{print "  " $NF}' >&2
  exit 1
fi
grep 'libvv_native\.so' <<<"$listing"
