#!/usr/bin/env python3
"""Recording-policy guard (SEC-09, ADR-SEC-09-recording-policy).

Fails (exit 1) when anything that could capture phone/VoIP call audio, record
without a user tap, or hide recording appears in:

* Android manifests: every first-party source manifest and, when present, the
  **merged** manifest produced by the Gradle build (covers third-party plugins
  and implicit permissions added by the manifest merger);
* iOS and macOS `Info.plist` files and `*.entitlements` (macOS: microphone only,
  no screen/system-audio capture, no call/Continuity intents, no hidden agent app);
* first-party Dart / Kotlin / Java / Swift / Objective-C sources.

Usage: check_recording_policy.py [repo-root] [--require-merged-manifest]
                                 [--manifest PATH ...]

`--require-merged-manifest` is used by the CI job that has just built the APK:
it fails if no merged manifest can be found (so a moved AGP output path cannot
silently skip the most important check).
"""
from __future__ import annotations

import argparse
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
TOOLS_NS = "{http://schemas.android.com/tools}"

# --- Android manifest rules -------------------------------------------------
# Permissions that read/answer/redirect calls, capture other apps' or call
# audio, draw over other apps or bind accessibility/telecom services.
FORBIDDEN_PERMISSIONS = {
    "READ_PHONE_STATE",
    "READ_PRECISE_PHONE_STATE",
    "READ_PHONE_NUMBERS",
    "READ_CALL_LOG",
    "WRITE_CALL_LOG",
    "PROCESS_OUTGOING_CALLS",
    "ANSWER_PHONE_CALLS",
    "CALL_PHONE",
    "MODIFY_PHONE_STATE",
    "MANAGE_OWN_CALLS",
    "USE_SIP",
    "CAPTURE_AUDIO_OUTPUT",
    "CAPTURE_MEDIA_OUTPUT",
    "CAPTURE_VOICE_COMMUNICATION_OUTPUT",
    "FOREGROUND_SERVICE_MEDIA_PROJECTION",
    "FOREGROUND_SERVICE_PHONE_CALL",
    "BIND_ACCESSIBILITY_SERVICE",
    "BIND_INCALL_SERVICE",
    "BIND_SCREENING_SERVICE",
    "BIND_CALL_REDIRECTION_SERVICE",
    "BIND_TELECOM_CONNECTION_SERVICE",
    "SYSTEM_ALERT_WINDOW",
}
FORBIDDEN_FGS_TYPES = {"mediaProjection", "phoneCall"}
FORBIDDEN_ACTIONS = {
    "android.accessibilityservice.AccessibilityService",
    "android.telecom.InCallService",
    "android.telecom.ConnectionService",
    "android.telecom.CallScreeningService",
    "android.telecom.CallRedirectionService",
}
PERMISSION_TAGS = {"uses-permission", "uses-permission-sdk-23", "uses-permission-sdk-m"}

# --- Source rules -------------------------------------------------------------
# (rule id, regex, file suffixes or None for all scanned sources)
_ALL = None
# macOS: the microphone is the only audio input (AUD-09). Entitlement and
# Info.plist keys that grant screen / other-process audio capture, or attach
# to calls (FaceTime, Continuity), are forbidden.
FORBIDDEN_PLIST_KEYS = {
    "NSScreenCaptureUsageDescription": "screen capture",
    "NSAudioCaptureUsageDescription": "system-audio capture",
    "com.apple.security.device.camera": "camera",
    "NSCameraUsageDescription": "camera",
    "com.apple.developer.screen-capture": "screen capture",
    "com.apple.security.temporary-exception.audio-unit-host": "audio-unit host exception",
    "com.apple.developer.coreaudio.tap": "audio tap",
}
FORBIDDEN_PLIST_PREFIXES = ("com.apple.security.temporary-exception.mach-lookup",
                            "com.apple.security.temporary-exception.apple-events")
CALL_INTENT_RX = re.compile(r"\bIN(Start(Audio|Video)?Call|Answer|Hangup|Search)CallIntent\b|\bINStartCallIntent\b")
HIDDEN_APP_KEYS = ("LSUIElement", "LSBackgroundOnly")

SOURCE_RULES: list[tuple[str, re.Pattern[str], set[str] | None]] = [
    ("call audio source",
     re.compile(r"\b(VOICE_CALL|VOICE_UPLINK|VOICE_DOWNLINK|VOICE_COMMUNICATION|REMOTE_SUBMIX)\b"), _ALL),
    # `record` package: only AndroidAudioSource.mic / .voiceRecognition are allowed.
    ("non-mic Android audio source (record package)",
     re.compile(r"\bAndroidAudioSource\s*\.\s*(?!mic\b|voiceRecognition\b)\w+"), {".dart"}),
    ("playback / screen capture",
     re.compile(r"\b(AudioPlaybackCaptureConfiguration|MediaProjection\w*|RPScreenRecorder|RPBroadcast\w*|ReplayKit)\b"), _ALL),
    ("macOS screen / process audio capture",
     re.compile(r"\b(ScreenCaptureKit|SCStream\w*|SCShareableContent|CGDisplayStream\w*|CGWindowListCreateImage|"
                r"AVCaptureScreenInput|AudioHardwareCreateProcessTap|CATapDescription|"
                r"AudioHardwareCreateAggregateDevice|AudioHardwareCreateProcessTap)\b"), _ALL),
    ("call / Continuity intent",
     re.compile(r"\b(INStartCallIntent|INStartAudioCallIntent|INStartVideoCallIntent|INAnswerCallIntent)\b"), _ALL),
    ("accessibility service", re.compile(r"\bAccessibilityService\b"), _ALL),
    ("telephony / telecom service",
     re.compile(r"\b(TelephonyManager|PhoneStateListener|TelephonyCallback|InCallService|CallScreeningService|"
                r"CallRedirectionService|ConnectionService|TelecomManager)\b"), _ALL),
    ("call-related permission",
     re.compile(r"\b(" + "|".join(sorted(FORBIDDEN_PERMISSIONS)) + r")\b"), _ALL),
    ("permission_handler phone/overlay permission",
     re.compile(r"\bPermission\s*\.\s*(phone|systemAlertWindow)\b"), {".dart"}),
    ("CallKit provider / VoIP push",
     re.compile(r"\b(CXProvider\w*|CXCallController|CXTransaction|CXStartCallAction|CXAnswerCallAction|PKPushRegistry\w*|PushKit)\b"), _ALL),
    ("mix-with-others audio session", re.compile(r"mixWithOthers|MixWithOthers"), _ALL),
    ("VoIP audio session mode", re.compile(r"\b(voiceChat|videoChat|ModeVoiceChat|ModeVideoChat)\b"), _ALL),
    ("Android audio mode write (VoIP/call mode)",
     re.compile(r"\.setMode\s*\(|\.mode\s*=(?!=)"), {".kt", ".java"}),
]
# macOS-only (ADR-SEC-09 "CallGuard → macOS"): a Mac has no cellular call and
# the policy forbids CallKit, Continuity/FaceTime attachment and any call
# observer there; the macOS call guard answers `false` without call APIs.
MACOS_SOURCE_RULES: list[tuple[str, re.Pattern[str], set[str] | None]] = [
    ("macOS call API (CallKit / observer / FaceTime / Telephony)",
     re.compile(r"\b(import\s+CallKit|CXCall\w*|CXProvider\w*|CTCall\w*|CoreTelephony|FaceTime|facetime(-audio)?:|"
                r"NSUserActivity\w*Call\w*)\b"), _ALL),
]
SOURCE_SUFFIXES = {".dart", ".kt", ".java", ".swift", ".m", ".mm", ".h"}
SKIP_PARTS = {"build", ".dart_tool", ".gradle", "Pods", ".symlinks", "test", "androidTest",
              "Frameworks", "ephemeral", "__pycache__"}


def first_party_source_dirs(root: Path) -> list[Path]:
    # app/ios/LumenWidgets + QuickCaptureShared: QCP-02 widget/control extension;
    # LiveActivityShared: AUD-13 Live Activity attributes.
    dirs = [root / "app/lib", root / "app/android/app/src", root / "app/ios/Runner",
            root / "app/ios/LumenWidgets", root / "app/ios/QuickCaptureShared",
            root / "app/ios/ShareExtension",
            root / "app/ios/LiveActivityShared",
            root / "app/macos/Runner"]
    for pkg in sorted((root / "packages").glob("*")):
        dirs += [pkg / "lib", pkg / "android/src", pkg / "ios/Classes", pkg / "macos"]
    return [d for d in dirs if d.is_dir()]


def _skipped(path: Path, base: Path) -> bool:
    return any(part in SKIP_PARTS for part in path.relative_to(base).parts)


def source_manifests(root: Path) -> list[Path]:
    out = []
    for base in [root / "app/android", *sorted((root / "packages").glob("*/android"))]:
        if base.is_dir():
            out += [p for p in base.rglob("AndroidManifest.xml") if not _skipped(p, base)]
    return out


def merged_manifests(root: Path) -> list[Path]:
    """Merged manifests written by AGP (Flutter puts the app's Gradle buildDir
    under app/build/app; plain Gradle uses app/android/app/build). Verified for
    AGP 8.x: intermediates/merged_manifest/<variant>/process<Variant>Manifest/
    and intermediates/merged_manifests/<variant>/... (older)."""
    out = []
    for base in (root / "app/build", root / "app/android/app/build"):
        if base.is_dir():
            out += [p for p in base.rglob("AndroidManifest.xml")
                    if "intermediates" in p.parts and any(x.startswith("merged_manifest") for x in p.parts)]
    return sorted(out)


def check_manifest(path: Path, rel: str) -> list[str]:
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        return [f"{rel}: cannot parse manifest ({e})"]
    errs = []
    for el in tree.iter():
        if el.get(f"{TOOLS_NS}node") in ("remove", "removeAll"):
            continue  # explicitly stripping a permission a plugin adds is the fix, not a violation
        name = el.get(f"{ANDROID_NS}name") or ""
        short = name.rsplit(".", 1)[-1]
        if el.tag in PERMISSION_TAGS and name.startswith("android.permission.") and short in FORBIDDEN_PERMISSIONS:
            errs.append(f"{rel}: forbidden permission {name}")
        perm = el.get(f"{ANDROID_NS}permission") or ""
        if perm.rsplit(".", 1)[-1] in FORBIDDEN_PERMISSIONS:
            errs.append(f"{rel}: <{el.tag} {name}> guarded by forbidden permission {perm}")
        fgs = set((el.get(f"{ANDROID_NS}foregroundServiceType") or "").split("|"))
        if bad := fgs & FORBIDDEN_FGS_TYPES:
            errs.append(f"{rel}: <{el.tag} {name}> forbidden foregroundServiceType {'|'.join(sorted(bad))}")
        if el.tag == "action" and name in FORBIDDEN_ACTIONS:
            errs.append(f"{rel}: forbidden service binding action {name}")
    return errs


def check_plist(path: Path, rel: str) -> list[str]:
    try:
        data = plistlib.loads(path.read_bytes())
    except Exception as e:  # noqa: BLE001 - any parse error is a failure
        return [f"{rel}: cannot parse plist ({type(e).__name__})"]
    errs = []
    if isinstance(data, dict):
        modes = data.get("UIBackgroundModes") or []
        if "voip" in modes:
            errs.append(f"{rel}: forbidden UIBackgroundModes entry 'voip'")
    if isinstance(data, dict):
        for k in data:
            if k in FORBIDDEN_PLIST_KEYS:
                errs.append(f"{rel}: forbidden {FORBIDDEN_PLIST_KEYS[k]} key {k}")
            elif k.startswith(FORBIDDEN_PLIST_PREFIXES):
                errs.append(f"{rel}: forbidden entitlement exception {k}")
        for k in HIDDEN_APP_KEYS:
            if data.get(k) in (True, "1", 1):
                errs.append(f"{rel}: {k} hides the recording app (visible indicator required)")
        if CALL_INTENT_RX.search(str(data.get("NSUserActivityTypes", ""))):
            errs.append(f"{rel}: NSUserActivityTypes declares a call intent (Continuity)")
        if rel == "app/macos/Runner/Info.plist":
            purpose = str(data.get("NSMicrophoneUsageDescription", ""))
            if "not a call" not in purpose:
                errs.append(f"{rel}: NSMicrophoneUsageDescription must say the user records a note, not a call")
    if path.suffix == ".entitlements":
        def walk(v, key=""):
            if isinstance(v, dict):
                for k, x in v.items():
                    yield from walk(x, k)
            elif isinstance(v, list):
                for x in v:
                    yield from walk(x, key)
            else:
                yield key, str(v)
        for k, v in walk(data):
            if re.search(r"voip|pushkit|callkit", f"{k} {v}", re.I):
                errs.append(f"{rel}: forbidden call/VoIP entitlement {k}={v}")
    return errs


def ios_plists(root: Path) -> list[Path]:
    out = []
    bases = [root / "app/ios", root / "app/macos",
             *sorted((root / "packages").glob("*/ios")), *sorted((root / "packages").glob("*/macos"))]
    for base in bases:
        if not base.is_dir():
            continue
        for p in base.rglob("*"):
            if p.is_file() and (p.name == "Info.plist" or p.suffix == ".entitlements") and not _skipped(p, base):
                out.append(p)
    # Built app bundles (merged Info.plist), when a build ran.
    built = root / "app/build/ios"
    if built.is_dir():
        out += [p for p in built.rglob("Info.plist")
                if p.parent.name.endswith((".app", ".appex"))]
    built = root / "app/build/macos"
    if built.is_dir():
        out += [p for p in built.rglob("Info.plist") if p.parent.name == "Contents" and p.parent.parent.name.endswith(".app")]
    return out


def check_sources(root: Path) -> list[str]:
    errs = []
    for base in first_party_source_dirs(root):
        for f in sorted(base.rglob("*")):
            if f.suffix not in SOURCE_SUFFIXES or not f.is_file() or _skipped(f, base):
                continue
            rel = f.relative_to(root).as_posix()
            for n, line in enumerate(f.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
                rules = SOURCE_RULES + (MACOS_SOURCE_RULES if "/macos/" in f"/{rel}" else [])
                for rule, rx, suffixes in rules:
                    if suffixes is not None and f.suffix not in suffixes:
                        continue
                    if m := rx.search(line):
                        errs.append(f"{rel}:{n}: {rule}: {m.group(0)}")
    return errs


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--require-merged-manifest", action="store_true")
    ap.add_argument("--manifest", action="append", default=[], help="extra manifest to check")
    a = ap.parse_args(argv)
    root = Path(a.root).resolve()

    errs: list[str] = []
    merged = merged_manifests(root) + [Path(m).resolve() for m in a.manifest]
    if a.require_merged_manifest and not merged:
        errs.append("no merged AndroidManifest.xml found under app/build — build the APK first "
                    "(or the AGP output path changed: update merged_manifests())")
    manifests = source_manifests(root) + merged
    for m in manifests:
        errs += check_manifest(m, m.relative_to(root).as_posix() if m.is_relative_to(root) else str(m))
    plists = ios_plists(root)
    for p in plists:
        errs += check_plist(p, p.relative_to(root).as_posix())
    errs += check_sources(root)

    for e in errs:
        print(f"RECORDING-POLICY: {e}", file=sys.stderr)
    summary = (f"{len(manifests)} manifest(s) ({len(merged)} merged), {len(plists)} plist/entitlement file(s), "
               f"{len(first_party_source_dirs(root))} source dir(s)")
    if errs:
        print(f"check_recording_policy: FAILED — {len(errs)} violation(s) in {summary}. "
              "See docs/adr/ADR-SEC-09-recording-policy.md", file=sys.stderr)
        return 1
    print(f"check_recording_policy: OK — {summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
