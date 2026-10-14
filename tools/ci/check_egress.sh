#!/usr/bin/env bash
# Egress guard (FND-03; hardened by SEC-02). Fails when
#  1. a network API, URL construction or web view appears outside the
#     allowlisted directories (Dart, Kotlin/Java, Swift/ObjC sources);
#  2. a telemetry / ads / crash / network-client dependency is declared in
#     app/pubspec.yaml or Gradle;
#  3. the platform transport policy is weakened: Android cleartext traffic or a
#     release trust of user CAs, a missing network security config; iOS ATS
#     exceptions (NSAllowsArbitraryLoads=true, NSAllowsLocalNetworking,
#     NSExceptionDomains, …).
# Usage: check_egress.sh [repo-root]
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Directories (relative to repo root) that may use network APIs.
ALLOW=(
  "app/lib/core/network/"
  "app/lib/features/models/data/"   # model downloader (MDL-02)
  # MDL-02 iOS background download session for model files only: hosts were
  # validated by the Dart NetworkGateway first and are re-checked natively
  # (docs/adr/ADR-MDL-02-model-downloader.md, docs/privacy-audit.md).
  "app/ios/Runner/ModelDownload/"
)
# Only first-party sources: tests, generated code and vendored native code
# are out of scope.
SCAN=(app/lib app/android/app/src app/ios/Runner packages/vv_native/lib)
# Dart
P_DART='package:http/|package:dio/|package:web_socket|package:grpc/|package:http2/|package:cronet_http|package:cupertino_http|package:socket_io|package:webview_flutter|package:url_launcher|package:flutter_inappwebview|HttpClient\(|HttpClient\.|RawSocket|SecureSocket|Socket\.connect|ServerSocket|RawDatagramSocket|WebSocket|Uri\.https?\(|Uri\.parse\(.https?:'
# Kotlin / Java
P_JVM='OkHttp|okhttp3|retrofit2|com\.android\.volley|HttpURLConnection|HttpsURLConnection|java\.net\.Socket|java\.net\.URL\b|URL\([^)]*\)\.open|DatagramSocket|android\.webkit\.WebView|Cronet|ktor'
# Swift / ObjC
P_APPLE='URLSession|NSURLConnection|NSURLSession|NWConnection|NWPathMonitor|import Network|CFStream|WKWebView|SFSafariViewController|UIWebView'
PATTERN="$P_DART|$P_JVM|$P_APPLE"

fail=0
for d in "${SCAN[@]}"; do
  [ -d "$ROOT/$d" ] || continue
  while IFS= read -r hit; do
    file="${hit%%:*}"; rel="${file#"$ROOT"/}"
    case "$rel" in *.g.dart|*.freezed.dart|*/l10n/gen/*) continue ;; esac
    line="${hit#*:*:}"
    # Comment-only lines (docs mentioning an API) are not network use.
    if [[ "$line" =~ ^[[:space:]]*(//|\*|/\*|#) ]]; then continue; fi
    allowed=0
    for a in "${ALLOW[@]}"; do [[ "$rel" == "$a"* ]] && allowed=1; done
    if [ "$allowed" -eq 0 ]; then
      echo "EGRESS: $hit" >&2
      fail=1
    fi
  done < <(grep -rEn --include='*.dart' --include='*.kt' --include='*.java' \
            --include='*.swift' --include='*.m' --include='*.mm' --include='*.h' \
            "$PATTERN" "$ROOT/$d" || true)
done

# Telemetry / ads / crash SDKs and extra network clients are forbidden as
# dependencies (pubspec + Gradle).
BAD_DEPS='firebase|crashlytics|sentry|analytics|amplitude|mixpanel|appsflyer|adjust_sdk|google_mobile_ads|facebook_|datadog|bugsnag|instabug|newrelic|segment|onesignal|dio|web_socket_channel|webview_flutter|url_launcher|cronet_http|cupertino_http|grpc'
if [ -f "$ROOT/app/pubspec.yaml" ]; then
  while IFS= read -r hit; do
    echo "FORBIDDEN DEPENDENCY: $hit" >&2
    fail=1
  done < <(grep -En "^[[:space:]]+($BAD_DEPS)[a-z_]*:" "$ROOT/app/pubspec.yaml" || true)
fi
BAD_GRADLE='firebase|crashlytics|sentry|play-services-analytics|play-services-ads|okhttp|retrofit|volley|appsflyer|bugsnag|datadog'
for g in "$ROOT"/app/android/app/build.gradle* "$ROOT"/app/android/build.gradle*; do
  [ -f "$g" ] || continue
  while IFS= read -r hit; do
    echo "FORBIDDEN DEPENDENCY: ${g#"$ROOT"/}:$hit" >&2
    fail=1
  done < <(grep -Ein "^[[:space:]]*(implementation|api|classpath)[^/]*($BAD_GRADLE)" "$g" || true)
done

# Android transport policy.
MANIFEST="$ROOT/app/android/app/src/main/AndroidManifest.xml"
NSC="$ROOT/app/android/app/src/main/res/xml/network_security_config.xml"
if [ -f "$MANIFEST" ]; then
  if grep -q 'usesCleartextTraffic="true"' "$MANIFEST"; then
    echo "TRANSPORT: AndroidManifest.xml allows cleartext traffic" >&2; fail=1
  fi
  if ! grep -q 'android:networkSecurityConfig="@xml/network_security_config"' "$MANIFEST"; then
    echo "TRANSPORT: AndroidManifest.xml has no networkSecurityConfig" >&2; fail=1
  fi
  if [ ! -f "$NSC" ]; then
    echo "TRANSPORT: res/xml/network_security_config.xml missing" >&2; fail=1
  else
    if grep -q 'cleartextTrafficPermitted="true"' "$NSC"; then
      echo "TRANSPORT: network_security_config.xml permits cleartext" >&2; fail=1
    fi
    if ! grep -q '<base-config cleartextTrafficPermitted="false"' "$NSC"; then
      echo "TRANSPORT: network_security_config.xml base-config must forbid cleartext" >&2; fail=1
    fi
    # User CAs only inside <debug-overrides> (never in release builds).
    if python3 - "$NSC" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
bad = [c for parent in root.iter() if parent.tag != 'debug-overrides'
       for ta in parent.findall('trust-anchors')
       for c in ta.findall('certificates') if c.get('src') == 'user']
sys.exit(0 if bad else 1)
PY
    then
      echo "TRANSPORT: network_security_config.xml trusts user CAs outside debug-overrides" >&2; fail=1
    fi
  fi
fi

# iOS App Transport Security.
PLIST="$ROOT/app/ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  if ! python3 - "$PLIST" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    info = plistlib.load(f)
ats = info.get('NSAppTransportSecurity', {})
bad = [k for k, v in ats.items() if v not in (False, {}, [])]
if bad:
    print('TRANSPORT: Info.plist ATS exceptions: ' + ', '.join(sorted(bad)), file=sys.stderr)
    sys.exit(1)
PY
  then fail=1; fi
fi

if [ "$fail" -ne 0 ]; then
  echo "check_egress: FAILED (route network use through lib/core/network)" >&2
  exit 1
fi
echo "check_egress: OK"
