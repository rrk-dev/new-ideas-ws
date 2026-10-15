"""SEC-02: the hardened egress guard (tools/ci/check_egress.sh)."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "check_egress.sh"

MANIFEST_OK = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:networkSecurityConfig="@xml/network_security_config"
               android:usesCleartextTraffic="false"/>
</manifest>
"""
NSC_OK = """<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <base-config cleartextTrafficPermitted="false">
    <trust-anchors><certificates src="system" /></trust-anchors>
  </base-config>
  <debug-overrides>
    <trust-anchors><certificates src="user" /></trust-anchors>
  </debug-overrides>
</network-security-config>
"""
PLIST_OK = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsArbitraryLoads</key><false/></dict>
</dict></plist>
"""


def _repo(tmp_path, extra=None, drop=()):
    files = {
        "app/android/app/src/main/AndroidManifest.xml": MANIFEST_OK,
        "app/android/app/src/main/res/xml/network_security_config.xml": NSC_OK,
        "app/ios/Runner/Info.plist": PLIST_OK,
        "app/lib/core/network/gateway.dart": "import 'package:http/http.dart';\n",
        "app/pubspec.yaml": "dependencies:\n  http: ^1.6.0\n",
    }
    files.update(extra or {})
    for rel in drop:
        files.pop(rel)
    for rel, body in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body)
    return tmp_path


def _run(root):
    return subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)


def test_SEC_02_AC1_repository_passes_the_egress_guard():
    """[SEC-02/AC1] the real repository passes the hardened guard."""
    r = _run(ROOT)
    assert r.returncode == 0, r.stderr


def test_SEC_02_AC1_minimal_clean_tree_passes(tmp_path):
    """[SEC-02/AC1] gateway-only network use + locked transport passes."""
    r = _run(_repo(tmp_path))
    assert r.returncode == 0, r.stderr


def test_SEC_02_AC1_network_apis_outside_gateway_fail(tmp_path):
    """[SEC-02/AC1] every network API family is caught outside the gateway."""
    cases = {
        "app/lib/features/x/a.dart": "final u = Uri.https('evil.example', '/');\n",
        "app/lib/features/x/b.dart": "final s = await SecureSocket.connect('h', 443);\n",
        "app/lib/features/x/c.dart": "import 'package:webview_flutter/webview_flutter.dart';\n",
        "app/android/app/src/main/kotlin/X.kt": "val c = URL(u).openConnection() as HttpURLConnection\n",
        "app/ios/Runner/X.swift": "let t = URLSession.shared.dataTask(with: u)\n",
        "app/ios/Runner/Y.swift": "let v = WKWebView()\n",
    }
    for i, (rel, body) in enumerate(cases.items()):
        r = _run(_repo(tmp_path / str(i), {rel: body}))
        assert r.returncode == 1, rel
        assert "EGRESS" in r.stderr, rel


def test_SEC_02_AC1_comments_and_allowlisted_dirs_pass(tmp_path):
    """[SEC-02/AC1] doc comments mentioning an API and the gateway dirs are fine."""
    r = _run(_repo(tmp_path, {
        "app/lib/features/x/a.dart": "/// Never use HttpClient( here.\n// URLSession is iOS only\n",
        "app/ios/Runner/ModelDownload/D.swift": "let s = URLSession(configuration: c)\n",
    }))
    assert r.returncode == 0, r.stderr


def test_SEC_02_AC1_forbidden_dependencies_fail(tmp_path):
    """[SEC-02/AC1] telemetry SDKs and extra network clients are rejected."""
    r = _run(_repo(tmp_path / "pub", {"app/pubspec.yaml": "dependencies:\n  dio: ^5.0.0\n"}))
    assert r.returncode == 1 and "FORBIDDEN DEPENDENCY" in r.stderr
    r = _run(_repo(tmp_path / "gradle", {
        "app/android/app/build.gradle.kts":
            'dependencies {\n  implementation("com.squareup.okhttp3:okhttp:4.12.0")\n}\n',
    }))
    assert r.returncode == 1 and "FORBIDDEN DEPENDENCY" in r.stderr


def test_SEC_02_AC1_weakened_transport_policy_fails(tmp_path):
    """[SEC-02/AC1] cleartext, release user-CA trust and ATS exceptions fail."""
    bad = {
        "cleartext": {"app/android/app/src/main/AndroidManifest.xml":
                      MANIFEST_OK.replace('"false"', '"true"')},
        "nsc-cleartext": {"app/android/app/src/main/res/xml/network_security_config.xml":
                          NSC_OK.replace('cleartextTrafficPermitted="false"',
                                         'cleartextTrafficPermitted="true"')},
        "user-ca": {"app/android/app/src/main/res/xml/network_security_config.xml":
                    NSC_OK.replace('src="system"', 'src="user"')},
        "ats": {"app/ios/Runner/Info.plist": PLIST_OK.replace(
            "<false/>", "<true/>")},
        "ats-exception": {"app/ios/Runner/Info.plist": PLIST_OK.replace(
            "<key>NSAllowsArbitraryLoads</key><false/>",
            "<key>NSExceptionDomains</key><dict><key>x.example</key><dict/></dict>")},
    }
    for name, files in bad.items():
        r = _run(_repo(tmp_path / name, files))
        assert r.returncode == 1, name
        assert "TRANSPORT" in r.stderr, name
    # Integration W3: the loopback exception never widens to another host.
    loopback_plus = NSC_OK.replace(
        "</base-config>",
        '</base-config><domain-config cleartextTrafficPermitted="true">'
        '<domain includeSubdomains="false">127.0.0.1</domain>'
        '<domain includeSubdomains="false">evil.example</domain></domain-config>')
    for name, files in {
        "nsc-other-host": {
            "app/android/app/src/main/res/xml/network_security_config.xml":
                loopback_plus},
        "nsc-loopback-subdomains": {
            "app/android/app/src/main/res/xml/network_security_config.xml":
                NSC_OK.replace("</base-config>",
                               '</base-config><domain-config cleartextTrafficPermitted="true">'
                               '<domain includeSubdomains="true">127.0.0.1</domain>'
                               '</domain-config>')},
    }.items():
        r = _run(_repo(tmp_path / name, files))
        assert r.returncode == 1 and "TRANSPORT" in r.stderr, name
    r = _run(_repo(tmp_path / "no-nsc",
                   drop=["app/android/app/src/main/res/xml/network_security_config.xml"]))
    assert r.returncode == 1 and "TRANSPORT" in r.stderr


def test_INT_W3_loopback_playback_exception_passes(tmp_path):
    """Integration W3 (STT-06 x SEC-02): cleartext for exactly 127.0.0.1 and
    iOS NSAllowsLocalNetworking are the only accepted transport exceptions."""
    nsc = NSC_OK.replace(
        "</base-config>",
        '</base-config><domain-config cleartextTrafficPermitted="true">'
        '<domain includeSubdomains="false">127.0.0.1</domain></domain-config>')
    plist = PLIST_OK.replace(
        "<key>NSAllowsArbitraryLoads</key><false/>",
        "<key>NSAllowsLocalNetworking</key><true/>")
    r = _run(_repo(tmp_path, {
        "app/android/app/src/main/res/xml/network_security_config.xml": nsc,
        "app/ios/Runner/Info.plist": plist,
    }))
    assert r.returncode == 0, r.stderr
