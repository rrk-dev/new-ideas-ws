#!/usr/bin/env bash
# Egress guard (FND-03; hardened by SEC-02). Fails when
#  1. a network API, URL construction or web view appears outside the
#     allowlisted directories (Dart, Kotlin/Java, Swift/ObjC sources);
#  2. a telemetry / ads / crash / network-client dependency is declared in
#     app/pubspec.yaml or Gradle;
#  3. the platform transport policy is weakened: Android cleartext traffic or a
#     release trust of user CAs, a missing network security config; iOS ATS
#     exceptions (NSAllowsArbitraryLoads=true, NSExceptionDomains, …).
#     One documented exception (integration wave 3, STT-06 playback through
#     just_audio's in-process loopback proxy): Android cleartext for exactly
#     127.0.0.1 (no subdomains) and iOS NSAllowsLocalNetworking=true, nothing
#     else.
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
SCAN=(app/lib app/android/app/src app/ios/Runner app/ios/LumenWidgets app/ios/QuickCaptureShared app/ios/ShareExtension app/ios/LiveActivityShared packages/vv_native/lib)
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
    # LIC-02: passive OS reachability prevents offline cached ownership from
    # masquerading as a verified revocation. These exact declarations cannot
    # send traffic; all connection/HTTP APIs in the same file remain forbidden.
    if [ "$rel" = "app/ios/Runner/PurchaseHostApiImpl.swift" ]; then
      if [[ "$line" =~ ^[[:space:]]*import[[:space:]]Network[[:space:]]*$ ]] ||
         [[ "$line" =~ ^[[:space:]]*private[[:space:]]let[[:space:]]monitor[[:space:]]=[[:space:]]NWPathMonitor\(\)[[:space:]]*$ ]]; then
        allowed=1
      fi
    fi
    if [ "$allowed" -eq 0 ]; then
      echo "EGRESS: $hit" >&2
      fail=1
    fi
  done < <(grep -rEn --include='*.dart' --include='*.kt' --include='*.java' \
            --include='*.swift' --include='*.m' --include='*.mm' --include='*.h' \
            "$PATTERN" "$ROOT/$d" || true)
done

# SEC-11: no third-party integration host or credential code. Todoist, Notion,
# Apple Notes web APIs and similar were dropped (ADR-TSK-01); task export goes
# to the on-device Reminders store only. Cloud LLM hosts and OAuth/API-key
# plumbing must not appear in first-party sources or bundled assets either.
P_INTEG='todoist|notion\.so|api\.notion|evernote|asana\.com|trello\.com|graph\.microsoft|googleapis\.com|icloud\.com|api\.openai|openai\.com|anthropic\.com|generativelanguage|client_secret|AppAuth|OAuthSwift|oauth2?\b|Bearer '
for d in "${SCAN[@]}" app/assets app/macos/Runner; do
  [ -d "$ROOT/$d" ] || continue
  while IFS= read -r hit; do
    rel="${hit%%:*}"; rel="${rel#"$ROOT"/}"
    case "$rel" in *.g.dart|*/l10n/gen/*|*/assets/licenses/*) continue ;; esac
    line="${hit#*:*:}"
    if [[ "$line" =~ ^[[:space:]]*(//|\*|/\*|#) ]]; then continue; fi
    echo "INTEGRATION: $hit" >&2
    fail=1
  done < <(grep -rEin --include='*.dart' --include='*.kt' --include='*.java' \
            --include='*.swift' --include='*.m' --include='*.mm' --include='*.json' \
            --include='*.plist' --include='*.xml' "$P_INTEG" "$ROOT/$d" || true)
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
    # Cleartext only in a domain-config listing exactly 127.0.0.1 (STT-06
    # loopback playback proxy); anywhere else it fails.
    if ! python3 - "$NSC" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
def loopback_only(el):
    if el.tag != 'domain-config' or el.findall('domain-config'):
        return False
    domains = el.findall('domain')
    return bool(domains) and all(
        (d.text or '').strip() == '127.0.0.1'
        and d.get('includeSubdomains', 'false') == 'false' for d in domains)
bad = [el for el in root.iter()
       if el.get('cleartextTrafficPermitted') == 'true' and not loopback_only(el)]
sys.exit(1 if bad else 0)
PY
    then
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
# STT-06 loopback playback proxy: local networking only (no arbitrary loads).
allowed = {'NSAllowsLocalNetworking'}
bad = [k for k, v in ats.items()
       if v not in (False, {}, []) and not (k in allowed and v is True)]
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
