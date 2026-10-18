#!/usr/bin/env python3
"""Store-privacy guard (SEC-06).

Fails (exit 1) when the repository stops matching what the store privacy
declarations say ("Data Not Collected", no tracking, no call recording):

* every first-party iOS/macOS ``PrivacyInfo.xcprivacy`` parses, declares no
  tracking, no tracking domains, no collected data, and only valid
  required-reason categories/codes; the app manifest is mandatory;
* required-reason APIs used by first-party Swift/ObjC sources are declared in
  the app manifest (or in the plugin's own manifest);
* ``Info.plist`` has a microphone usage description, no tracking/contacts/
  location/photo usage strings, and background modes limited to audio+processing;
* Android source (and merged, when present) manifests request no
  advertising-id/location/contacts/phone permissions and no ads/analytics meta-data;
* store listing copy and in-app strings never claim or imply call recording;
* the in-app privacy policy asset exists and is registered in pubspec.yaml.

Usage: check_store_privacy.py [repo-root]
"""
from __future__ import annotations

import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"

REASONS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": {
        "DDA9.1", "C617.1", "3B52.1", "0A2A.1",
    },
    "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1", "8FFB.1", "3D61.1"},
    "NSPrivacyAccessedAPICategoryDiskSpace": {
        "85F4.1", "E174.1", "7D9E.1", "B728.1",
    },
    "NSPrivacyAccessedAPICategoryActiveKeyboards": {"3EC4.1", "54BD.1"},
    "NSPrivacyAccessedAPICategoryUserDefaults": {
        "CA92.1", "1C8F.1", "C56D.1", "AC6B.1",
    },
}

# First-party source patterns that need a declared category.
API_PATTERNS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": re.compile(
        r"creationDate|modificationDate|contentModificationDate|creationDateKey|"
        r"attributesOfItem|attributesOfFileSystem|\bfstat\(|\bstat\(|\blstat\(|getattrlist"
    ),
    "NSPrivacyAccessedAPICategoryDiskSpace": re.compile(
        r"volumeAvailableCapacity|volumeTotalCapacity|systemFreeSize|systemSize|"
        r"\bstatfs\(|\bstatvfs\(|NSFileSystemFreeSize"
    ),
    "NSPrivacyAccessedAPICategoryUserDefaults": re.compile(r"UserDefaults"),
    "NSPrivacyAccessedAPICategorySystemBootTime": re.compile(
        r"systemUptime|mach_absolute_time|clock_gettime_nsec_np|kern\.boottime"
    ),
    "NSPrivacyAccessedAPICategoryActiveKeyboards": re.compile(r"activeInputModes"),
}

# Reminders keys are allowed since TSK-02: the user-initiated export writes to
# the on-device Reminders store (docs/privacy-audit.md); nothing is collected.
FORBIDDEN_PLIST_KEYS = {
    "NSUserTrackingUsageDescription",
    "NSContactsUsageDescription",
    "NSLocationWhenInUseUsageDescription",
    "NSLocationAlwaysUsageDescription",
    "NSLocationAlwaysAndWhenInUseUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "NSCameraUsageDescription",
    "NSCalendarsUsageDescription",
    "NSHealthShareUsageDescription",
    "NSSpeechRecognitionUsageDescription",
    "SKAdNetworkItems",
}
ALLOWED_BACKGROUND_MODES = {"audio", "processing"}

FORBIDDEN_ANDROID_PERMISSIONS = {
    "com.google.android.gms.permission.AD_ID",
    "ACCESS_FINE_LOCATION",
    "ACCESS_COARSE_LOCATION",
    "ACCESS_BACKGROUND_LOCATION",
    "READ_CONTACTS",
    "WRITE_CONTACTS",
    "GET_ACCOUNTS",
    "READ_SMS",
    "RECEIVE_SMS",
    "SEND_SMS",
    "READ_CALENDAR",
    "CAMERA",
    "BODY_SENSORS",
    "READ_PHONE_STATE",
    "READ_CALL_LOG",
    "WRITE_CALL_LOG",
    "READ_PHONE_NUMBERS",
    "PROCESS_OUTGOING_CALLS",
    "ANSWER_PHONE_CALLS",
}
FORBIDDEN_META_PREFIXES = (
    "com.google.android.gms.ads",
    "com.google.firebase.analytics",
    "firebase_analytics",
    "google_analytics",
    "com.facebook.sdk",
)

CALL_CLAIM = re.compile(
    r"(record(?:s|ing|er)?|capture[sd]?|tap(?:s|ping)?)\s+(?:your\s+|all\s+|any\s+|every\s+)?"
    r"(?:phone\s+|voip\s+|video\s+|whatsapp\s+|zoom\s+)?(?:calls?\b|call\s+audio)|"
    r"call[- ]record(?:er|ing)",
    re.IGNORECASE,
)
NEGATION = re.compile(
    r"\b(never|not|n't|no|without|stops?|blocked?|refuses?|cannot|can't|won't|"
    r"does not|isn't)\b",
    re.IGNORECASE,
)


def _load_plist(path: Path) -> dict:
    with path.open("rb") as f:
        return plistlib.load(f)


def _first_party(root: Path, pattern: str) -> list[Path]:
    skip = {"Pods", "build", ".dart_tool", "Frameworks", ".symlinks", "ephemeral"}
    out = []
    for p in root.glob(pattern):
        if any(part in skip for part in p.relative_to(root).parts):
            continue
        out.append(p)
    return sorted(out)


def check_manifest(path: Path, rel: str, errs: list[str]) -> set[str]:
    try:
        d = _load_plist(path)
    except Exception as e:  # noqa: BLE001 - any parse failure is a finding
        errs.append(f"{rel}: not a valid plist ({e})")
        return set()
    if d.get("NSPrivacyTracking") is not False:
        errs.append(f"{rel}: NSPrivacyTracking must be false")
    if d.get("NSPrivacyTrackingDomains", []) != []:
        errs.append(f"{rel}: NSPrivacyTrackingDomains must be empty")
    if d.get("NSPrivacyCollectedDataTypes", []) != []:
        errs.append(f"{rel}: NSPrivacyCollectedDataTypes must be empty (Data Not Collected)")
    declared: set[str] = set()
    for entry in d.get("NSPrivacyAccessedAPITypes", []):
        cat = entry.get("NSPrivacyAccessedAPIType")
        reasons = entry.get("NSPrivacyAccessedAPITypeReasons") or []
        if cat not in REASONS:
            errs.append(f"{rel}: unknown required-reason category {cat!r}")
            continue
        if not reasons:
            errs.append(f"{rel}: {cat} has no reason code")
        for r in reasons:
            if r not in REASONS[cat]:
                errs.append(f"{rel}: reason {r!r} is not valid for {cat}")
        declared.add(cat)
    return declared


def check_privacy_manifests(root: Path, errs: list[str]) -> None:
    app_manifest = root / "app/ios/Runner/PrivacyInfo.xcprivacy"
    if not app_manifest.is_file():
        errs.append("app/ios/Runner/PrivacyInfo.xcprivacy is missing")
        return
    pbx = root / "app/ios/Runner.xcodeproj/project.pbxproj"
    if pbx.is_file() and "PrivacyInfo.xcprivacy in Resources" not in pbx.read_text():
        errs.append("PrivacyInfo.xcprivacy is not in the Runner Resources build phase")

    declared_by_dir: dict[Path, set[str]] = {}
    for m in _first_party(root, "app/ios/**/PrivacyInfo.xcprivacy") + _first_party(
        root, "app/macos/**/PrivacyInfo.xcprivacy"
    ) + _first_party(root, "packages/*/ios/**/PrivacyInfo.xcprivacy") + _first_party(
        root, "packages/*/macos/**/PrivacyInfo.xcprivacy"
    ):
        rel = str(m.relative_to(root))
        declared_by_dir[m.parent] = check_manifest(m, rel, errs)

    app_declared = declared_by_dir.get(app_manifest.parent, set())
    plugin_dirs = {
        d: cats for d, cats in declared_by_dir.items() if d != app_manifest.parent
    }
    for pattern in ("app/ios/Runner/**/*", "packages/*/ios/**/*", "packages/*/macos/**/*"):
        for src in _first_party(root, pattern):
            if src.suffix in (".swift", ".m", ".mm"):
                _scan_source(root, src, app_declared, plugin_dirs, errs)

    # SEC-11: the extensions are separate bundles with their own manifest.
    # QuickCaptureShared is compiled into Runner *and* LumenWidgets, so both
    # must declare what it uses; ShareExtension has no manifest and must not
    # use any required-reason API.
    ios = root / "app/ios"
    shared_targets = {
        "app/ios/QuickCaptureShared/**/*": [app_declared, declared_by_dir.get(ios / "LumenWidgets", set())],
        "app/ios/LiveActivityShared/**/*": [app_declared, declared_by_dir.get(ios / "LumenWidgets", set())],
        "app/ios/LumenWidgets/**/*": [declared_by_dir.get(ios / "LumenWidgets", set())],
        "app/ios/ShareExtension/**/*": [declared_by_dir.get(ios / "ShareExtension", set())],
    }
    for pattern, declared_sets in shared_targets.items():
        for src in _first_party(root, pattern):
            if src.suffix in (".swift", ".m", ".mm"):
                for declared in declared_sets:
                    _scan_source(root, src, declared, {}, errs)


def _scan_source(
    root: Path,
    src: Path,
    app_declared: set[str],
    plugin_dirs: dict[Path, set[str]],
    errs: list[str],
) -> None:
    if not src.is_file() or src.name.endswith(".g.swift"):
        return
    # Comment-only lines (docs naming an API) are not API use.
    text = "\n".join(
        ln for ln in src.read_text(errors="ignore").splitlines()
        if not ln.lstrip().startswith(("//", "*", "/*"))
    )
    declared = set(app_declared)
    for d, cats in plugin_dirs.items():
        if d in src.parents:
            declared = cats
    for cat, pat in API_PATTERNS.items():
        if pat.search(text) and cat not in declared:
            errs.append(
                f"{src.relative_to(root)}: uses a {cat} API but no PrivacyInfo.xcprivacy declares it"
            )


def check_info_plists(root: Path, errs: list[str]) -> None:
    plist = root / "app/ios/Runner/Info.plist"
    if not plist.is_file():
        errs.append("app/ios/Runner/Info.plist is missing")
        return
    d = _load_plist(plist)
    mic = d.get("NSMicrophoneUsageDescription")
    if not isinstance(mic, str) or len(mic.strip()) < 20:
        errs.append("Info.plist: NSMicrophoneUsageDescription missing or too short")
    elif CALL_CLAIM.search(mic) and not NEGATION.search(mic):
        errs.append("Info.plist: microphone description implies call recording")
    for k in sorted(FORBIDDEN_PLIST_KEYS & d.keys()):
        errs.append(f"Info.plist: {k} contradicts the no-data-collected declaration")
    extra = set(d.get("UIBackgroundModes", [])) - ALLOWED_BACKGROUND_MODES
    if extra:
        errs.append(f"Info.plist: unexpected UIBackgroundModes {sorted(extra)}")
    if "audio" in d.get("UIBackgroundModes", []) and not d.get("NSMicrophoneUsageDescription"):
        errs.append("Info.plist: background audio without a microphone description")


def _manifest_findings(path: Path, rel: str, errs: list[str]) -> None:
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        errs.append(f"{rel}: unparsable manifest ({e})")
        return
    for el in tree.iter():
        name = el.get(ANDROID_NS + "name", "")
        if el.tag in ("uses-permission", "uses-permission-sdk-23"):
            short = name.rsplit(".", 1)[-1]
            if name in FORBIDDEN_ANDROID_PERMISSIONS or short in FORBIDDEN_ANDROID_PERMISSIONS:
                errs.append(f"{rel}: permission {name} contradicts the Data Safety declaration")
        if el.tag == "meta-data" and name.startswith(FORBIDDEN_META_PREFIXES):
            errs.append(f"{rel}: ads/analytics meta-data {name}")


def check_android(root: Path, errs: list[str]) -> None:
    manifests = _first_party(root, "app/android/**/AndroidManifest.xml") + _first_party(
        root, "packages/*/android/**/AndroidManifest.xml"
    )
    merged = list(root.glob("app/build/app/intermediates/merged_manifests/**/AndroidManifest.xml"))
    if not manifests:
        errs.append("no Android manifest found")
    for m in manifests + merged:
        _manifest_findings(m, str(m.relative_to(root)), errs)


def _claims(text: str) -> list[str]:
    bad = []
    for line in text.splitlines():
        if CALL_CLAIM.search(line) and not NEGATION.search(line):
            bad.append(line.strip())
    return bad


def check_copy(root: Path, errs: list[str]) -> None:
    listing = sorted((root / "docs/store").glob("listing*.md")) if (root / "docs/store").is_dir() else []
    if not listing:
        errs.append("docs/store/listing*.md (store listing copy) is missing")
    for f in listing:
        for line in _claims(f.read_text()):
            errs.append(f"{f.relative_to(root)}: implies call recording: {line[:80]!r}")
    arb = root / "app/lib/core/l10n/arb"
    for f in sorted(arb.glob("*.arb")) if arb.is_dir() else []:
        for line in _claims(f.read_text()):
            errs.append(f"{f.relative_to(root)}: implies call recording: {line[:80]!r}")


def check_policy_link(root: Path, errs: list[str]) -> None:
    asset = root / "app/assets/legal/privacy_policy.md"
    if not asset.is_file() or not asset.read_text().strip():
        errs.append("app/assets/legal/privacy_policy.md is missing or empty")
    pubspec = root / "app/pubspec.yaml"
    if pubspec.is_file() and "assets/legal/" not in pubspec.read_text():
        errs.append("app/pubspec.yaml does not register assets/legal/")
    settings = root / "app/lib/features/settings/presentation/settings_screen.dart"
    if settings.is_file() and "about-privacy-policy" not in settings.read_text():
        errs.append("Settings → About has no privacy-policy entry (about-privacy-policy)")


def main(argv: list[str]) -> int:
    root = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[2]
    errs: list[str] = []
    check_privacy_manifests(root, errs)
    check_info_plists(root, errs)
    check_android(root, errs)
    check_copy(root, errs)
    check_policy_link(root, errs)
    if errs:
        print("store-privacy check FAILED:", file=sys.stderr)
        for e in errs:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("store-privacy check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
