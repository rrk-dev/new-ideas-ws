"""Tests for tools/ci/check_store_privacy.sh (SEC-06).

Fixture trees are built in tmp_path; nothing bad is committed. The parametrize
id carries the acceptance tag so `pytest -k SEC-06_AC1` selects these tests.
"""
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "check_store_privacy.sh"
AC1 = pytest.mark.parametrize("tag", ["SEC-06_AC1"])

HEAD = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>"""
TAIL = "</dict></plist>"


def manifest(tracking="false", collected="<array/>", apis=""):
    return (
        f"{HEAD}<key>NSPrivacyTracking</key><{tracking}/>"
        "<key>NSPrivacyTrackingDomains</key><array/>"
        f"<key>NSPrivacyCollectedDataTypes</key>{collected}"
        f"<key>NSPrivacyAccessedAPITypes</key><array>{apis}</array>{TAIL}"
    )


def api(cat, *reasons):
    r = "".join(f"<string>{x}</string>" for x in reasons)
    return (
        f"<dict><key>NSPrivacyAccessedAPIType</key><string>{cat}</string>"
        f"<key>NSPrivacyAccessedAPITypeReasons</key><array>{r}</array></dict>"
    )


DISK = api("NSPrivacyAccessedAPICategoryDiskSpace", "E174.1")
INFO = (
    f"{HEAD}<key>NSMicrophoneUsageDescription</key>"
    "<string>Record notes you start. Audio stays on this device.</string>"
    f"<key>UIBackgroundModes</key><array><string>audio</string></array>{TAIL}"
)
ANDROID = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<application/></manifest>"""
FILES = {
    "app/ios/Runner/PrivacyInfo.xcprivacy": manifest(apis=DISK),
    "app/ios/Runner.xcodeproj/project.pbxproj": "PrivacyInfo.xcprivacy in Resources",
    "app/ios/Runner/Info.plist": INFO,
    "app/ios/Runner/Ok.swift": "let free = values.volumeAvailableCapacityForImportantUsage\n",
    "app/android/app/src/main/AndroidManifest.xml": ANDROID,
    "docs/store/listing.md": "Records voice notes you start. It never records calls.\n",
    "app/lib/core/l10n/arb/app_en.arb": '{"a": "VaultVoice never records phone calls."}\n',
    "app/assets/legal/privacy_policy.md": "# Policy\n",
    "app/pubspec.yaml": "assets:\n  - assets/legal/\n",
    "app/lib/features/settings/presentation/settings_screen.dart": "'about-privacy-policy'\n",
}


def run(base):
    return subprocess.run(["bash", str(SCRIPT), str(base)], capture_output=True, text=True)


def tree(base: Path, **over):
    for rel, body in {**FILES, **over}.items():
        if body is None:
            continue
        p = base / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body)
    return base


def fails(r, needle):
    assert r.returncode == 1, r.stdout + r.stderr
    assert needle in r.stderr, r.stderr


@AC1
def test_SEC_06_AC1_clean_tree_passes(tmp_path, tag):
    """[SEC-06/AC1] a consistent tree passes."""
    r = run(tree(tmp_path))
    assert r.returncode == 0, r.stderr


@AC1
def test_SEC_06_AC1_repo_passes(tag):
    """[SEC-06/AC1] this repository's manifests, plist, copy and policy link pass."""
    r = subprocess.run(["bash", str(SCRIPT)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


@AC1
def test_SEC_06_AC1_missing_app_manifest_fails(tmp_path, tag):
    base = tree(tmp_path)
    (base / "app/ios/Runner/PrivacyInfo.xcprivacy").unlink()
    fails(run(base), "PrivacyInfo.xcprivacy is missing")


@AC1
def test_SEC_06_AC1_tracking_or_collected_data_fails(tmp_path, tag):
    fails(run(tree(tmp_path / "a", **{"app/ios/Runner/PrivacyInfo.xcprivacy": manifest(tracking="true", apis=DISK)})),
          "NSPrivacyTracking must be false")
    collected = "<array><dict><key>NSPrivacyCollectedDataType</key><string>x</string></dict></array>"
    fails(run(tree(tmp_path / "b", **{"app/ios/Runner/PrivacyInfo.xcprivacy": manifest(collected=collected, apis=DISK)})),
          "Data Not Collected")


@AC1
def test_SEC_06_AC1_invalid_reason_code_fails(tmp_path, tag):
    bad = manifest(apis=api("NSPrivacyAccessedAPICategoryDiskSpace", "ZZZZ.9"))
    fails(run(tree(tmp_path, **{"app/ios/Runner/PrivacyInfo.xcprivacy": bad})), "ZZZZ.9")


@AC1
def test_SEC_06_AC1_undeclared_required_reason_api_fails(tmp_path, tag):
    src = "let d = UserDefaults.standard\n"
    fails(run(tree(tmp_path, **{"app/ios/Runner/New.swift": src})),
          "NSPrivacyAccessedAPICategoryUserDefaults")


@AC1
def test_SEC_06_AC1_tracking_usage_string_fails(tmp_path, tag):
    bad = INFO.replace(TAIL, "<key>NSUserTrackingUsageDescription</key><string>ads</string>" + TAIL)
    fails(run(tree(tmp_path, **{"app/ios/Runner/Info.plist": bad})), "NSUserTrackingUsageDescription")


@AC1
def test_SEC_06_AC1_extra_background_mode_fails(tmp_path, tag):
    bad = INFO.replace("<string>audio</string>", "<string>audio</string><string>voip</string>")
    fails(run(tree(tmp_path, **{"app/ios/Runner/Info.plist": bad})), "UIBackgroundModes")


@AC1
def test_SEC_06_AC1_android_ad_id_permission_fails(tmp_path, tag):
    bad = ANDROID.replace(
        "<application/>",
        '<uses-permission android:name="com.google.android.gms.permission.AD_ID"/><application/>')
    fails(run(tree(tmp_path, **{"app/android/app/src/main/AndroidManifest.xml": bad})), "AD_ID")


@AC1
def test_SEC_06_AC1_call_recording_claim_in_listing_fails(tmp_path, tag):
    bad = "Record your phone calls with one tap.\n"
    fails(run(tree(tmp_path, **{"docs/store/listing.md": bad})), "implies call recording")
    fails(run(tree(tmp_path / "b", **{"app/lib/core/l10n/arb/app_en.arb": '{"a": "Great call recorder"}\n'})),
          "implies call recording")


@AC1
def test_SEC_06_AC1_missing_policy_link_fails(tmp_path, tag):
    fails(run(tree(tmp_path, **{"app/lib/features/settings/presentation/settings_screen.dart": "x\n"})),
          "privacy-policy entry")


BOOT = api("NSPrivacyAccessedAPICategorySystemBootTime", "35F9.1")
UPTIME = "let t = ProcessInfo.processInfo.systemUptime\n"
SEC11 = pytest.mark.parametrize("tag", ["SEC-11_AC4"])


@SEC11
def test_SEC_11_shared_code_declared_in_app_and_widget_passes(tmp_path, tag):
    """[SEC-11/AC4] QuickCaptureShared is compiled into Runner and the widget."""
    r = run(tree(tmp_path, **{
        "app/ios/Runner/PrivacyInfo.xcprivacy": manifest(apis=DISK + BOOT),
        "app/ios/LumenWidgets/PrivacyInfo.xcprivacy": manifest(apis=BOOT),
        "app/ios/QuickCaptureShared/Store.swift": UPTIME,
    }))
    assert r.returncode == 0, r.stderr


@SEC11
def test_SEC_11_shared_code_undeclared_in_app_fails(tmp_path, tag):
    fails(run(tree(tmp_path, **{
        "app/ios/LumenWidgets/PrivacyInfo.xcprivacy": manifest(apis=BOOT),
        "app/ios/QuickCaptureShared/Store.swift": UPTIME,
    })), "NSPrivacyAccessedAPICategorySystemBootTime")


@SEC11
def test_SEC_11_shared_code_undeclared_in_widget_fails(tmp_path, tag):
    fails(run(tree(tmp_path, **{
        "app/ios/Runner/PrivacyInfo.xcprivacy": manifest(apis=DISK + BOOT),
        "app/ios/QuickCaptureShared/Store.swift": UPTIME,
    })), "NSPrivacyAccessedAPICategorySystemBootTime")


@SEC11
def test_SEC_11_share_extension_required_reason_api_fails(tmp_path, tag):
    fails(run(tree(tmp_path, **{
        "app/ios/ShareExtension/Share.swift": "let d = UserDefaults.standard\n",
    })), "NSPrivacyAccessedAPICategoryUserDefaults")
