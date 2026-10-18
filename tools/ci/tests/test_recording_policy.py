"""Tests proving tools/ci/check_recording_policy.sh fails when it should (SEC-09).

Each test builds a throw-away fixture tree in tmp_path — no bad manifest is ever
committed. The parametrize id carries the acceptance tag so that
`pytest -k SEC-09_AC1` (what `tasks.py verify --run` uses) selects these tests.
"""
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "ci" / "check_recording_policy.sh"
AC1 = pytest.mark.parametrize("tag", ["SEC-09_AC1"])

CLEAN_MANIFEST = """<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
    <application>
        <service android:name=".RecordingService" android:foregroundServiceType="microphone"/>
    </application>
</manifest>
"""
PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>NSMicrophoneUsageDescription</key><string>Record notes</string>
<key>UIBackgroundModes</key><array>{modes}</array>
</dict></plist>
"""
MAIN_MANIFEST = "app/android/app/src/main/AndroidManifest.xml"


def run(*args):
    return subprocess.run(["bash", str(SCRIPT), *map(str, args)], capture_output=True, text=True)


def tree(base: Path, files: dict[str, str]) -> Path:
    defaults = {
        MAIN_MANIFEST: CLEAN_MANIFEST,
        "app/ios/Runner/Info.plist": PLIST.format(modes="<string>audio</string>"),
        "app/lib/main.dart": "void main() {}\n",
        "app/android/app/src/main/kotlin/a/Ok.kt": "val source = MediaRecorder.AudioSource.MIC\n",
        "app/ios/Runner/Ok.swift": "import CallKit\nlet o = CXCallObserver()\n",
    }
    for rel, body in {**defaults, **files}.items():
        p = base / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body)
    return base


def with_permission(name: str, extra_attr: str = "") -> str:
    return CLEAN_MANIFEST.replace(
        "<application>",
        f'<uses-permission android:name="android.permission.{name}"{extra_attr}/>\n    <application>')


def assert_fails(r, needle):
    assert r.returncode == 1, r.stdout + r.stderr
    assert needle in r.stderr, r.stderr


@AC1
def test_SEC_09_AC1_read_phone_state_in_manifest_fails(tmp_path, tag):
    """[SEC-09/AC1] a branch adding READ_PHONE_STATE fails the guard."""
    assert run(tree(tmp_path / "ok", {})).returncode == 0
    bad = tree(tmp_path / "bad", {MAIN_MANIFEST: with_permission("READ_PHONE_STATE")})
    assert_fails(run(bad), "forbidden permission android.permission.READ_PHONE_STATE")


@AC1
def test_SEC_09_AC1_voice_call_audio_source_in_kotlin_fails(tmp_path, tag):
    """[SEC-09/AC1] a branch adding AudioSource.VOICE_CALL fails the guard."""
    bad = tree(tmp_path, {
        "app/android/app/src/main/kotlin/a/Rec.kt":
            "val r = AudioRecord(MediaRecorder.AudioSource.VOICE_CALL, 16000, 16, 2, 4096)\n",
    })
    assert_fails(run(bad), "Rec.kt:1: call audio source: VOICE_CALL")


@AC1
def test_SEC_09_AC1_merged_manifest_from_plugins_is_checked(tmp_path, tag):
    """[SEC-09/AC1] a permission added only by a plugin (merged manifest) fails."""
    merged = "app/build/app/intermediates/merged_manifest/devDebug/processDevDebugManifest/AndroidManifest.xml"
    bad = tree(tmp_path, {merged: with_permission("READ_PHONE_STATE")})
    r = run(bad, "--require-merged-manifest")
    assert_fails(r, f"{merged}: forbidden permission android.permission.READ_PHONE_STATE")
    # Without a build output, the CI build job's flag makes the check fail
    # instead of silently skipping the merged manifest.
    assert_fails(run(tree(tmp_path / "nobuild", {}), "--require-merged-manifest"),
                 "no merged AndroidManifest.xml")
    ok = tree(tmp_path / "okbuild", {merged: CLEAN_MANIFEST})
    r = run(ok, "--require-merged-manifest")
    assert r.returncode == 0 and "(1 merged)" in r.stdout, r.stdout + r.stderr


@AC1
@pytest.mark.parametrize("perm", [
    "READ_CALL_LOG", "PROCESS_OUTGOING_CALLS", "ANSWER_PHONE_CALLS", "CAPTURE_AUDIO_OUTPUT",
    "MANAGE_OWN_CALLS", "BIND_ACCESSIBILITY_SERVICE", "SYSTEM_ALERT_WINDOW",
    "FOREGROUND_SERVICE_MEDIA_PROJECTION",
])
def test_SEC_09_AC1_every_forbidden_permission_fails(tmp_path, tag, perm):
    """[SEC-09/AC1] each permission listed in the task is rejected."""
    assert_fails(run(tree(tmp_path, {MAIN_MANIFEST: with_permission(perm)})), perm)


@AC1
def test_SEC_09_AC1_removing_a_plugin_permission_is_allowed(tmp_path, tag):
    """[SEC-09/AC1] tools:node="remove" (stripping a plugin permission) passes."""
    ok = tree(tmp_path, {MAIN_MANIFEST: with_permission("READ_PHONE_STATE", ' tools:node="remove"')})
    r = run(ok)
    assert r.returncode == 0, r.stderr


@AC1
def test_SEC_09_AC1_manifest_services_and_fgs_types_fail(tmp_path, tag):
    """[SEC-09/AC1] accessibility service, projection FGS type, telecom bindings fail."""
    m = CLEAN_MANIFEST.replace("</application>", """
        <service android:name=".A" android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter><action android:name="android.accessibilityservice.AccessibilityService"/></intent-filter>
        </service>
        <service android:name=".P" android:foregroundServiceType="microphone|mediaProjection"/>
    </application>""")
    r = run(tree(tmp_path, {MAIN_MANIFEST: m}))
    assert_fails(r, "guarded by forbidden permission")
    assert "forbidden service binding action android.accessibilityservice.AccessibilityService" in r.stderr
    assert "forbidden foregroundServiceType mediaProjection" in r.stderr


@AC1
def test_SEC_09_AC1_ios_voip_mode_and_entitlements_fail(tmp_path, tag):
    """[SEC-09/AC1] voip background mode and VoIP push entitlements fail."""
    bad = tree(tmp_path / "plist", {
        "app/ios/Runner/Info.plist": PLIST.format(modes="<string>audio</string><string>voip</string>"),
    })
    assert_fails(run(bad), "forbidden UIBackgroundModes entry 'voip'")
    ent = PLIST.replace("<key>NSMicrophoneUsageDescription</key><string>Record notes</string>",
                        "<key>com.apple.developer.pushkit.unrestricted-voip</key><true/>").format(modes="")
    bad = tree(tmp_path / "ent", {"app/ios/Runner/Runner.entitlements": ent})
    assert_fails(run(bad), "forbidden call/VoIP entitlement")


@AC1
@pytest.mark.parametrize("rel,body,needle", [
    ("app/ios/Runner/S.swift", "let p = CXProvider(configuration: c)\n", "CallKit provider"),
    ("app/ios/Runner/S.swift", "try s.setCategory(.playAndRecord, options: [.mixWithOthers])\n", "mix-with-others"),
    ("app/ios/Runner/S.swift", "try s.setMode(.voiceChat)\n", "VoIP audio session mode"),
    ("app/ios/Runner/S.swift", "import PushKit\n", "VoIP push"),
    ("app/ios/Runner/S.swift", "RPScreenRecorder.shared().startCapture()\n", "playback / screen capture"),
    ("app/android/app/src/main/kotlin/a/B.kt", "val c = AudioPlaybackCaptureConfiguration.Builder(p)\n",
     "playback / screen capture"),
    ("app/android/app/src/main/kotlin/a/B.kt", "class X : AccessibilityService()\n", "accessibility service"),
    ("app/android/app/src/main/kotlin/a/B.kt", "val t = getSystemService(TelephonyManager::class.java)\n",
     "telephony"),
    ("app/android/app/src/main/kotlin/a/B.kt", "audioManager.mode = AudioManager.MODE_IN_COMMUNICATION\n",
     "audio mode write"),
    ("app/android/app/src/main/java/a/B.java", "int s = MediaRecorder.AudioSource.REMOTE_SUBMIX;\n",
     "call audio source"),
    ("app/lib/r.dart", "const c = AndroidRecordConfig(audioSource: AndroidAudioSource.voiceCommunication);\n",
     "non-mic Android audio source"),
    ("app/lib/r.dart", "await Permission.phone.request();\n", "phone/overlay permission"),
    ("packages/p/lib/p.dart", "const p = 'android.permission.READ_CALL_LOG';\n", "call-related permission"),
])
def test_SEC_09_AC1_forbidden_source_apis_fail(tmp_path, tag, rel, body, needle):
    """[SEC-09/AC1] forbidden APIs in Dart/Kotlin/Java/Swift sources fail."""
    assert_fails(run(tree(tmp_path, {rel: body})), needle)


@AC1
def test_SEC_09_AC1_allowed_sources_pass(tmp_path, tag):
    """[SEC-09/AC1] the allowed APIs (mic/voiceRecognition, CXCallObserver, mode reads) pass."""
    ok = tree(tmp_path, {
        "app/lib/r.dart": "const a = AndroidAudioSource.mic; const b = AndroidAudioSource.voiceRecognition;\n",
        "app/android/app/src/main/kotlin/a/G.kt":
            "val inCall = am.mode == AudioManager.MODE_IN_CALL || am.mode == AudioManager.MODE_IN_COMMUNICATION\n",
    })
    r = run(ok)
    assert r.returncode == 0, r.stderr


@AC1
def test_SEC_09_AC1_repository_passes_and_ci_runs_the_guard(tag):
    """[SEC-09/AC1] the real repo passes; CI runs the guard in static and on the merged manifest."""
    r = run(ROOT)
    assert r.returncode == 0, r.stderr
    ci = (ROOT / ".github/workflows/ci.yml").read_text()
    assert "run_slot.sh check_recording_policy.sh SEC-09" in ci
    assert "check_recording_policy.sh --require-merged-manifest" in ci
    android_job = ci.split("\n  android:")[1].split("\n  ios:")[0]
    assert android_job.index("build_android.sh") < android_job.index("check_recording_policy.sh")


MAC_INFO = "app/macos/Runner/Info.plist"
MAC_PURPOSE = "Records a note you start, not a call."


def mac_plist(extra: str = "", purpose: str = MAC_PURPOSE) -> str:
    body = PLIST.replace("Record notes", purpose).format(modes="")
    return body.replace("</dict>", extra + "</dict>")


MAC = pytest.mark.parametrize("tag", ["AUD-09_AC3"])


@MAC
def test_AUD_09_AC3_macos_microphone_only_passes(tmp_path, tag):
    """[AUD-09/AC3] a microphone-only macOS Runner passes the guard."""
    ok = tree(tmp_path, {
        MAC_INFO: mac_plist(),
        "app/macos/Runner/Release.entitlements": mac_plist().replace(
            "<key>NSMicrophoneUsageDescription</key><string>%s</string>" % MAC_PURPOSE,
            "<key>com.apple.security.device.audio-input</key><true/>"),
    })
    r = run(ok)
    assert r.returncode == 0, r.stderr


@MAC
@pytest.mark.parametrize("key,needle", [
    ("<key>NSScreenCaptureUsageDescription</key><string>x</string>", "forbidden screen capture"),
    ("<key>NSAudioCaptureUsageDescription</key><string>x</string>", "forbidden system-audio capture"),
    ("<key>com.apple.security.device.camera</key><true/>", "forbidden camera"),
    ("<key>com.apple.security.temporary-exception.mach-lookup.global-name</key><array/>", "entitlement exception"),
    ("<key>LSUIElement</key><true/>", "hides the recording app"),
    ("<key>NSUserActivityTypes</key><array><string>INStartCallIntent</string></array>", "call intent"),
])
def test_AUD_09_AC3_macos_forbidden_keys_fail(tmp_path, tag, key, needle):
    """[AUD-09/AC3] screen/system-audio capture, call intents and hidden-agent keys fail on macOS."""
    for rel in (MAC_INFO, "app/macos/Runner/Release.entitlements", "packages/vv_native/macos/Info.plist"):
        bad = tree(tmp_path / rel.replace("/", "_"), {rel: mac_plist(key)})
        assert_fails(run(bad), needle)


@MAC
def test_AUD_09_AC3_macos_purpose_string_must_say_not_a_call(tmp_path, tag):
    """[AUD-09/AC3] the Runner purpose string states the user records a note, not a call."""
    bad = tree(tmp_path, {MAC_INFO: mac_plist(purpose="Needs the microphone.")})
    assert_fails(run(bad), "not a call")


@MAC
@pytest.mark.parametrize("rel,body", [
    ("app/macos/Runner/S.swift", "let s = SCStream(filter: f, configuration: c, delegate: nil)\n"),
    ("packages/vv_native/macos/T.swift", "AudioHardwareCreateProcessTap(d, &t)\n"),
    ("packages/vv_native/macos/A.swift", "AudioHardwareCreateAggregateDevice(d, &a)\n"),
    ("app/macos/Runner/I.swift", "let i = INStartCallIntent()\n"),
])
def test_AUD_09_AC3_macos_capture_sources_fail(tmp_path, tag, rel, body):
    """[AUD-09/AC3] macOS screen / process-audio capture and call-intent APIs fail the source scan."""
    assert_fails(run(tree(tmp_path, {rel: body})), rel)


@MAC
@pytest.mark.parametrize("rel,body", [
    ("app/macos/Runner/C.swift", "import CallKit\n"),
    ("app/macos/Runner/C.swift", "let o = CXCallObserver()\n"),
    ("packages/vv_native/macos/C.swift", "let c = CTCallCenter()\n"),
])
def test_AUD_09_AC3_macos_call_apis_fail(tmp_path, tag, rel, body):
    """[AUD-09/AC3] the macOS call guard may not use any call API (it answers inCall=false)."""
    assert_fails(run(tree(tmp_path, {rel: body})), rel)


def test_AUD_09_AC3_call_observer_stays_allowed_on_ios(tmp_path):
    """[AUD-09/AC3] the iOS CXCallObserver guard is unaffected by the macOS-only rule."""
    ok = tree(tmp_path, {"app/ios/Runner/C.swift": "let o = CXCallObserver()\n"})
    assert run(ok).returncode == 0


def test_FND_09_AC4_macos_call_guard_is_permissionless_and_registered():
    """[FND-09/AC2] macOS CallGuardHost answers false with no call API and is registered at startup."""
    host = (ROOT / "app/macos/Runner/MacHostChannels.swift").read_text()
    assert 'case "isInCall":\n      result(false)' in host
    window = (ROOT / "app/macos/Runner/MainFlutterWindow.swift").read_text()
    assert "MacHostChannels.register" in window
    pbx = (ROOT / "app/macos/Runner.xcodeproj/project.pbxproj").read_text()
    assert "MacHostChannels.swift in Sources" in pbx


@MAC
def test_AUD_09_AC3_repository_macos_files_are_scanned(tag):
    """[AUD-09/AC3] the real macOS runner and plugin files are in scope and pass."""
    r = run(ROOT)
    assert r.returncode == 0, r.stderr
    summary = r.stdout
    assert "plist/entitlement file(s)" in summary
    sys.path.insert(0, str(ROOT / "tools/ci"))
    import check_recording_policy as crp  # noqa: PLC0415
    rels = {p.relative_to(ROOT).as_posix() for p in crp.ios_plists(ROOT)}
    assert {"app/macos/Runner/Info.plist", "app/macos/Runner/Release.entitlements",
            "packages/vv_native/macos/Info.plist"} <= rels


@pytest.mark.parametrize("tag", ["SEC-09_AC2"])
def test_SEC_09_AC2_native_call_guards_use_permissionless_apis(tag):
    """[SEC-09/AC2] static check of the platform CallGuard sources (device test: docs/test-plans/device/SEC-09.md)."""
    kt = (ROOT / "app/android/app/src/main/kotlin/com/vaultvoice/vaultvoice/CallGuardPlugin.kt").read_text()
    for needle in ["MODE_RINGTONE", "MODE_IN_CALL", "MODE_IN_COMMUNICATION", "MODE_CALL_SCREENING",
                   "MODE_CALL_REDIRECT", "MODE_COMMUNICATION_REDIRECT", "addOnModeChangedListener",
                   "POLL_INTERVAL_MS = 500L", "registerAudioRecordingCallback", "isClientSilenced"]:
        assert needle in kt, needle
    assert "CallGuardPlugin()" in (ROOT / "app/android/app/src/main/kotlin/com/vaultvoice/vaultvoice/MainActivity.kt").read_text()
    swift = (ROOT / "app/ios/Runner/CallGuardPlugin.swift").read_text()
    for needle in ["CXCallObserver", "!$0.hasEnded", "AVAudioSession.interruptionNotification"]:
        assert needle in swift, needle
    code = [ln for ln in swift.splitlines() if not ln.strip().startswith("//")]
    assert not any("shouldResume" in ln for ln in code)  # never reads the resume hint
    assert "CallGuardPlugin.register" in (ROOT / "app/ios/Runner/AppDelegate.swift").read_text()
    assert "CallGuardPlugin.swift in Sources" in (ROOT / "app/ios/Runner.xcodeproj/project.pbxproj").read_text()


QCP02 = pytest.mark.parametrize("tag", ["QCP-02_AC6"])


@QCP02
@pytest.mark.parametrize("rel", [
    "app/ios/LumenWidgets/Bad.swift",
    "app/ios/QuickCaptureShared/Bad.swift",
])
def test_QCP_02_AC6_widget_extension_sources_are_scanned(tmp_path, tag, rel):
    """[QCP-02/AC6] the widget/control extension directories are policy source roots."""
    assert run(tree(tmp_path, {rel: "let o = CXCallObserver()\n"})).returncode == 0
    assert_fails(run(tree(tmp_path / "bad", {rel: "let p = CXProvider()\n"})), "CXProvider")


@QCP02
def test_QCP_02_AC6_extension_plist_with_background_mode_or_call_key_fails(tmp_path, tag):
    """[QCP-02/AC6] an extension Info.plist is scanned like the app's."""
    bad = tree(tmp_path, {"app/ios/LumenWidgets/Info.plist": PLIST.format(modes="<string>voip</string>")})
    assert_fails(run(bad), "voip")
